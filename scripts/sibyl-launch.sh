#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# Sibyl Launch Wrapper — pins the model, prints a cost meter, starts Claude.
#
# Usage:
#   scripts/sibyl-launch.sh --model anthropic     → Opus 4.8 (quality)
#   scripts/sibyl-launch.sh --model deepseek      → DeepSeek (cost saving)
#   scripts/sibyl-launch.sh --cost                → show costs only
#   scripts/sibyl-launch.sh --project <name>      → costs for one project
#
# There is deliberately NO implicit default: if --model is omitted we use
# anthropic, never the cheap model, so a mistake can't silently downgrade
# your session.
# ═══════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="$REPO_ROOT/.venv/bin/python3"
COST_ONLY=false
PROJECT_ARG=""
MODEL="anthropic"

while [ $# -gt 0 ]; do
    case "$1" in
        --cost) COST_ONLY=true; shift ;;
        --project) PROJECT_ARG="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --bare) shift ;;
        *) shift ;;
    esac
done

# shellcheck source=scripts/sibyl-model-env.sh
source "$REPO_ROOT/scripts/sibyl-model-env.sh"
[ "$COST_ONLY" = true ] && export SIBYL_NO_AGENT_SWAP=1
sibyl_apply_model "$MODEL"

echo ""
sibyl_model_banner
echo ""

if [ -n "$PROJECT_ARG" ]; then
    "$VENV_PYTHON" -m sibyl.cli cost --scan --banner "$PROJECT_ARG" 2>/dev/null || true
elif [ -d "$REPO_ROOT/workspaces" ]; then
    "$VENV_PYTHON" -m sibyl.cli cost --scan --banner --all 2>/dev/null || true
fi
echo ""

if [ "$COST_ONLY" = false ]; then
    exec "$HOME/.local/bin/claude" --bare \
        --model "$SIBYL_CLI_MODEL" --settings "$SIBYL_SETTINGS"
fi
