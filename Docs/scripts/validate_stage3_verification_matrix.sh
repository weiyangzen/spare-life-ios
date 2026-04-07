#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"

echo "[stage3-verification-matrix] lane=plugin-demo"
bash Docs/scripts/validate_stage3_openclaw_im_smoke.sh

echo "[stage3-verification-matrix] lane=client-only-local-seed path+shared+routes+macos"
bash Docs/scripts/validate_ios_paths.sh
bash Docs/scripts/validate_stage3_shared_surface.sh
bash Docs/scripts/validate_stage3_messages_typed_routes.sh
bash Docs/scripts/validate_stage3_macos_smoke.sh

echo "[stage3-verification-matrix] lane=server-backed-joint-debug"
bash Docs/scripts/validate_stage3_joint_debug_contracts.sh

echo "[stage3-verification-matrix] complete"
