#!/usr/bin/env bash
# Launch the COMSOL Multiphysics MCP server (wjc9011/COMSOL_Multiphysics_MCP).
# Install first with: scripts/install-comsol-mcp.sh
set -euo pipefail

COMSOL_MCP_HOME="${COMSOL_MCP_HOME:-$HOME/.local/share/mcp-servers/COMSOL_Multiphysics_MCP}"
PY="$COMSOL_MCP_HOME/.venv/bin/python"

if [ ! -x "$PY" ]; then
    echo "COMSOL MCP is not installed at $COMSOL_MCP_HOME" >&2
    echo "Run: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/install-comsol-mcp.sh" >&2
    exit 1
fi

cd "$COMSOL_MCP_HOME"
exec "$PY" -m src.server "$@"
