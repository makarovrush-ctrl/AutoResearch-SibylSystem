# Model routing

One rule: **the model is chosen explicitly at launch, never inherited.**

## Where the model comes from

| Entry point | Model |
|---|---|
| `Start New Sibyl Project (Opus 5).command` | `opus[1m]` → Opus 5, 1M context (Anthropic) |
| `Start New Sibyl Project (DeepSeek v4 pro).command` | `deepseek-v4-pro` (DeepSeek) |
| `Sibyl Research System.command` (no arg) | Anthropic; `--deepseek` for cost mode |
| any resume shortcut | same **provider** as the transcript; model upgraded to your default |
| plain `claude` | `model` field in `~/.claude/settings.json` (Anthropic) |

Provider credentials live in `~/.claude/settings.{anthropic,deepseek}.json`
(chmod 600, outside git). Each launcher passes `--settings` **and** `--model`.

## Model strings: alias vs API id

`opus[1m]` is a **Claude Code alias** for "Opus 5, 1M context" — it is what
`/model` persists, and it is what `--model` expects. It is **not** a valid raw
API model id (`POST /v1/messages` with it returns 404). The real id is
`claude-opus-5`. `sibyl_model_api_id` translates alias → id for direct API
probes; never send an alias to the API.

## Resuming: provider is sacred, model is not

Resuming preserves the **provider** absolutely — a DeepSeek chat never reopens
on Anthropic and, more importantly, an Anthropic chat never reopens on DeepSeek.
Within Anthropic, an older model is upgraded to your configured default (an Opus
4.8 chat reopens on Opus 5) and the banner says so. To pin the original exactly:

```bash
SIBYL_KEEP_EXACT_MODEL=1 <shortcut>
```

## Two rules that must not be broken

1. **Never export `ANTHROPIC_BASE_URL` / `ANTHROPIC_MODEL` / `ANTHROPIC_AUTH_TOKEN`
   from a shell profile.** A global export silently hijacks every session,
   including resumed Opus ones. This caused Opus conversations to reopen on
   DeepSeek for ~2 weeks (sessions `41022c00`, `fc2c8aaf`).
2. **Never put `ANTHROPIC_MODEL` in a settings `env` block.** It is sticky and
   outlives the `--model` flag. Use the `model` field instead.

## Endpoints

- Anthropic: `https://api.anthropic.com`
- DeepSeek: `https://api.deepseek.com/anthropic`  ← the Anthropic-compatible path

`https://deepseek.com` is the marketing site behind CloudFront; it returns
`403 ... only cachable requests` on POST and surfaces in Claude Code as a
misleading `Please run /login`.

## Health check

```bash
bash scripts/sibyl-model-doctor.sh          # config audit
bash scripts/sibyl-model-doctor.sh --live   # + one tiny API call per provider
```

Verify a resume without launching it:

```bash
SIBYL_DRY_RUN=1 bash scripts/sibyl-resume.sh <session-uuid>
```
