# ──────────────────────────────────────────────────────────────────────────
# Sibyl Cost Meter — Shell Integration
#
# Source this file in your ~/.zshrc or ~/.bashrc to get:
#   sibyl-cost          → launch cost HUD in a tmux split for current project
#   sibyl-cost-all      → launch cost HUD for all projects
#   sibyl-cost-report   → print one-shot cost report
#
# Requirements: tmux (optional, for split-pane mode), Sibyl repo venv
# ──────────────────────────────────────────────────────────────────────────

# Set this to your Sibyl repo path, or it will auto-detect
: ${SIBYL_REPO:=""}

_sibyl_find_repo() {
    if [ -n "$SIBYL_REPO" ]; then
        echo "$SIBYL_REPO"
        return
    fi
    # Try to find it relative to where this script is sourced
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
    if [ -d "$script_dir/../.claude" ] && [ -f "$script_dir/../sibyl/cli.py" ]; then
        echo "$(cd "$script_dir/.." && pwd)"
        return
    fi
    # Fallback
    echo "${HOME}/sibyl-research-system"
}

_sibyl_venv_python() {
    local repo
    repo="$(_sibyl_find_repo)"
    echo "$repo/.venv/bin/python3"
}

_sibyl_find_project() {
    # Look for a project name from the current directory path
    local dir
    dir="$(pwd)"
    # Check if we're inside a workspace directory
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/status.json" ] && [ -d "$dir/logs" ]; then
            basename "$dir"
            return
        fi
        # Also check parent for workspaces/ dir pattern
        if [ "$(basename "$(dirname "$dir")")" = "workspaces" ]; then
            basename "$dir"
            return
        fi
        dir="$(dirname "$dir")"
    done
    echo ""
}

# ── One-shot cost report ────────────────────────────────────────────────

sibyl-cost-report() {
    local python project
    python="$(_sibyl_venv_python)"
    if [ $# -gt 0 ]; then
        "$python" -m sibyl.cli cost --scan "$@"
    else
        "$python" -m sibyl.cli cost --all --scan
    fi
}

# ── Live cost HUD (current terminal) ────────────────────────────────────

sibyl-cost() {
    local python project
    python="$(_sibyl_venv_python)"
    if [ $# -gt 0 ]; then
        "$python" -m sibyl.cli cost --watch --scan "$@"
    else
        # Auto-detect project
        project="$(_sibyl_find_project)"
        if [ -n "$project" ]; then
            "$python" -m sibyl.cli cost --watch --scan "$project"
        else
            echo "No project detected. Specify a project name or use sibyl-cost-all."
            echo "Usage: sibyl-cost <project-name>"
        fi
    fi
}

# ── Live cost HUD for all projects ──────────────────────────────────────

sibyl-cost-all() {
    local python
    python="$(_sibyl_venv_python)"
    "$python" -m sibyl.cli cost --watch --all
}

# ── Launch cost HUD in a tmux split pane ────────────────────────────────

sibyl-cost-tmux() {
    local python project repo
    python="$(_sibyl_venv_python)"
    repo="$(_sibyl_find_repo)"

    if [ -z "${TMUX:-}" ]; then
        echo "Not in tmux. Launching as foreground process..."
        sibyl-cost "$@"
        return
    fi

    project="${1:-$(_sibyl_find_project)}"
    local cmd
    if [ -n "$project" ]; then
        cmd="cd $repo && $python -m sibyl.cli cost --watch --scan $project"
    else
        cmd="cd $repo && $python -m sibyl.cli cost --watch --all"
    fi

    # Split right, 40 cols wide
    tmux split-window -h -l 50 "$cmd" 2>/dev/null || \
    tmux split-window -v -l 15 "$cmd" 2>/dev/null || \
    echo "Could not create tmux pane. Run sibyl-cost directly."
}

# ── Print help ──────────────────────────────────────────────────────────

sibyl-cost-help() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║              Sibyl Cost Meter — Shell Commands               ║
╠══════════════════════════════════════════════════════════════╣
║  sibyl-cost-report [project]   One-shot cost report          ║
║  sibyl-cost [project]          Live cost HUD (this terminal) ║
║  sibyl-cost-all                Live HUD for all projects     ║
║  sibyl-cost-tmux [project]     Launch HUD in tmux split      ║
║  sibyl-cost-help               Show this help                ║
╠══════════════════════════════════════════════════════════════╣
║  CLI (direct):                                              ║
║    sibyl cost <project>          One-shot report             ║
║    sibyl cost --watch <project>  Live HUD                    ║
║    sibyl cost --watch --all      Live HUD (all projects)     ║
║    sibyl cost --reset <project>  Reset cost data             ║
║    sibyl cost --json <project>   JSON output                 ║
╚══════════════════════════════════════════════════════════════╝
EOF
}
