#!/bin/bash
# Auto-save conversation shortcut to:
#   ~/Desktop/Sibyl Projects/Conversations/
# Matches established naming convention: ▶️ YYYY-MM-DD - title.command

DESKTOP_DIR="$HOME/Desktop/Sibyl Projects/Conversations"
READABLE_DIR="$DESKTOP_DIR/Readable"
mkdir -p "$DESKTOP_DIR" "$READABLE_DIR"

# Find the most recent conversation UUID
PROJECT_DIR="$HOME/.claude/projects/-Users-mackenzieboi-sibyl-research-system"
LATEST_JSONL=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)

if [ -z "$LATEST_JSONL" ]; then
    echo "No conversation found."
    exit 0
fi

UUID=$(basename "$LATEST_JSONL" .jsonl)
TIMESTAMP=$(date +"%Y-%m-%d")

# Try to extract a title from the first user message
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

if [ -z "$TITLE" ]; then
    TITLE="Untitled conversation"
fi

# Sanitize title for filename
SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/:*?"<>|]/-/g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Create launcher
LAUNCHER="$DESKTOP_DIR/▶️ ${TIMESTAMP} - ${SAFE_TITLE}.command"

cat << EOF > "$LAUNCHER"
#!/bin/bash
cd "\$HOME/sibyl-research-system" || exit 1
clear
echo "🔄 Resuming: ${SAFE_TITLE}"
echo "   Session: ${UUID}"
echo ""
claude --resume "${UUID}" "let's continue where we left off"
EOF

chmod +x "$LAUNCHER"

# Create readable markdown
MARKDOWN="$READABLE_DIR/${TIMESTAMP} - ${SAFE_TITLE}.md"
cat << MDEOF > "$MARKDOWN"
# ${SAFE_TITLE}
**Date:** ${TIMESTAMP}
**Session:** ${UUID}
**Project:** sibyl-research-system

*Auto-saved conversation shortcut.*
MDEOF

echo "✓ Shortcut saved: ${LAUNCHER}"
echo "✓ Readable saved: ${MARKDOWN}"
