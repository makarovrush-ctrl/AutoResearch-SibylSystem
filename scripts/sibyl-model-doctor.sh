#!/usr/bin/env bash
# Model routing health check. Run any time you suspect a model swap:
#   bash ~/sibyl-research-system/scripts/sibyl-model-doctor.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/sibyl-model-env.sh
source "$REPO_ROOT/scripts/sibyl-model-env.sh"
SHORTCUTS="$HOME/Desktop/Sibyl Projects"
fail=0

echo "── 1. Shell profiles must not export model/provider vars ──"
hits=$(grep -ln "^export ANTHROPIC" "$HOME"/.zshrc "$HOME"/.zprofile "$HOME"/.zshenv \
        "$HOME"/.bash_profile "$HOME"/.bashrc "$HOME"/.profile 2>/dev/null)
if [ -n "$hits" ]; then echo "  ❌ leaking: $hits"; fail=1; else echo "  ✅ clean"; fi

echo "── 2. Settings files ──"
for f in settings.json settings.anthropic.json settings.deepseek.json; do
    python3 - "$HOME/.claude/$f" <<'PY'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception as e:
    print(f"  ❌ {p}: {e}"); raise SystemExit
env = d.get("env", {})
bad = "ANTHROPIC_MODEL" in env
print(f"  {'❌' if bad else '✅'} {p.split('/')[-1]:26} model={d.get('model','?'):18} "
      f"url={env.get('ANTHROPIC_BASE_URL','?')}"
      f"{'   <- sticky ANTHROPIC_MODEL in env!' if bad else ''}")
PY
done

echo "── 3. Every .command shortcut pins its model ──"
unpinned=0
while IFS= read -r -d '' f; do
    if grep -q "claude" "$f" \
       && ! grep -q "sibyl-resume.sh\|resume-session.sh\|sibyl-launch.sh\|SIBYL_CLI_MODEL" "$f"; then
        echo "  ❌ unpinned: $f"; unpinned=1; fail=1
    fi
done < <(find "$SHORTCUTS" -name "*.command" -print0 2>/dev/null)
[ $unpinned -eq 0 ] && echo "  ✅ all $(find "$SHORTCUTS" -name '*.command' 2>/dev/null | wc -l | tr -d ' ') shortcuts pinned"

echo "── 4. Sessions that drifted between providers mid-conversation ──"
python3 - <<'PY'
import json, glob, os
d = os.path.expanduser("~/.claude/projects/-Users-mackenzieboi-sibyl-research-system")
bad = []
for f in glob.glob(d + "/*.jsonl"):
    seen = []
    for line in open(f, errors="replace"):
        i = line.find('"model":"')
        if i < 0: continue
        m = line[i+9:line.find('"', i+9)]
        if m and m != "<synthetic>" and (not seen or seen[-1] != m):
            seen.append(m)
    fams = {("deepseek" if s.startswith("deepseek") else "claude") for s in seen}
    if len(fams) > 1:
        bad.append((os.path.basename(f)[:8], " → ".join(seen)))
print("  ✅ none" if not bad else "  ⚠️  historical drift (pre-fix):")
for sid, chain in bad: print(f"     {sid}  {chain}")
PY
echo "── 5. Core operating config must be committed, not just sitting in the tree ──"
# CLAUDE.md carried the identity / SOP / mission blocks unstaged from 2026-07-20
# to 2026-07-30. Uncommitted config does not survive a reset, clone or self-heal.
CORE_FILES="CLAUDE.md sibyl/prompts/_common_zh.md \
scripts/sibyl-model-env.sh scripts/sibyl-launch.sh scripts/sibyl-resume.sh \
scripts/sibyl-model-doctor.sh .claude/hooks/on-conversation-start.sh"
dirty_core=""
# Untracked is worse than dirty: it vanishes on clone/reset without warning.
for cf in $CORE_FILES; do
    if [ -f "$REPO_ROOT/$cf" ] \
       && ! git -C "$REPO_ROOT" ls-files --error-unmatch "$cf" >/dev/null 2>&1; then
        dirty_core="$dirty_core $cf(UNTRACKED)"
    fi
done
for cf in $CORE_FILES; do
    if [ -f "$REPO_ROOT/$cf" ] \
       && ! git -C "$REPO_ROOT" diff --quiet -- "$cf" 2>/dev/null; then
        dirty_core="$dirty_core $cf"
    fi
    if [ -f "$REPO_ROOT/$cf" ] \
       && ! git -C "$REPO_ROOT" diff --cached --quiet -- "$cf" 2>/dev/null; then
        dirty_core="$dirty_core $cf(staged)"
    fi
done
if [ -n "$dirty_core" ]; then
    echo "  ⚠️  uncommitted:$dirty_core"
    echo "      → commit these; they define how every session behaves"
else
    echo "  ✅ core config committed"
fi

# The canonical shortcut pattern lives on the Desktop, outside git. Keep a
# tracked mirror in the repo so it cannot be lost or silently contradicted.
PATTERN_SRC="$SHORTCUTS/System/shortcut-pattern.txt"
PATTERN_MIRROR="$REPO_ROOT/docs/shortcut-pattern.txt"
if [ -f "$PATTERN_SRC" ]; then
    if [ ! -f "$PATTERN_MIRROR" ] || ! cmp -s "$PATTERN_SRC" "$PATTERN_MIRROR"; then
        echo "  ⚠️  docs/shortcut-pattern.txt is out of sync with System/shortcut-pattern.txt"
        echo "      → cp \"$PATTERN_SRC\" \"$PATTERN_MIRROR\" && git add docs/shortcut-pattern.txt"
    else
        echo "  ✅ shortcut pattern mirrored in repo"
    fi
fi

echo "── 6. Cost-regression guards ──"
# Defined once in scripts/sibyl-cost-guards.sh and re-checked on every launch,
# so the doctor and the launcher can never disagree about what "healthy" means.
source "$REPO_ROOT/scripts/sibyl-cost-guards.sh"
sibyl_cost_guards || fail=1

echo "── 7. Live endpoint check (add --live to run; makes 1 tiny API call each) ──"
if [ "${1:-}" = "--live" ]; then
    for f in settings.anthropic.json settings.deepseek.json; do
        read -r url key model <<<"$(python3 -c "
import json,sys
d=json.load(open('$HOME/.claude/$f')); e=d['env']
print(e['ANTHROPIC_BASE_URL'], e['ANTHROPIC_API_KEY'], d['model'])")"
        # CLI aliases (opus, opus[1m]) are not valid raw API model ids.
        api_model="$(sibyl_model_api_id "$model")"
        code=$(curl -s -o /tmp/sibyl_probe.$$ -w '%{http_code}' -m 30 -X POST "$url/v1/messages" \
            -H 'content-type: application/json' -H 'anthropic-version: 2023-06-01' \
            -H "x-api-key: $key" -H "authorization: Bearer $key" \
            -d "{\"model\":\"$api_model\",\"max_tokens\":4,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}")
        case "$code" in
            200)
                echo "  ✅ $f  $(sibyl_model_label "$model") [$api_model] @ $url" ;;
            000)
                # No HTTP response at all: DNS/TLS/network, not a config fault.
                echo "  ⚠️  $f  unreachable (no TLS response) @ $url"
                echo "      network issue, not config — retry later; config itself is unchanged" ;;
            *)
                echo "  ❌ $f  HTTP $code @ $url/v1/messages"
                [ -s /tmp/sibyl_probe.$$ ] && { head -c 200 /tmp/sibyl_probe.$$ | tr -d '\n'; echo; }
                fail=1 ;;
        esac
        rm -f /tmp/sibyl_probe.$$
    done
else
    echo "  (skipped)"
fi

echo
[ $fail -eq 0 ] && echo "RESULT: ✅ model routing is locked down" || echo "RESULT: ❌ issues above"
