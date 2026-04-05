#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-17880}"
WS_PATH="${2:-/v1/clawdb-topics/ws}"

if command -v tailscale >/dev/null 2>&1; then
  IP4="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
  if [[ -n "${IP4}" ]]; then
    echo "ws://${IP4}:${PORT}${WS_PATH}"
    exit 0
  fi
fi

echo "tailscale_ip_not_found"
exit 1
