#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd


SHARD_ID_RE = re.compile(r"::shard:(?P<ordinal>\d+)$")


@dataclass
class QueryContext:
    data_root: Path
    tenant_id: str


def _read_stdin_json() -> Dict[str, Any]:
    raw = sys.stdin.read().strip()
    if not raw:
        return {}
    payload = json.loads(raw)
    if not isinstance(payload, dict):
        raise ValueError("stdin payload must be a JSON object")
    return payload


def _safe_int(value: Any, default: int, minimum: int, maximum: int) -> int:
    try:
        parsed = int(value)
    except Exception:
        return default
    if parsed < minimum:
        return minimum
    if parsed > maximum:
        return maximum
    return parsed


def _normalize_ts(value: Any) -> Optional[str]:
    ts = pd.to_datetime(value, utc=True, errors="coerce")
    if pd.isna(ts):
        return None
    iso = ts.isoformat()
    if iso.endswith("+00:00"):
        return iso[:-6] + "Z"
    return iso


def _load_topics_frame(ctx: QueryContext) -> pd.DataFrame:
    parquet_root = ctx.data_root / "parquet" / "topics"
    if not parquet_root.exists():
        raise FileNotFoundError(f"topics parquet directory not found: {parquet_root}")

    parts = sorted(parquet_root.rglob("*.parquet"))
    if not parts:
        return pd.DataFrame()

    frames = [pd.read_parquet(path) for path in parts]
    df = pd.concat(frames, ignore_index=True)

    if "tenant_id" not in df.columns:
        df["tenant_id"] = "default"
    if "topic_id" not in df.columns:
        df["topic_id"] = "default"
    if "canonical_topic_id" not in df.columns:
        df["canonical_topic_id"] = df["topic_id"]
    if "topic_path" not in df.columns:
        df["topic_path"] = df["canonical_topic_id"]
    if "status" not in df.columns:
        df["status"] = "active"
    if "summary" not in df.columns:
        df["summary"] = ""
    if "vector_text" not in df.columns:
        df["vector_text"] = df["summary"]
    if "message_count" not in df.columns:
        df["message_count"] = 0
    if "updated_at" not in df.columns:
        df["updated_at"] = pd.Timestamp.now(tz="UTC")

    df["tenant_id"] = df["tenant_id"].fillna("default").astype(str)
    df["topic_id"] = df["topic_id"].fillna("default").astype(str)
    df["canonical_topic_id"] = df["canonical_topic_id"].fillna(df["topic_id"]).astype(str)
    df["topic_path"] = df["topic_path"].fillna(df["canonical_topic_id"]).astype(str)
    df["status"] = df["status"].fillna("active").astype(str)
    df["summary"] = df["summary"].fillna("").astype(str)
    df["vector_text"] = df["vector_text"].fillna(df["summary"]).astype(str)
    df["message_count"] = pd.to_numeric(df["message_count"], errors="coerce").fillna(0).astype(int)
    df["updated_at"] = pd.to_datetime(df["updated_at"], utc=True, errors="coerce")
    return df


def _scoped_active(df: pd.DataFrame, tenant_id: str) -> pd.DataFrame:
    if df.empty:
        return df.copy()
    scoped = df[df["tenant_id"].astype(str) == str(tenant_id)].copy()
    if scoped.empty:
        return scoped
    return scoped[scoped["status"].astype(str) != "compacted"].copy()


def _canonical_rows(scoped: pd.DataFrame) -> pd.DataFrame:
    if scoped.empty:
        return scoped

    canonical = scoped[scoped["topic_id"].astype(str) == scoped["canonical_topic_id"].astype(str)].copy()
    canonical_ids = set(canonical["canonical_topic_id"].astype(str).tolist())

    missing = scoped[~scoped["canonical_topic_id"].astype(str).isin(canonical_ids)].copy()
    if not missing.empty:
        missing = missing.sort_values(
            ["updated_at", "topic_id"],
            ascending=[False, True],
            kind="stable",
        )
        missing = missing.groupby("canonical_topic_id", as_index=False, sort=True).head(1)
        canonical = pd.concat([canonical, missing], ignore_index=True)

    canonical = canonical.sort_values(
        ["updated_at", "canonical_topic_id", "topic_id"],
        ascending=[False, True, True],
        kind="stable",
    )
    return canonical


def _shard_ordinal(topic_id: str) -> int:
    match = SHARD_ID_RE.search(str(topic_id or ""))
    if not match:
        return 0
    return int(match.group("ordinal"))


def list_topics(payload: Dict[str, Any]) -> Dict[str, Any]:
    data_root = Path(str(payload.get("dataRoot") or "~/.openclaw/clawdb-data")).expanduser()
    tenant_id = str(payload.get("tenantId") or "default")
    batch_size = _safe_int(payload.get("batchSize"), default=50, minimum=1, maximum=500)
    cursor = _safe_int(payload.get("cursor"), default=0, minimum=0, maximum=10_000_000)

    frame = _load_topics_frame(QueryContext(data_root=data_root, tenant_id=tenant_id))
    scoped = _scoped_active(frame, tenant_id)
    canonical = _canonical_rows(scoped)

    shard_counts: Dict[str, int] = {}
    if not scoped.empty:
        shard_rows = scoped[scoped["topic_id"].astype(str) != scoped["canonical_topic_id"].astype(str)].copy()
        if not shard_rows.empty:
            counts = shard_rows.groupby("canonical_topic_id").size().to_dict()
            shard_counts = {str(k): int(v) for k, v in counts.items()}

    total = int(canonical.shape[0])
    if cursor >= total:
        return {
            "items": [],
            "nextCursor": None,
            "total": total,
            "batchSize": batch_size,
            "tenantId": tenant_id,
        }

    window = canonical.iloc[cursor : cursor + batch_size].copy()
    items: List[Dict[str, Any]] = []
    for _, row in window.iterrows():
        canonical_topic_id = str(row.get("canonical_topic_id") or row.get("topic_id") or "default")
        items.append(
            {
                "topicId": canonical_topic_id,
                "topicPath": str(row.get("topic_path") or canonical_topic_id),
                "status": str(row.get("status") or "active"),
                "messageCount": int(row.get("message_count") or 0),
                "summary": str(row.get("summary") or ""),
                "updatedAt": _normalize_ts(row.get("updated_at")),
                "shardCount": int(shard_counts.get(canonical_topic_id, 0)),
            }
        )

    next_cursor = cursor + len(items)
    if next_cursor >= total:
        next_cursor_value: Optional[str] = None
    else:
        next_cursor_value = str(next_cursor)

    return {
        "items": items,
        "nextCursor": next_cursor_value,
        "total": total,
        "batchSize": batch_size,
        "tenantId": tenant_id,
    }


def list_shards(payload: Dict[str, Any]) -> Dict[str, Any]:
    data_root = Path(str(payload.get("dataRoot") or "~/.openclaw/clawdb-data")).expanduser()
    tenant_id = str(payload.get("tenantId") or "default")
    topic_id = str(payload.get("topicId") or "").strip()
    if not topic_id:
        raise ValueError("topicId is required")
    batch_size = _safe_int(payload.get("batchSize"), default=20, minimum=1, maximum=500)
    cursor = _safe_int(payload.get("cursor"), default=0, minimum=0, maximum=10_000_000)

    frame = _load_topics_frame(QueryContext(data_root=data_root, tenant_id=tenant_id))
    scoped = _scoped_active(frame, tenant_id)
    topic_scope = scoped[scoped["canonical_topic_id"].astype(str) == topic_id].copy()
    shard_rows = topic_scope[
        topic_scope["topic_id"].astype(str) != topic_scope["canonical_topic_id"].astype(str)
    ].copy()

    if shard_rows.empty:
        canonical_row = topic_scope[topic_scope["topic_id"].astype(str) == topic_id].copy()
        if canonical_row.empty:
            return {
                "items": [],
                "nextCursor": None,
                "total": 0,
                "batchSize": batch_size,
                "tenantId": tenant_id,
                "topicId": topic_id,
            }
        canonical_row = canonical_row.sort_values(["updated_at"], ascending=[False], kind="stable").head(1)
        row = canonical_row.iloc[0]
        items = [
            {
                "topicId": str(row.get("topic_id") or topic_id),
                "canonicalTopicId": topic_id,
                "topicPath": str(row.get("topic_path") or topic_id),
                "status": str(row.get("status") or "active"),
                "messageCount": int(row.get("message_count") or 0),
                "summary": str(row.get("summary") or ""),
                "updatedAt": _normalize_ts(row.get("updated_at")),
                "shardOrdinal": 0,
                "isCanonical": True,
            }
        ]
        return {
            "items": items,
            "nextCursor": None,
            "total": 1,
            "batchSize": batch_size,
            "tenantId": tenant_id,
            "topicId": topic_id,
        }

    shard_rows = shard_rows.copy()
    shard_rows["_ordinal"] = shard_rows["topic_id"].astype(str).map(_shard_ordinal)
    shard_rows = shard_rows.sort_values(
        ["_ordinal", "updated_at", "topic_id"],
        ascending=[False, False, True],
        kind="stable",
    )

    total = int(shard_rows.shape[0])
    if cursor >= total:
        return {
            "items": [],
            "nextCursor": None,
            "total": total,
            "batchSize": batch_size,
            "tenantId": tenant_id,
            "topicId": topic_id,
        }

    window = shard_rows.iloc[cursor : cursor + batch_size].copy()
    items: List[Dict[str, Any]] = []
    for _, row in window.iterrows():
        items.append(
            {
                "topicId": str(row.get("topic_id") or ""),
                "canonicalTopicId": str(row.get("canonical_topic_id") or topic_id),
                "topicPath": str(row.get("topic_path") or ""),
                "status": str(row.get("status") or "active"),
                "messageCount": int(row.get("message_count") or 0),
                "summary": str(row.get("summary") or ""),
                "updatedAt": _normalize_ts(row.get("updated_at")),
                "shardOrdinal": int(row.get("_ordinal") or 0),
                "isCanonical": False,
            }
        )

    next_cursor = cursor + len(items)
    if next_cursor >= total:
        next_cursor_value: Optional[str] = None
    else:
        next_cursor_value = str(next_cursor)

    return {
        "items": items,
        "nextCursor": next_cursor_value,
        "total": total,
        "batchSize": batch_size,
        "tenantId": tenant_id,
        "topicId": topic_id,
    }


def get_topic(payload: Dict[str, Any]) -> Dict[str, Any]:
    data_root = Path(str(payload.get("dataRoot") or "~/.openclaw/clawdb-data")).expanduser()
    tenant_id = str(payload.get("tenantId") or "default")
    topic_id = str(payload.get("topicId") or "").strip()
    if not topic_id:
        raise ValueError("topicId is required")

    frame = _load_topics_frame(QueryContext(data_root=data_root, tenant_id=tenant_id))
    scoped = _scoped_active(frame, tenant_id)
    row_match = scoped[scoped["topic_id"].astype(str) == topic_id].copy()

    if row_match.empty:
        # Fallback: allow lookup by canonical topic id.
        canonical = scoped[scoped["canonical_topic_id"].astype(str) == topic_id].copy()
        if canonical.empty:
            raise FileNotFoundError(f"topic not found: {topic_id}")
        canonical = canonical.sort_values(
            ["updated_at", "topic_id"],
            ascending=[False, True],
            kind="stable",
        )
        row = canonical.iloc[0]
    else:
        row_match = row_match.sort_values(["updated_at"], ascending=[False], kind="stable")
        row = row_match.iloc[0]

    topic_row_id = str(row.get("topic_id") or topic_id)
    canonical_topic_id = str(row.get("canonical_topic_id") or topic_row_id)
    return {
        "topicId": topic_row_id,
        "canonicalTopicId": canonical_topic_id,
        "topicPath": str(row.get("topic_path") or canonical_topic_id),
        "status": str(row.get("status") or "active"),
        "messageCount": int(row.get("message_count") or 0),
        "summary": str(row.get("summary") or ""),
        "vectorText": str(row.get("vector_text") or row.get("summary") or ""),
        "updatedAt": _normalize_ts(row.get("updated_at")),
        "isShard": topic_row_id != canonical_topic_id,
        "shardOrdinal": _shard_ordinal(topic_row_id),
    }


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: read_clawdb_topics.py <list_topics|list_shards|get_topic>", file=sys.stderr)
        return 2

    action = str(sys.argv[1]).strip()
    payload = _read_stdin_json()

    if action == "list_topics":
        result = list_topics(payload)
    elif action == "list_shards":
        result = list_shards(payload)
    elif action == "get_topic":
        result = get_topic(payload)
    else:
        raise ValueError(f"unsupported action: {action}")

    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
