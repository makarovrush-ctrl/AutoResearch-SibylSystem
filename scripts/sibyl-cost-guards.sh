#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════
# Cost-regression guards — single source of truth.
#
# These assert the four regressions that silently produced ~$3.2k of spend
# (see commit f0394a0 and 2de93b5). Each was invisible in normal use, so they
# are re-checked on EVERY launch, not just when someone remembers to run the
# doctor.
#
#   sibyl_cost_guards          → verbose, one line per check
#   sibyl_cost_guards quiet    → silent when healthy, loud when not
#
# Returns 0 if all guards pass, 1 otherwise.
# ══════════════════════════════════════════════════════════════════════════

sibyl_cost_guards() {
    local mode="${1:-verbose}" root problems=()
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local shortcuts="$HOME/Desktop/Sibyl Projects"

    # 1. No 1M-context alias: >200K context bills 2x input / 1.5x output.
    local f mdl
    for f in settings.json settings.anthropic.json; do
        mdl=$(python3 -c "import json;print(json.load(open('$HOME/.claude/$f')).get('model',''))" 2>/dev/null)
        case "$mdl" in
            *"[1m]"*) problems+=("$f pins $mdl → long-context premium billing (2x in / 1.5x out)") ;;
        esac
    done

    # 2. Launchers must load the plugin, else autoresearch cannot run at all.
    local s
    for s in sibyl-launch.sh sibyl-resume.sh; do
        grep -q -- "--plugin-dir" "$root/scripts/$s" 2>/dev/null \
            || problems+=("scripts/$s missing --plugin-dir → no commands, no hooks, no loop")
    done

    # 3. --bare kills hooks, auto-memory and CLAUDE.md discovery. Only flag it
    #    when actually passed to claude (the parser legitimately ignores one).
    local bare
    bare=$(python3 - "$root/scripts/sibyl-launch.sh" "$root/scripts/sibyl-resume.sh" 2>/dev/null <<'PY'
import re, sys
bad = []
for p in sys.argv[1:]:
    try: src = open(p).read()
    except OSError: continue
    src = re.sub(r"\\\n", " ", src)
    for line in src.splitlines():
        if "bin/claude" in line.split("#", 1)[0] and "--bare" in line.split("#", 1)[0]:
            bad.append(p.split("/")[-1])
print(" ".join(sorted(set(bad))))
PY
)
    [ -n "$bare" ] && problems+=("--bare reaches claude in $bare → hooks/memory/CLAUDE.md disabled")

    # 4. Tier routing: only 'heavy' may be Opus. standard+light are ~33 of 44 skills.
    local t m
    for t in standard light; do
        m=$(grep -h '^model:' "$root/.claude/agents-anthropic/sibyl-$t.md" 2>/dev/null | awk '{print $2}')
        case "$m" in
            *opus*) problems+=("sibyl-$t pinned to $m → Opus on a high-volume tier") ;;
            "")     problems+=("sibyl-$t has no model pinned") ;;
        esac
    done

    # 5. supervisor_enabled must stay False (standing Opus subagent per experiment).
    grep -q "supervisor_enabled: bool = True" "$root/sibyl/config.py" 2>/dev/null \
        && problems+=("supervisor_enabled defaults True → standing Opus subagent per experiment")

    # 6. Any shortcut calling claude directly must pass --plugin-dir itself.
    local sc
    while IFS= read -r -d '' sc; do
        grep -q "bin/claude" "$sc" || continue
        grep -q "sibyl-launch.sh\|sibyl-resume.sh\|resume-session.sh" "$sc" && continue
        grep -q -- "--plugin-dir" "$sc" || problems+=("shortcut without --plugin-dir: ${sc#$HOME/}")
    done < <(find "$shortcuts" \( -name "*.command" -o -name "*.sh" \) -print0 2>/dev/null)

    if [ ${#problems[@]} -eq 0 ]; then
        [ "$mode" = quiet ] || echo "  ✅ cost guards: all clear"
        return 0
    fi
    echo ""
    echo "  ⚠️  COST GUARD FAILURE — a fixed regression has come back:"
    local p
    for p in "${problems[@]}"; do echo "     ❌ $p"; done
    echo "     → run: bash $root/scripts/sibyl-model-doctor.sh"
    echo ""
    return 1
}
