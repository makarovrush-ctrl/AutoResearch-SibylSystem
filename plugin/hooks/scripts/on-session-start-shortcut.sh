#!/usr/bin/env bash
# SessionStart Hook — guarantee the conversation resume shortcut EXISTS.
#
# Step Zero in CLAUDE.md says the shortcut must be created before any other
# work. Relying on the model to remember that has failed repeatedly ("where is
# the shortcut again???????"). This hook removes memory from the equation: the
# shortcut is written the moment the session starts.
#
# At SessionStart the conversation has no topic yet, so the title is a
# placeholder. on-stop-shortcut.sh retitles it from the transcript once there
# is something to name it after. That two-phase split is deliberate: existence
# is guaranteed immediately, a good name arrives later.
#
# Pattern is copied verbatim from docs/shortcut-pattern.txt — do not invent.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/sibyl-hook-utils.sh"

INPUT=$(sibyl_read_hook_input)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
[ -n "$SESSION_ID" ] || exit 0

CONV_DIR="$HOME/Desktop/Sibyl Projects/Conversations"
mkdir -p "$CONV_DIR/Readable" 2>/dev/null || exit 0

# Already have a shortcut for this session? Leave it alone — it may already
# carry a real title from a previous Stop hook.
if grep -rlq "$SESSION_ID" "$CONV_DIR"/*.command 2>/dev/null; then
    exit 0
fi

DATE=$(date +%Y-%m-%d)
SC="$CONV_DIR/▶️ $DATE - Untitled session.command"
# Never clobber a different session's shortcut that shares the placeholder name.
n=2
while [ -e "$SC" ]; do
    SC="$CONV_DIR/▶️ $DATE - Untitled session ($n).command"
    n=$((n + 1))
done

cat > "$SC" <<EOF
#!/bin/bash
# ▶️ $DATE - Untitled session
# Model is auto-detected from the transcript so this conversation
# always resumes on the model it was created with.
exec "\$HOME/sibyl-research-system/scripts/sibyl-resume.sh" "$SESSION_ID" "let's continue where we left off"
EOF
chmod +x "$SC" 2>/dev/null

# Self-verify per SOP step 7: syntax must parse and file must be executable.
if ! bash -n "$SC" 2>/dev/null || [ ! -x "$SC" ]; then
    rm -f "$SC"
    exit 0
fi

# NOTE: not using sibyl_inject_context() here — it hardcodes
# "hookEventName":"PostToolUse", which is wrong for a SessionStart hook and
# would make the harness discard this context.
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' \
    "[SHORTCUT-HOOK] Resume shortcut auto-created: $(basename "$SC" | sed 's/"/\\"/g'). Step Zero is already satisfied — do NOT create another. It is retitled automatically when the session ends."
exit 0
