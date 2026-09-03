#!/usr/bin/env bash
# Launch the COMSOL Multiphysics MCP server (wjc9011/COMSOL_Multiphysics_MCP).
# Install first with: scripts/install-comsol-mcp.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/comsol-mcp-env.sh
source "$SCRIPT_DIR/comsol-mcp-env.sh"
comsol_mcp_export

COMSOL_MCP_HOME="${COMSOL_MCP_HOME:-$HOME/.local/share/mcp-servers/COMSOL_Multiphysics_MCP}"
PY="$COMSOL_MCP_HOME/.venv/bin/python"

if [ ! -x "$PY" ]; then
    echo "COMSOL MCP is not installed at $COMSOL_MCP_HOME" >&2
    echo "Run: $(cd "$SCRIPT_DIR/.." && pwd)/scripts/install-comsol-mcp.sh" >&2
    exit 1
fi

unix_root="$(comsol_mcp_unix_path "$COMSOL_ROOT")"
if ! comsol_mcp_looks_like_root "$unix_root"; then
    echo "COMSOL Multiphysics was not found at $COMSOL_ROOT" >&2
    echo "Shortcut target is COMSOL 6.2 at:" >&2
    echo "  C:\\Program Files\\COMSOL\\COMSOL62\\Multiphysics_copy1\\bin\\win64\\comsol.exe" >&2
    echo "This launcher can only start that Windows binary on the Windows machine that owns the install." >&2
fi

cd "$COMSOL_MCP_HOME"
exec "$PY" -m src.server "$@"
