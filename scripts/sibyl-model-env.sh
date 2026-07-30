#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# Single source of truth for model routing. Source this, then call
# sibyl_apply_model <anthropic|deepseek>.
#
# It exports the FULL provider env explicitly, so nothing inherited from a
# shell profile, a parent Terminal, or a stale settings file can override
# the model you asked for. It also sets:
#   SIBYL_CLI_MODEL  → value for `claude --model`
#   SIBYL_SETTINGS   → value for `claude --settings`
#   SIBYL_MODEL_KIND → anthropic | deepseek
# ═══════════════════════════════════════════════════════════════════════

sibyl_apply_model() {
    local kind="${1:-anthropic}" settings

    case "$kind" in
        deepseek)  settings="$HOME/.claude/settings.deepseek.json" ;;
        anthropic) settings="$HOME/.claude/settings.anthropic.json" ;;
        *)
            echo "  ⚠️  Unknown model '$kind' — refusing to guess. Using anthropic." >&2
            kind="anthropic"; settings="$HOME/.claude/settings.anthropic.json" ;;
    esac

    if [ ! -f "$settings" ]; then
        echo "  ❌ Missing settings file: $settings" >&2
        return 1
    fi

    # Wipe any inherited routing before applying our own.
    unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL

    # Export exactly what the settings file declares.
    local exports
    exports=$(python3 - "$settings" <<'PY'
import json, shlex, sys
env = json.load(open(sys.argv[1])).get("env", {})
for k, v in env.items():
    print(f"export {k}={shlex.quote(str(v))}")
PY
    ) || { echo "  ❌ Could not parse $settings" >&2; return 1; }
    eval "$exports"

    export SIBYL_MODEL_KIND="$kind"
    export SIBYL_SETTINGS="$settings"
    # Model comes from the settings file's "model" field — never from a
    # sticky ANTHROPIC_MODEL env var, which is what used to hijack sessions.
    SIBYL_CLI_MODEL=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['model'])" "$settings")
    export SIBYL_CLI_MODEL

    # Keep subagent definitions in step with the provider.
    # (Skipped for read-only operations like --cost, which must not mutate state.)
    [ -n "${SIBYL_NO_AGENT_SWAP:-}" ] && return 0
    local repo_root agents_link
    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    agents_link="$repo_root/.claude/agents"
    if [ -d "$repo_root/.claude/agents-$kind" ] \
       && [ "$(readlink "$agents_link" 2>/dev/null)" != "agents-$kind" ]; then
        rm -rf "$agents_link"
        ln -s "agents-$kind" "$agents_link"
    fi
}

sibyl_model_banner() {
    if [ "$SIBYL_MODEL_KIND" = "anthropic" ]; then
        echo "  🧠  MODEL: $SIBYL_CLI_MODEL  (Anthropic — quality mode)"
    else
        echo "  💰  MODEL: $SIBYL_CLI_MODEL  (DeepSeek — cost-saving mode)"
    fi
    echo "      endpoint: $ANTHROPIC_BASE_URL"
}

# Pin an exact model string (e.g. resuming a claude-opus-5 session on
# claude-opus-5, not just "whatever the provider default is").
sibyl_pin_exact_model() {
    local exact="${1:-}"
    [ -n "$exact" ] || return 0
    export ANTHROPIC_MODEL="$exact"
    export SIBYL_CLI_MODEL="$exact"
}
