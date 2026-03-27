#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ID="spare-life-openclaw-plugin"
CHANNEL_ID="clawdb-topics"
PROFILE="${OPENCLAW_PROFILE:-}"
CHANNEL_PORT="${CLAWDB_TOPICS_PORT:-17880}"
CHANNEL_HOST="${CLAWDB_TOPICS_HOST:-0.0.0.0}"
DATA_ROOT="${CLAWDB_TOPICS_DATA_ROOT:-~/.openclaw/clawdb-data}"
TENANT_ID="${CLAWDB_TOPICS_TENANT_ID:-default}"
HTTP_BASE_PATH="${CLAWDB_TOPICS_HTTP_BASE_PATH:-/v1/clawdb-topics}"
WS_PATH="${CLAWDB_TOPICS_WS_PATH:-/v1/clawdb-topics/ws}"
PUBLIC_BASE_URL="${CLAWDB_TOPICS_PUBLIC_BASE_URL:-}"
PYTHON_BIN_OVERRIDE="${CLAWDB_TOPICS_PYTHON_BIN:-}"

discover_python_with_pandas() {
  local candidates=()
  if [[ -n "${PYTHON_BIN_OVERRIDE}" ]]; then
    candidates+=("${PYTHON_BIN_OVERRIDE}")
  fi
  candidates+=("${HOME}/anaconda3/bin/python3" "${HOME}/anaconda3/bin/python" "python3" "python")
  for candidate in "${candidates[@]}"; do
    if [[ -z "${candidate}" ]]; then
      continue
    fi
    local resolved="${candidate}"
    if [[ "${candidate}" != */* ]]; then
      resolved="$(command -v "${candidate}" 2>/dev/null || true)"
    fi
    if [[ -z "${resolved}" || ! -x "${resolved}" ]]; then
      continue
    fi
    if "${resolved}" - <<'PY' >/dev/null 2>&1
import pandas
PY
    then
      echo "${resolved}"
      return 0
    fi
  done
  return 1
}

OPENCLAW_ARGS=()
if [[ -n "${PROFILE}" ]]; then
  OPENCLAW_ARGS+=(--profile "${PROFILE}")
fi

if [[ -z "${PUBLIC_BASE_URL}" ]] && command -v tailscale >/dev/null 2>&1; then
  TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
  if [[ -n "${TAILSCALE_IP}" ]]; then
    PUBLIC_BASE_URL="http://${TAILSCALE_IP}:${CHANNEL_PORT}"
  fi
fi

PYTHON_BIN_VALUE="$(discover_python_with_pandas || true)"
if [[ -z "${PYTHON_BIN_VALUE}" ]]; then
  echo "warning: could not find a python with pandas; channel may fail until channels.clawdb-topics.pythonBin is set"
fi

echo "installing plugin from ${ROOT_DIR}"
openclaw "${OPENCLAW_ARGS[@]}" plugins install "${ROOT_DIR}" --link >/dev/null

CONFIG_FILE_RAW="$(openclaw "${OPENCLAW_ARGS[@]}" config file 2>&1 || true)"
CONFIG_FILE="$(printf '%s\n' "${CONFIG_FILE_RAW}" | grep -Eo '(~|/)[^[:space:]]*openclaw[^[:space:]]*\.json' | tail -n1 || true)"
if [[ -z "${CONFIG_FILE}" ]]; then
  if [[ -n "${PROFILE}" ]]; then
    CONFIG_FILE="${HOME}/.openclaw-${PROFILE}/openclaw.json"
  else
    CONFIG_FILE="${HOME}/.openclaw/openclaw.json"
  fi
fi
if [[ "${CONFIG_FILE}" == ~* ]]; then
  CONFIG_FILE="${HOME}${CONFIG_FILE#\~}"
fi
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "failed to resolve openclaw config file from output:"
  echo "${CONFIG_FILE_RAW}"
  exit 1
fi
python3 - "${CONFIG_FILE}" "${PLUGIN_ID}" "${CHANNEL_ID}" "${CHANNEL_HOST}" "${CHANNEL_PORT}" "${DATA_ROOT}" "${TENANT_ID}" "${HTTP_BASE_PATH}" "${WS_PATH}" "${PUBLIC_BASE_URL}" "${PYTHON_BIN_VALUE}" <<'PY'
import json
import sys
from pathlib import Path

cfg_path = Path(sys.argv[1]).expanduser()
plugin_id = sys.argv[2]
channel_id = sys.argv[3]
channel_host = sys.argv[4]
channel_port = int(sys.argv[5])
data_root = sys.argv[6]
tenant_id = sys.argv[7]
http_base_path = sys.argv[8]
ws_path = sys.argv[9]
public_base_url = sys.argv[10]
python_bin = sys.argv[11]
legacy_plugin_id = "spare-life-clawdb-topics"

payload = json.loads(cfg_path.read_text(encoding="utf-8"))
payload.setdefault("plugins", {})
payload["plugins"].setdefault("allow", [])
payload["plugins"]["allow"] = [
    item for item in payload["plugins"]["allow"] if str(item) != legacy_plugin_id
]
if plugin_id not in payload["plugins"]["allow"]:
    payload["plugins"]["allow"].append(plugin_id)

payload["plugins"].setdefault("entries", {})
payload["plugins"]["entries"].pop(legacy_plugin_id, None)
entry = payload["plugins"]["entries"].get(plugin_id, {})
entry["enabled"] = True
payload["plugins"]["entries"][plugin_id] = entry

payload.setdefault("channels", {})
channel = payload["channels"].get(channel_id, {})
channel.update(
    {
        "enabled": True,
        "host": channel_host,
        "port": channel_port,
        "dataRoot": data_root,
        "tenantId": tenant_id,
        "httpBasePath": http_base_path,
        "wsPath": ws_path,
    }
)
if public_base_url:
    channel["publicBaseUrl"] = public_base_url
if python_bin:
    channel["pythonBin"] = python_bin
payload["channels"][channel_id] = channel

cfg_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo "installed plugin id=${PLUGIN_ID} channel=${CHANNEL_ID}"
echo "config file: ${CONFIG_FILE}"

if [[ -n "${PUBLIC_BASE_URL}" ]]; then
  PUBLIC_WS_URL="${PUBLIC_BASE_URL/http:\/\//ws:\/\//}${WS_PATH}"
  PUBLIC_WS_URL="${PUBLIC_WS_URL/https:\/\//wss:\/\/}"
  echo "public_base_url=${PUBLIC_BASE_URL}"
  echo "public_ws_url=${PUBLIC_WS_URL}"
fi

echo "next: start OpenClaw gateway so the channel runtime can maintain the long websocket service"
echo "  openclaw ${OPENCLAW_ARGS[*]} gateway"
echo "verify channel status"
echo "  openclaw ${OPENCLAW_ARGS[*]} channels status --json"
