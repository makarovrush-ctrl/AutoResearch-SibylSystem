#!/usr/bin/env bash
# Linux/macOS wrapper around scripts/run_comsol_mcp.py
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/comsol-mcp-env.sh
source "$SCRIPT_DIR/comsol-mcp-env.sh"
comsol_mcp_export
if command -v python3 >/dev/null 2>&1; then
    exec python3 "$SCRIPT_DIR/run_comsol_mcp.py" "$@"
fi
exec python "$SCRIPT_DIR/run_comsol_mcp.py" "$@"
