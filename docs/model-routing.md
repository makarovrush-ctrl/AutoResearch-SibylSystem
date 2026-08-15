# Model routing

One rule: **the model is chosen explicitly at launch, never inherited.**

## Where the model comes from

| Entry point | Model |
|---|---|
| `Start New Sibyl Project (Opus 5).command` | `opus` → Opus 5, standard 200K context (Anthropic) |
| `Start New Sibyl Project (DeepSeek v4 pro).command` | `deepseek-v4-pro` (DeepSeek) |
| `Sibyl Research System.command` (no arg) | Anthropic; `--deepseek` for cost mode |
| any resume shortcut | same **provider and model** as the transcript |
| plain `claude` | `model` field in `~/.claude/settings.json` (Anthropic) |

Provider credentials live in `~/.claude/settings.{anthropic,deepseek}.json`
(chmod 600, outside git). Each launcher passes `--settings` **and** `--model`.

## Model strings: alias vs API id

`opus` / `opus[1m]` are **Claude Code aliases** — they are what `/model`
persists and what `--model` expects. They are **not** valid raw API model ids
(`POST /v1/messages` with one returns 404). The real id is `claude-opus-5`.
`sibyl_model_api_id` translates alias → id for direct API probes; never send an
alias to the API.

## Why not `opus[1m]`

The 1M-context alias is deliberately **not** the default. Anthropic bills any
request whose context exceeds 200K at a premium: **2x** on input/cache and
**1.5x** on output. Transcript audit found 782 such calls carrying **$1,268** of
pure surcharge — with no quality benefit, since a 400K-token context degrades
retrieval rather than improving it. Use `opus[1m]` only for a deliberate
whole-codebase pass, never as a standing default.

## Resuming: provider and model are both preserved

Resuming preserves the **provider** absolutely — a DeepSeek chat never reopens
on Anthropic and, more importantly, an Anthropic chat never reopens on DeepSeek.
The **model is preserved too**: a Sonnet thread reopens on Sonnet.

The old rule "upgraded" every resumed chat to the configured default, which
meant each resume silently re-entered the most expensive model available. That
escalator is removed. To opt in to upgrading:

```bash
SIBYL_UPGRADE_MODEL=1 <shortcut>
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
