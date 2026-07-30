#!/bin/bash
# On every new conversation start, remind to save the shortcut EARLY.
# Prints a visible reminder that Claude will see.

DESKTOP_DIR="$HOME/Desktop/Sibyl Projects/Conversations"
PROJECT_DIR="$HOME/.claude/projects/-Users-mackenzieboi-sibyl-research-system"

cat << MSG

╔══════════════════════════════════════════════════════════╗
║  ⚠️  REMINDER: Save the conversation shortcut NOW       ║
║                                                          ║
║  SOP (from Mack):                                        ║
║  1. Get session UUID from latest .jsonl                  ║
║  2. Save .command shortcut to:                           ║
║     ~/Desktop/Sibyl Projects/Conversations/              ║
║     Format: ▶️ YYYY-MM-DD - <descriptive title>.command  ║
║  3. chmod +x the shortcut                                ║
║                                                          ║
║  DO NOT wait until conversation end. Do it NOW.          ║
╚══════════════════════════════════════════════════════════╝

MSG

# Auto-save the shortcut immediately if possible
LATEST_JSONL=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)
if [ -n "$LATEST_JSONL" ] && [ "$(stat -f %m "$LATEST_JSONL" 2>/dev/null)" -gt "$(date -v-60S +%s 2>/dev/null || echo 0)" ]; then
    UUID=$(basename "$LATEST_JSONL" .jsonl)
    TIMESTAMP=$(date +"%Y-%m-%d")
    
    # Try to get a title from the first user message
    TITLE=$(head -1 "$LATEST_JSONL" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    content = d.get('message', {}).get('content', '')
    if isinstance(content, list):
        content = content[0].get('text', '') if content else ''
    title = content[:80].replace('\n', ' ').strip()
    print(title)
except:
    print('Untitled conversation')
" 2>/dev/null)
    
    if [ -z "$TITLE" ]; then TITLE="Untitled conversation"; fi
    SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/:*?"<>|]/-/g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    LAUNCHER="$DESKTOP_DIR/▶️ ${TIMESTAMP} - ${SAFE_TITLE}.command"
    
    if [ ! -f "$LAUNCHER" ]; then
        mkdir -p "$DESKTOP_DIR"
        cat << LAUNCHER_EOF > "$LAUNCHER"
#!/bin/bash
# ${SAFE_TITLE}
# Resumes on the same model this conversation was created with
# (auto-detected from the transcript). Override with: --model anthropic|deepseek
exec "\$HOME/sibyl-research-system/scripts/sibyl-resume.sh" "${UUID}" "let's continue where we left off"
LAUNCHER_EOF
        chmod +x "$LAUNCHER"
        echo "✅ Auto-saved shortcut: ${LAUNCHER}"
    fi
fi
