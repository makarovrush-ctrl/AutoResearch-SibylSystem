#!/bin/bash
# Sibyl Research System — continue latest session, model chosen explicitly.
#   default        → Anthropic Opus (quality)
#   --deepseek     → DeepSeek (cost saving)
WORKDIR="/Users/mackenzieboi/sibyl-research-system"
cd "$WORKDIR" || exit 1

MODEL="anthropic"
case "${1:-}" in
    --deepseek|--cheap) MODEL="deepseek" ;;
esac

source "$WORKDIR/scripts/sibyl-model-env.sh"
sibyl_apply_model "$MODEL"

clear
echo ""
sibyl_model_banner
echo ""
.venv/bin/python3 -m sibyl.cli cost --scan --banner --all 2>/dev/null || echo "  (cost data will appear after pipeline runs)"
echo ""

SESSION_DIR="$HOME/.claude/projects/$(echo "$WORKDIR" | sed 's|/|-|g')"
# --plugin-dir loads the sibyl-research plugin (16 commands + 4 hooks). Without
# it this shortcut starts a plain Claude Code session with no /sibyl-research:*
# commands and no orchestration hooks — which is why autoresearch had not run
# since 20 Jul.
if [ -d "$SESSION_DIR" ] && [ -n "$(ls -A "$SESSION_DIR" 2>/dev/null)" ]; then
  exec ~/.local/bin/claude --plugin-dir "$WORKDIR/plugin" --continue \
    --model "$SIBYL_CLI_MODEL" --settings "$SIBYL_SETTINGS"
else
  exec ~/.local/bin/claude --plugin-dir "$WORKDIR/plugin" \
    --model "$SIBYL_CLI_MODEL" --settings "$SIBYL_SETTINGS"
fi
