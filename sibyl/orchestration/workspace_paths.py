"""Workspace path and marker helpers for orchestration code."""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


def _is_bare_workspace_name(p: Path) -> bool:
    """True for a single-component name with no path separator and no leading dot."""
    s = str(p)
    if p.is_absolute():
        return False
    if s in ("", ".", ".."):
        return False
    if "/" in s or "\\" in s:
        return False
    if s.startswith("."):
        return False
    return True


def _configured_workspaces_dir() -> Path:
    """Read ``workspaces_dir`` from the root ``config.yaml``.

    Falls back to the dataclass default, resolved against the repo root when
    relative, so a bare project name always lands in the configured directory
    rather than a shadow ``<cwd>/workspaces``.
    """
    from sibyl._paths import REPO_ROOT
    from sibyl.config import Config

    root_cfg = REPO_ROOT / "config.yaml"
    ws_dir: Path | None = None
    if root_cfg.exists():
        try:
            ws_dir = Config.from_yaml(str(root_cfg)).workspaces_dir
        except Exception:
            ws_dir = None
    if ws_dir is None:
        ws_dir = Config().workspaces_dir
    if not ws_dir.is_absolute():
        ws_dir = (REPO_ROOT / ws_dir).resolve()
    return ws_dir


def resolve_workspace_root(workspace_path: str | Path) -> Path:
    """Normalize a workspace name or path to the stable project root.

    A bare name (single component, no separator, no leading dot) is resolved
    against ``Config.workspaces_dir``. Anything with a path separator or an
    absolute path is treated as a literal path. This keeps ``/sibyl-research:continue
    centriflow`` operating on the real project instead of silently creating a
    shadow ``<cwd>/centriflow``.
    """
    workspace_root = Path(workspace_path)
    if _is_bare_workspace_name(workspace_root):
        workspace_root = _configured_workspaces_dir() / workspace_root.name
    if workspace_root.name == "current" and (workspace_root.parent / "status.json").exists():
        workspace_root = workspace_root.parent
    return workspace_root.resolve()


def workspace_scope_id(workspace_path: str | Path) -> str:
    """Return a stable workspace-scoped identifier for cross-process markers."""
    workspace_root = resolve_workspace_root(workspace_path)
    safe_name = re.sub(r"[^a-zA-Z0-9_.-]+", "-", workspace_root.name).strip("-") or "sibyl"
    digest = hashlib.sha1(str(workspace_root).encode("utf-8")).hexdigest()[:10]
    return f"{safe_name}_{digest}"


def project_marker_file(workspace_path: str | Path, suffix: str) -> str:
    """Build a per-workspace marker file path under /tmp."""
    safe_suffix = re.sub(r"[^a-zA-Z0-9_.-]+", "-", suffix).strip("-") or "marker"
    return f"/tmp/sibyl_{workspace_scope_id(workspace_path)}_{safe_suffix}.json"


def load_workspace_iteration_dirs(workspace_path: str | Path, default: bool = False) -> bool:
    """Read iteration_dirs from workspace status when available."""
    status_path = resolve_workspace_root(workspace_path) / "status.json"
    if not status_path.exists():
        return default
    try:
        status_data = json.loads(status_path.read_text(encoding="utf-8"))
        return bool(status_data.get("iteration_dirs", default))
    except (json.JSONDecodeError, OSError, TypeError):
        return default


def resolve_active_workspace_path(workspace_path: str | Path) -> Path:
    """Normalize a workspace path to the active iteration workspace."""
    workspace_root = resolve_workspace_root(workspace_path)
    if load_workspace_iteration_dirs(workspace_root):
        current_path = workspace_root / "current"
        if current_path.exists():
            return current_path
    return workspace_root
