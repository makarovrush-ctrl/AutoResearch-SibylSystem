#!/usr/bin/env bash
# Install wjc9011/COMSOL_Multiphysics_MCP into a dedicated venv and register it.
#
# Usage:
#   scripts/install-comsol-mcp.sh
#
# The MCP Python package is installed under:
#   ~/.local/share/mcp-servers/COMSOL_Multiphysics_MCP
#
# Runtime still requires a local COMSOL Multiphysics 5.x/6.x install plus Java.
# This script does not install COMSOL itself.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMSOL_MCP_HOME="${COMSOL_MCP_HOME:-$HOME/.local/share/mcp-servers/COMSOL_Multiphysics_MCP}"
COMSOL_MCP_REPO="${COMSOL_MCP_REPO:-https://github.com/wjc9011/COMSOL_Multiphysics_MCP.git}"
SERVER_NAME="comsol"

if command -v python3.12 >/dev/null 2>&1; then
    PY=python3.12
elif command -v python3 >/dev/null 2>&1; then
    PY=python3
else
    echo "ERROR: Python 3.10+ is required to install COMSOL MCP." >&2
    exit 1
fi

PY_OK="$("$PY" -c 'import sys; print(int(sys.version_info[:2] >= (3, 10)))')"
if [ "$PY_OK" != "1" ]; then
    echo "ERROR: Python 3.10+ is required, found $($PY --version 2>&1)." >&2
    exit 1
fi

mkdir -p "$(dirname "$COMSOL_MCP_HOME")"
if [ -d "$COMSOL_MCP_HOME/.git" ]; then
    echo "Updating existing clone at $COMSOL_MCP_HOME"
    git -C "$COMSOL_MCP_HOME" pull --ff-only
else
    echo "Cloning $COMSOL_MCP_REPO"
    git clone --depth 1 "$COMSOL_MCP_REPO" "$COMSOL_MCP_HOME"
fi

if [ ! -x "$COMSOL_MCP_HOME/.venv/bin/python" ]; then
    echo "Creating virtual environment with $PY"
    "$PY" -m venv "$COMSOL_MCP_HOME/.venv"
fi

echo "Installing comsol-mcp and dependencies"
"$COMSOL_MCP_HOME/.venv/bin/pip" install -U pip setuptools wheel
"$COMSOL_MCP_HOME/.venv/bin/pip" install -e "$COMSOL_MCP_HOME"

merge_mcp_json() {
    local config_path="$1"
    local command="$2"
    local cwd="$3"
    "$PY" - "$config_path" "$SERVER_NAME" "$command" "$cwd" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1]).expanduser()
server_name = sys.argv[2]
command = sys.argv[3]
cwd = sys.argv[4]
entry = {
    "command": command,
    "args": [],
    "cwd": cwd,
    "env": {},
}

data = {}
if config_path.exists():
    try:
        loaded = json.loads(config_path.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            data = loaded
    except json.JSONDecodeError:
        print(f"  ! {config_path} is not valid JSON; leaving it unchanged", file=sys.stderr)
        sys.exit(0)

servers = data.get("mcpServers")
if not isinstance(servers, dict):
    servers = {}
    data["mcpServers"] = servers
servers[server_name] = entry
config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"  registered {server_name} in {config_path}")
PY
}

COMMAND="$COMSOL_MCP_HOME/.venv/bin/comsol-mcp"
echo "Registering MCP server as '$SERVER_NAME'"
if command -v claude >/dev/null 2>&1; then
    if claude mcp add --scope local "$SERVER_NAME" -- "$COMMAND"; then
        echo "  registered via claude mcp add --scope local"
    else
        echo "  claude mcp add failed; writing JSON configs instead"
    fi
else
    echo "  Claude Code CLI not found — writing JSON MCP configs"
fi

merge_mcp_json "$HOME/.cursor/mcp.json" "$COMMAND" "$COMSOL_MCP_HOME"
merge_mcp_json "$HOME/.mcp.json" "$COMMAND" "$COMSOL_MCP_HOME"
if [ -f "$REPO_ROOT/.mcp.json" ]; then
    merge_mcp_json "$REPO_ROOT/.mcp.json" "$COMMAND" "$COMSOL_MCP_HOME"
fi

echo ""
echo "COMSOL MCP installed."
echo "  source: $COMSOL_MCP_HOME"
echo "  launch: $REPO_ROOT/scripts/run-comsol-mcp.sh"
echo "  tools:  mcp__comsol__comsol_start, mcp__comsol__model_create, ..."
echo ""
echo "Restart Cursor / Claude Code so the new MCP server is loaded."
echo "A licensed COMSOL Multiphysics 5.x/6.x install is still required before comsol_start can open a client."
