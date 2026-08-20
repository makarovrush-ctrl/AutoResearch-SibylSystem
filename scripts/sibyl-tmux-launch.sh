#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# Sibyl tmux Launcher — run EVERY active project in its own tmux window.
#
# Each project gets:
#   • a Claude Code pane auto-started with the control-plane loop prompt, and
#   • a Sentinel sibling pane (sibyl/sentinel.sh) that revives Claude if it
#     dies or stalls while the project is still active.
#
# This is the "one session per project" topology the Sentinel ownership
# model assumes (cli_sentinel_session flags an ownership_conflict if one
# pane/session tries to own two projects), so one window per project is the
# correct shape — not a single session iterating over all of them.
#
# Usage:
#   scripts/sibyl-tmux-launch.sh --model deepseek
#   scripts/sibyl-tmux-launch.sh --model anthropic --session sibyl
#   scripts/sibyl-tmux-launch.sh --model deepseek --project centriflow
#   scripts/sibyl-tmux-launch.sh --model deepseek --dry-run
# ═══════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="$REPO_ROOT/.venv/bin/python3"
CLAUDE_BIN="$HOME/.local/bin/claude"

MODEL="deepseek"
SESSION_NAME="sibyl"
PROJECT_FILTER=""
DRY_RUN=0
IGNORE=(test-cli-proj)

usage() {
    cat <<'EOF'
Usage: sibyl-tmux-launch.sh [options]

Options:
  --model <kind>     anthropic | deepseek          (default: deepseek)
  --session <name>   tmux session name             (default: sibyl)
  --project <name>   run only this one project     (default: all active)
  --exclude <name>   also skip this project name   (repeatable)
  --dry-run          print what would run, exit

If the tmux session already exists, nothing is started (attach with
`tmux attach -t <session>`). To restart cleanly: `tmux kill-session -t <session>`.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --model)   MODEL="$2"; shift 2 ;;
        --session) SESSION_NAME="$2"; shift 2 ;;
        --project) PROJECT_FILTER="$2"; shift 2 ;;
        --exclude) IGNORE+=("$2"); shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

# shellcheck source=scripts/sibyl-model-env.sh
source "$REPO_ROOT/scripts/sibyl-model-env.sh"
# shellcheck source=scripts/sibyl-cost-guards.sh
source "$REPO_ROOT/scripts/sibyl-cost-guards.sh"
sibyl_apply_model "$MODEL"

if ! command -v tmux >/dev/null 2>&1; then
    echo "❌ tmux is not installed. Install it first:" >&2
    echo "   brew install tmux" >&2
    exit 1
fi

# ── Enumerate active projects + write each project's bootstrap prompt ──
# Python is authoritative for: config.yaml workspaces_dir, done/stopped
# filtering, and the per-project prompt text (avoids shell-quoting hazards).
PROJECTS="$("$VENV_PYTHON" - "$REPO_ROOT" "$PROJECT_FILTER" "${IGNORE[@]}" <<'PY'
import json, sys
from pathlib import Path

repo = Path(sys.argv[1])
filter_name = sys.argv[2] or None
ignore = set(sys.argv[3:])

import yaml
cfg = yaml.safe_load((repo / "config.yaml").read_text(encoding="utf-8")) or {}
ws_dir = Path(cfg.get("workspaces_dir", repo / "workspaces")).expanduser()
if not ws_dir.is_absolute():
    ws_dir = (repo / ws_dir).resolve()

PROMPT_TMPL = (
    "You are the Sibyl control plane. Begin the autonomous research loop for "
    "project \"__NAME__\" at \"__PATH__\" (current stage: __STAGE__).\n"
    "\n"
    "Bootstrap once, then loop:\n"
    "1. Register Sentinel ownership (so the watchdog can auto-resume this pane):\n"
    "   CURRENT_PANE=$(tmux display-message -p '#{pane_id}')\n"
    "   .venv/bin/python3 -c \"from sibyl.orchestrate import cli_sentinel_session; "
    "cli_sentinel_session('__PATH__', '${CLAUDE_CODE_SESSION_ID:-}', '$CURRENT_PANE')\"\n"
    "2. Resume any prior state:\n"
    "   .venv/bin/python3 -c \"from sibyl.orchestrate import cli_resume; cli_resume('__PATH__')\"\n"
    "3. Render the loop definition and follow it exactly:\n"
    "   .venv/bin/python3 -c \"from sibyl.orchestrate import render_control_plane_prompt; "
    "print(render_control_plane_prompt('loop', workspace_path='__PATH__'))\"\n"
    "\n"
    "Then execute the loop until it emits SIBYL_PIPELINE_COMPLETE. Never pause. "
    "On any error, diagnose it, retry, and continue."
)

rows = []
for d in sorted(ws_dir.iterdir()):
    if not d.is_dir() or d.name in ignore:
        continue
    if filter_name and d.name != filter_name:
        continue
    status_path = d / "status.json"
    if not status_path.exists():
        continue
    try:
        status = json.loads(status_path.read_text(encoding="utf-8"))
    except Exception:
        continue
    stage = str(status.get("stage", "") or "")
    if stage == "done" or status.get("stop_requested"):
        continue
    topic = (d / "topic.txt").read_text(encoding="utf-8").strip() if (d / "topic.txt").exists() else ""

    prompt = (PROMPT_TMPL
              .replace("__NAME__", d.name)
              .replace("__PATH__", str(d))
              .replace("__STAGE__", stage))
    prompt_file = Path(f"/tmp/sibyl-prompt-{d.name}.txt")
    prompt_file.write_text(prompt, encoding="utf-8")
    rows.append((d.name, str(d), stage, str(prompt_file)))

# one project per line: name<TAB>path<TAB>stage<TAB>prompt_file
for r in rows:
    print("\t".join(r))
PY
)"

if [ -z "$PROJECTS" ]; then
    echo "No active projects found under the configured workspaces_dir."
    exit 0
fi

echo ""
echo "  🧠  MODEL: $(sibyl_model_label "$SIBYL_CLI_MODEL")  [$SIBYL_CLI_MODEL]"
echo "  ℹ️   tmux session: $SESSION_NAME"
echo ""

if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] would launch these projects:"
    while IFS=$'\t' read -r name path stage prompt_file; do
        [ -n "$name" ] || continue
        echo "  • $name (stage: $stage)"
        echo "      prompt: $prompt_file"
        echo "      cmd: cd $REPO_ROOT && $CLAUDE_BIN --plugin-dir $REPO_ROOT/plugin --model $SIBYL_CLI_MODEL --settings $SIBYL_SETTINGS \"\$(cat $prompt_file)\""
        echo "      sentinel: bash $REPO_ROOT/sibyl/sentinel.sh $path <pane> 120"
    done <<< "$PROJECTS"
    exit 0
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "  ⚠️  tmux session '$SESSION_NAME' already exists — not starting duplicates."
    echo "      attach:  tmux attach -t $SESSION_NAME"
    echo "      restart: tmux kill-session -t $SESSION_NAME && bash $0 --model $MODEL"
    exit 1
fi

# ── Spawn one window per project (main pane + sentinel pane) ──
win=0
while IFS=$'\t' read -r name path stage prompt_file; do
    [ -n "$name" ] || continue

    if [ "$win" -eq 0 ]; then
        tmux new-session -d -s "$SESSION_NAME" -n "$name"
    else
        tmux new-window -t "$SESSION_NAME" -n "$name"
    fi

    # Type the launch command into the pane's interactive shell. claude stays a
    # DIRECT child of the pane shell (no `exec`), which is what sentinel.sh's
    # claude_is_running() expects (pgrep -P <pane_pid> -f claude).
    CMD="cd $REPO_ROOT && $CLAUDE_BIN --plugin-dir $REPO_ROOT/plugin --model $SIBYL_CLI_MODEL --settings $SIBYL_SETTINGS \"\$(cat $prompt_file)\""
    tmux send-keys -t "$SESSION_NAME:$win" "$CMD" Enter

    # Sentinel watchdog in the right-hand sibling pane, watching the main pane.
    tmux split-window -t "$SESSION_NAME:$win.0" -h -l 60 \
        "bash $REPO_ROOT/sibyl/sentinel.sh $path $SESSION_NAME:$win.0 120"

    echo "  ✅ $name  (window $win, stage: $stage)  + sentinel"
    win=$((win + 1))
done <<< "$PROJECTS"

echo ""
echo "  🚀  All projects launched in tmux session '$SESSION_NAME'."

# When launched from a double-clicked .command (outside tmux), drop straight
# into the session so the panes are visible immediately. Inside an existing
# tmux session we must not nest, so just print the attach hint instead.
if [ -z "${TMUX:-}" ]; then
    exec tmux attach -t "$SESSION_NAME"
else
    echo "      attach:  tmux attach -t $SESSION_NAME"
    echo "      detach:  Ctrl-b d"
fi
