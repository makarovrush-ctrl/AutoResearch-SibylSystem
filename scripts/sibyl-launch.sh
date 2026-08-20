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
# shellcheck source=scripts/sibyl-cost-guards.sh
source "$REPO_ROOT/scripts/sibyl-cost-guards.sh"
[ "$COST_ONLY" = true ] && export SIBYL_NO_AGENT_SWAP=1
sibyl_apply_model "$MODEL"

echo ""
sibyl_model_banner
# Re-assert the cost invariants on every launch. Silent when healthy; if a
# fixed regression has crept back, it says so here before any tokens are spent.
sibyl_cost_guards quiet || true
echo ""

if [ -n "$PROJECT_ARG" ]; then
    "$VENV_PYTHON" -m sibyl.cli cost --scan --banner "$PROJECT_ARG" 2>/dev/null || true
elif [ -d "$REPO_ROOT/workspaces" ]; then
    "$VENV_PYTHON" -m sibyl.cli cost --scan --banner --all 2>/dev/null || true
fi
echo ""

if [ "$COST_ONLY" = false ]; then
    # --plugin-dir is REQUIRED, not optional. Without it the sibyl-research
    # plugin never loads, which means no /sibyl-research:* commands and none of
    # the PreToolUse/PostToolUse/SessionStart/Stop hooks. The orchestration loop
    # is driven entirely by those, so without this flag Sibyl silently degrades
    # into a plain Claude Code session and autoresearch cannot run at all.
    # Cost of loading it: ~485 tokens always-on.
    #
    # --bare was removed deliberately. It is documented as "skip hooks, LSP,
    # plugin sync ... and CLAUDE.md auto-discovery" — every one of which Sibyl
    # depends on. It was added to stop provider hijacking, but that is already
    # guaranteed by sibyl_apply_model (which unsets inherited routing and
    # exports the provider env explicitly) plus the explicit --model/--settings
    # flags below.
    if [ -n "${SIBYL_DRY_RUN:-}" ]; then
        echo "[dry-run] claude --plugin-dir $REPO_ROOT/plugin --dangerously-skip-permissions --model $SIBYL_CLI_MODEL --settings $SIBYL_SETTINGS"
        exit 0
    fi
    exec "$HOME/.local/bin/claude" \
        --plugin-dir "$REPO_ROOT/plugin" \
        --dangerously-skip-permissions \
        --model "$SIBYL_CLI_MODEL" --settings "$SIBYL_SETTINGS"
fi
