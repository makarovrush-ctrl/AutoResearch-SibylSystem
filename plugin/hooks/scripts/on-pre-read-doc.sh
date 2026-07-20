#!/usr/bin/env bash
# PreToolUse(Read) Hook — token-saving redirect for document reads.
#
# Reading a PDF/Office/ebook file via the native Read tool renders it as
# costly multimodal (page-image) tokens. markitdown converts these formats
# to plain Markdown text at a fraction of the cost. This hook intercepts
# Read calls on convertible documents, converts (and caches) a `<file>.md`
# sidecar via sibyl.doc_converter, and denies the original read with a
# reason pointing the agent at the cheap sidecar instead.
#
# Image formats are deliberately excluded — screenshots/UI captures must
# stay readable natively for visual inspection (see global CLAUDE.md).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/sibyl-hook-utils.sh"

INPUT=$(sibyl_read_hook_input)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
[ -n "$FILE_PATH" ] || exit 0
[ -f "$FILE_PATH" ] || exit 0

EXT_LC=$(echo "${FILE_PATH##*.}" | tr '[:upper:]' '[:lower:]')
case "$EXT_LC" in
    pdf|doc|docx|ppt|pptx|xls|xlsx|epub|msg|eml|odt) ;;
    *) exit 0 ;;
esac

MD_PATH="${FILE_PATH}.md"
NEED_CONVERT=1
if [ -f "$MD_PATH" ]; then
    SRC_MTIME=$(stat -f %m "$FILE_PATH" 2>/dev/null || stat -c %Y "$FILE_PATH" 2>/dev/null || echo 0)
    MD_MTIME=$(stat -f %m "$MD_PATH" 2>/dev/null || stat -c %Y "$MD_PATH" 2>/dev/null || echo 0)
    [ "$MD_MTIME" -ge "$SRC_MTIME" ] && NEED_CONVERT=0
fi

if [ "$NEED_CONVERT" = "1" ]; then
    [ -x "$SIBYL_PYTHON" ] || exit 0
    "$SIBYL_PYTHON" -m sibyl.doc_converter "$FILE_PATH" >/dev/null 2>&1 || exit 0
fi

# Conversion failed to produce output (e.g. scanned/image-only doc with no
# text layer) — fall back to letting the native Read handle it.
[ -s "$MD_PATH" ] || exit 0

REASON="Token-saving redirect: read ${MD_PATH} instead — a markitdown-converted plain-Markdown version of this file. Reading ${FILE_PATH} natively renders it as costly multimodal tokens."
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' \
    "$(echo "$REASON" | sed 's/"/\\"/g')"
