#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# Resume a Sibyl conversation on the SAME model it was created with.
#
#   scripts/sibyl-resume.sh <session-uuid> [prompt]
#   scripts/sibyl-resume.sh <session-uuid> --model anthropic [prompt]
#
# Model is auto-detected from the session transcript, so an Opus
# conversation always resumes as Opus and a DeepSeek conversation always
# resumes as DeepSeek. Override any time with --model.
# ═══════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1
# shellcheck source=scripts/sibyl-model-env.sh
source "$REPO_ROOT/scripts/sibyl-model-env.sh"

SESSION_ID="${1:-}"; shift || true
FORCED_MODEL=""
EXACT=""
PROMPT="let's continue where we left off"
if [ "${1:-}" = "--model" ]; then FORCED_MODEL="${2:-}"; shift 2 || true; fi
if [ $# -gt 0 ] && [ -n "$1" ]; then PROMPT="$1"; fi

if [ -z "$SESSION_ID" ]; then
    echo "usage: sibyl-resume.sh <session-uuid> [--model anthropic|deepseek] [prompt]" >&2
    exit 1
fi

TRANSCRIPT="$HOME/.claude/projects/-Users-mackenzieboi-sibyl-research-system/${SESSION_ID}.jsonl"

detect_model() {
    [ -f "$TRANSCRIPT" ] || return 1
    grep -o '"model":"[^"]*"' "$TRANSCRIPT" 2>/dev/null \
        | sed 's/"model":"//; s/"$//' \
        | grep -v '^<synthetic>$' \
        | tail -1
}

if [ -n "$FORCED_MODEL" ]; then
    KIND="$FORCED_MODEL"
    ORIGIN="forced by --model"
else
    LAST_MODEL="$(detect_model || true)"
    case "$LAST_MODEL" in
        deepseek*) KIND="deepseek";  EXACT="$LAST_MODEL"; ORIGIN="detected from transcript ($LAST_MODEL)" ;;
        claude*)   KIND="anthropic"; EXACT="$LAST_MODEL"; ORIGIN="detected from transcript ($LAST_MODEL)" ;;
        *)         KIND="anthropic"; EXACT="";            ORIGIN="no record found — defaulting to quality mode" ;;
    esac
fi

sibyl_apply_model "$KIND"
    # Provider is preserved absolutely. The model *within* the provider is
    # upgraded to your configured default (e.g. an old Opus 4.8 chat reopens on
    # Opus 5) — an upgrade, never a downgrade, and always announced.
    # Set SIBYL_KEEP_EXACT_MODEL=1 to reopen on the exact original model.
DEFAULT_MODEL="$(sibyl_default_model_for "$KIND")"
if [ -n "${EXACT:-}" ] && [ "$EXACT" != "$DEFAULT_MODEL" ]; then
    if [ -n "${SIBYL_KEEP_EXACT_MODEL:-}" ]; then
        sibyl_pin_exact_model "$EXACT"
        ORIGIN="$ORIGIN — kept exactly (SIBYL_KEEP_EXACT_MODEL=1)"
    elif [ "$(sibyl_model_api_id "$EXACT")" = "$(sibyl_model_api_id "$DEFAULT_MODEL")" ]; then
        : # same underlying model, different alias — keep the configured default
    else
        ORIGIN="$ORIGIN — upgraded to your default $(sibyl_model_label "$DEFAULT_MODEL")"
    fi
fi

clear
echo "  Resuming session: $SESSION_ID"
sibyl_model_banner
echo "      ($ORIGIN)"
echo ""

if [ -n "${SIBYL_DRY_RUN:-}" ]; then
    echo "[dry-run] claude --resume $SESSION_ID --model $SIBYL_CLI_MODEL --settings $SIBYL_SETTINGS"
    exit 0
fi

exec "$HOME/.local/bin/claude" --resume "$SESSION_ID" \
    --model "$SIBYL_CLI_MODEL" --settings "$SIBYL_SETTINGS" "$PROMPT"
