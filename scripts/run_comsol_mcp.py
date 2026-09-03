#!/usr/bin/env python3
"""Launch COMSOL MCP with the Windows 6.2 install on PATH.

MPh discovers COMSOL via `where comsol` / `which comsol`, not via COMSOL_ROOT.
The 6.2 desktop shortcut points at Multiphysics_copy1, which registry scans miss,
so this launcher prepends that win64 folder to PATH before starting the server.

On first run it clones wjc9011/COMSOL_Multiphysics_MCP and pip-installs a
dedicated venv. Subsequent launches reuse that venv.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_URL = "https://github.com/wjc9011/COMSOL_Multiphysics_MCP.git"
WIN_ROOT_DEFAULT = r"C:\Program Files\COMSOL\COMSOL62\Multiphysics_copy1"


def _bundled_home() -> Path:
    return Path(__file__).resolve().parent.parent / "COMSOL_Multiphysics_MCP"


def _home() -> Path:
    env_home = os.environ.get("COMSOL_MCP_HOME")
    if env_home:
        return Path(env_home)
    bundled = _bundled_home()
    if (bundled / "src" / "server.py").is_file():
        return bundled
    if os.name == "nt":
        base = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
        return Path(base) / "mcp-servers" / "COMSOL_Multiphysics_MCP"
    return Path.home() / ".local" / "share" / "mcp-servers" / "COMSOL_Multiphysics_MCP"


def _venv_python(home: Path) -> Path:
    if os.name == "nt":
        return home / ".venv" / "Scripts" / "python.exe"
    return home / ".venv" / "bin" / "python"


def _looks_like_root(root: Path) -> bool:
    return any(
        (root / rel / name).is_file()
        for rel, name in (
            ("bin/win64", "comsol.exe"),
            ("bin/glnxa64", "comsol"),
            ("bin/macarm64", "comsol"),
            ("bin/maci64", "comsol"),
        )
    )


def _bin_dir(root: Path) -> Path | None:
    for rel, name in (
        ("bin/win64", "comsol.exe"),
        ("bin/glnxa64", "comsol"),
        ("bin/macarm64", "comsol"),
        ("bin/maci64", "comsol"),
    ):
        candidate = root / rel
        if (candidate / name).is_file():
            return candidate
    return None


def discover_root() -> Path:
    candidates = [
        os.environ.get("COMSOL_ROOT", ""),
        os.environ.get("COMSOLROOT", ""),
        WIN_ROOT_DEFAULT,
        r"C:\Program Files\COMSOL\COMSOL62\Multiphysics",
        "/usr/local/comsol62/multiphysics",
        "/usr/local/comsol/multiphysics",
        str(Path.home() / ".local" / "comsol62" / "multiphysics"),
    ]
    for raw in candidates:
        if not raw:
            continue
        root = Path(raw)
        if _looks_like_root(root):
            return root
    return Path(os.environ.get("COMSOL_ROOT") or WIN_ROOT_DEFAULT)


def export_comsol_path(root: Path) -> Path | None:
    bin_dir = _bin_dir(root)
    os.environ["COMSOL_ROOT"] = str(root)
    os.environ["COMSOLROOT"] = str(root)
    if bin_dir is None:
        return None
    path = os.environ.get("PATH", "")
    prefix = str(bin_dir)
    parts = path.split(os.pathsep) if path else []
    if prefix not in parts:
        os.environ["PATH"] = prefix + (os.pathsep + path if path else "")
    return bin_dir


def _run(cmd: list[str], **kwargs) -> None:
    subprocess.run(cmd, check=True, **kwargs)


def _server_importable(py: Path, home: Path) -> bool:
    if not py.is_file():
        return False
    probe = subprocess.run(
        [str(py), "-c", "import src.server"],
        cwd=home,
        capture_output=True,
        check=False,
    )
    return probe.returncode == 0


def ensure_install(home: Path) -> Path:
    home.mkdir(parents=True, exist_ok=True)
    has_src = (home / "src" / "server.py").is_file()
    if not has_src and not (home / ".git").is_dir():
        _run(["git", "clone", "--depth", "1", REPO_URL, str(home)])
    py = _venv_python(home)
    if _server_importable(py, home):
        return py
    if not py.is_file():
        _run([sys.executable, "-m", "venv", str(home / ".venv")])
        py = _venv_python(home)
    _run([str(py), "-m", "pip", "install", "-U", "pip", "setuptools", "wheel"])
    _run([str(py), "-m", "pip", "install", "-e", str(home)])
    return py


def main() -> int:
    os.environ.setdefault("PYTHONUNBUFFERED", "1")
    root = discover_root()
    bin_dir = export_comsol_path(root)
    if bin_dir is None:
        sys.stderr.write(
            "COMSOL Multiphysics 6.2 was not found at:\n"
            f"  {root}\n"
            "Expected executable:\n"
            r"  C:\Program Files\COMSOL\COMSOL62\Multiphysics_copy1\bin\win64\comsol.exe"
            "\n"
            "This MCP must run on the Windows PC that has that install "
            "(Cursor Desktop or a self-hosted Cursor worker there).\n"
        )
        if os.name != "nt":
            sys.stderr.write(
                f"Current OS is {sys.platform}; win64 comsol.exe cannot be started here.\n"
            )

    home = Path(os.environ.get("COMSOL_MCP_HOME") or _home())
    try:
        python = ensure_install(home)
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(f"Failed to install COMSOL MCP into {home}: {exc}\n")
        return exc.returncode or 1

    os.chdir(home)
    argv = [str(python), "-m", "src.server", *sys.argv[1:]]
    os.execv(str(python), argv)
    return 1


if __name__ == "__main__":
    bundled = Path(os.environ.get("COMSOL_MCP_HOME") or _home())
    if not (bundled / "src" / "server.py").is_file() and not shutil.which("git"):
        sys.stderr.write("git is required to install COMSOL_Multiphysics_MCP\n")
        raise SystemExit(1)
    raise SystemExit(main())
