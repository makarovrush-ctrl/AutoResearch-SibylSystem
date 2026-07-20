"""Local-document → Markdown conversion via markitdown.

Converts PDFs, Office documents, ebooks, etc. into plain Markdown text so
agents read compact text instead of paying multimodal-rendering token costs
via the native `Read` tool. Used by the PreToolUse(Read) hook
(plugin/hooks/scripts/on-pre-read-doc.sh) and by any skill that needs to
ingest an external document into context.

Image formats are intentionally NOT handled here — screenshots/UI captures
must stay readable natively via `Read` for visual inspection.
"""

from __future__ import annotations

import sys
from pathlib import Path

from markitdown import MarkItDown

CONVERTIBLE_SUFFIXES = {
    ".pdf",
    ".doc",
    ".docx",
    ".ppt",
    ".pptx",
    ".xls",
    ".xlsx",
    ".epub",
    ".msg",
    ".eml",
    ".odt",
}


def convert_to_markdown(source: str) -> str:
    """Convert a local file path or URL to Markdown text."""
    return MarkItDown().convert(source).text_content


def convert_and_cache(source: str) -> Path:
    """Convert a local file to a `<source>.md` sidecar and return its path.

    Skips reconversion if the sidecar is already newer than the source.
    """
    src = Path(source)
    md_path = src.with_name(src.name + ".md")
    if md_path.exists() and md_path.stat().st_mtime >= src.stat().st_mtime:
        return md_path
    text = convert_to_markdown(str(src))
    md_path.write_text(text, encoding="utf-8")
    return md_path


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: python -m sibyl.doc_converter <path-or-url>", file=sys.stderr)
        sys.exit(2)
    target = sys.argv[1]
    if target.startswith("http://") or target.startswith("https://"):
        print(convert_to_markdown(target))
    else:
        print(convert_and_cache(target))


if __name__ == "__main__":
    main()
