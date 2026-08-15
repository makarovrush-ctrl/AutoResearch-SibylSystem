#!/bin/bash
# Sibyl shared session launcher — used by every project .command shortcut.
#
# Usage:  resume-session.sh <SESSION_ID> "<Project Label>" [--model anthropic|deepseek]
#
# Self-heals dead sessions (live store -> OneDrive backup -> honest failure)
# AND pins the model: a session resumes on the same model it was created
# with, so an Opus conversation can never silently continue on DeepSeek.

set -u
SID="${1:?session id required}"
LABEL="${2:-this project}"
FORCED_MODEL="${4:-}"
[ "${3:-}" = "--model" ] || FORCED_MODEL=""

WORKDIR="/Users/mackenzieboi/sibyl-research-system"
CLAUDE="$HOME/.local/bin/claude"
PROJ="$HOME/.claude/projects/-Users-mackenzieboi-sibyl-research-system"
BACKUP_BASE="$HOME/Library/CloudStorage/OneDrive-TheUniversityofSydney(Staff)/SibylTransfer/claude-brain/projects"

cd "$WORKDIR" || { echo "Cannot cd to $WORKDIR"; exit 1; }
[ -x "$CLAUDE" ] || CLAUDE="$(command -v claude || echo claude)"
source "$WORKDIR/scripts/sibyl-model-env.sh"

# Resume on the model recorded in the transcript (fall back to quality mode).
launch() {
  local kind origin last exact=""
  if [ -n "$FORCED_MODEL" ]; then
    kind="$FORCED_MODEL"; origin="forced by --model"
  else
    last=$(grep -o '"model":"[^"]*"' "$PROJ/$SID.jsonl" 2>/dev/null \
           | sed 's/"model":"//; s/"$//' | grep -v '^<synthetic>$' | tail -1)
    case "$last" in
      deepseek*) kind="deepseek";  exact="$last"; origin="detected from transcript ($last)" ;;
      claude*)   kind="anthropic"; exact="$last"; origin="detected from transcript ($last)" ;;
      *)         kind="anthropic"; exact="";      origin="no model recorded — defaulting to quality mode" ;;
    esac
  fi
  sibyl_apply_model "$kind"
  local default_model; default_model="$(sibyl_default_model_for "$kind")"
  if [ -n "${exact:-}" ] && [ "$exact" != "$default_model" ]; then
    if [ -n "${SIBYL_KEEP_EXACT_MODEL:-}" ]; then
      sibyl_pin_exact_model "$exact"
      origin="$origin — kept exactly (SIBYL_KEEP_EXACT_MODEL=1)"
    elif [ "$(sibyl_model_api_id "$exact")" = "$(sibyl_model_api_id "$default_model")" ]; then
      :
    else
      origin="$origin — upgraded to your default $(sibyl_model_label "$default_model")"
    fi
  fi
  echo ""
  sibyl_model_banner
  echo "      ($origin)"
  echo ""
  if [ -n "${SIBYL_DRY_RUN:-}" ]; then
    echo "[dry-run] claude --resume $SID --model $SIBYL_CLI_MODEL --settings $SIBYL_SETTINGS"
    exit 0
  fi
  # --plugin-dir: plugins are per-session, so a resumed Sibyl session without
  # it loses all /sibyl-research:* commands and orchestration hooks.
  exec "$CLAUDE" --plugin-dir "$HOME/sibyl-research-system/plugin" \
    --resume "$SID" --model "$SIBYL_CLI_MODEL" --settings "$SIBYL_SETTINGS"
}

# 1. Live session present.
if [ -f "$PROJ/$SID.jsonl" ]; then
  echo "Resuming '$LABEL'  ($SID)"
  launch
fi

# 2. Recover from OneDrive backup.
BK="$(find "$BACKUP_BASE" -name "$SID.jsonl" 2>/dev/null | head -1)"
if [ -n "$BK" ]; then
  echo "'$LABEL' was pruned from the live store — restoring from OneDrive backup..."
  mkdir -p "$PROJ"
  if cp "$BK" "$PROJ/$SID.jsonl"; then
    echo "Restored. Resuming '$LABEL'  ($SID)"
    launch
  fi
  echo "Restore failed (OneDrive not synced?)."
fi

# 3. Truly gone. Be honest — do not fake a resume.
echo
echo "======================================================================"
echo " '$LABEL'"
echo " Session $SID is no longer available."
echo " It was pruned from Claude Code's store and is not in the OneDrive"
echo " backup, so its conversation history cannot be recovered."
echo "======================================================================"
echo
echo "Options:"
echo "  [Enter]  start a FRESH session (Opus 4.8, quality mode)"
echo "  [d]      start a FRESH session on DeepSeek (cost-saving)"
echo "  [q]      quit without doing anything"
echo
printf "Choice: "
read -r ans
case "$ans" in
  q|Q) echo "Aborted."; exit 0 ;;
  d|D) sibyl_apply_model deepseek ;;
  *)   sibyl_apply_model anthropic ;;
esac
echo "Starting a fresh session..."
sibyl_model_banner
exec "$CLAUDE" --model "$SIBYL_CLI_MODEL" --settings "$SIBYL_SETTINGS"
