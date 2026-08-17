"""Shared agent/model selection helpers for orchestration."""

from __future__ import annotations

import re
from pathlib import Path

from .common_utils import pack_skill_args


def active_agent_models(agents_dir: Path | None = None) -> dict[str, str]:
    """Read the live per-tier model from the agent frontmatter files.

    The forked skills run on the model pinned in ``.claude/agents/sibyl-{tier}.md``
    (a symlink swapped per provider by ``sibyl_apply_model``). Reading the same
    file means ``action["model"]`` reports what will actually execute, instead of
    a hardcoded default that can disagree with the active provider. Falls back to
    ``config.model_tiers`` only when the files are unreadable.
    """
    if agents_dir is None:
        from sibyl._paths import CLAUDE_RUNTIME_DIR

        agents_dir = CLAUDE_RUNTIME_DIR / "agents"

    models: dict[str, str] = {}
    for tier in ("heavy", "standard", "light"):
        f = agents_dir / f"sibyl-{tier}.md"
        try:
            text = f.read_text(encoding="utf-8")
        except OSError:
            continue
        m = re.search(r"^model:\s*(\S+)", text, re.MULTILINE)
        if m:
            models[tier] = m.group(1).strip()
    return models


def resolve_model_tier(config: object, agent_name: str) -> tuple[str, str]:
    """Return the configured model tier and model id for an agent name."""
    tier_key = agent_name
    # Strip "sibyl-" prefix from skill-style agent names for map lookup
    if tier_key.startswith("sibyl-"):
        tier_key = tier_key[6:]
    # Normalize dashes to underscores for consistent map lookup
    tier_key = tier_key.replace("-", "_")
    # Handle dynamic/special agent name patterns
    if agent_name.startswith("writer_"):
        tier_key = "section_writer"
    elif agent_name.startswith("critic_") and agent_name != "critic":
        tier_key = "section_critic"
    elif "_critiques_" in agent_name:
        tier_key = "idea_critique"

    tier = config.agent_tier_map.get(tier_key, "standard")
    # Frontmatter is authoritative (it is what the forked skill actually runs);
    # config.model_tiers is only a fallback when the files are unreadable.
    model = active_agent_models().get(tier) or config.model_tiers.get(
        tier, config.model_tiers["standard"]
    )
    return tier, model


def codex_reviewer_args(config: object, mode: str, ws: str) -> str:
    """Build reviewer args with an optional model override."""
    if config.codex_model:
        return pack_skill_args(ws, mode, config.codex_model)
    return pack_skill_args(ws, mode)


def codex_writer_args(config: object, ws: str) -> str:
    """Build Codex writer args with an optional model override."""
    model = config.codex_writing_model or config.codex_model
    if model:
        return pack_skill_args(ws, model)
    return pack_skill_args(ws)
