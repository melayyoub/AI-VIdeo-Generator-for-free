#!/usr/bin/env python3
"""Remove non-portable export metadata from ComfyUI workflow JSON files."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WORKFLOW_DIRECTORY = REPOSITORY_ROOT / "examples"

JSON_STRING = r'"(?:\\.|[^"\\])*"'
FULLPATH_FIELD = re.compile(rf'("fullpath"\s*:\s*){JSON_STRING}')
OWNER_FIELD = re.compile(rf'("owner"\s*:\s*){JSON_STRING}')
WORKSPACE_INFO = re.compile(
    rf'("workspace_info"\s*:\s*)\{{(?:[^{{}}"]|{JSON_STRING})*\}}'
)
TRANSIENT_HOST = "liblibai-tmp-image." + "liblib.cloud"
TRANSIENT_URL = re.compile(
    rf'https://{re.escape(TRANSIENT_HOST)}(?:\\.|[^"\\\s])*',
    re.IGNORECASE,
)
SENSITIVE_URL = re.compile(
    r'https?://(?:\\.|[^"\\\s])*[?&]'
    r"(?:token|access_token|api_key|signature|x-amz-signature)="
    r'(?:\\.|[^"\\\s])*',
    re.IGNORECASE,
)


def sanitize(content: str) -> str:
    """Return workflow JSON text with local/export-only metadata removed."""

    sanitized = FULLPATH_FIELD.sub(r'\1""', content)
    sanitized = OWNER_FIELD.sub(r'\1""', sanitized)
    sanitized = WORKSPACE_INFO.sub(r"\1{}", sanitized)
    sanitized = TRANSIENT_URL.sub("", sanitized)
    sanitized = SENSITIVE_URL.sub("", sanitized)
    return sanitized


def workflow_paths(directory: Path) -> list[Path]:
    return sorted(path for path in directory.glob("*.json") if path.is_file())


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check or sanitize exported ComfyUI workflow metadata."
    )
    parser.add_argument(
        "--directory",
        type=Path,
        default=DEFAULT_WORKFLOW_DIRECTORY,
        help="Workflow directory (default: repository examples directory).",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Rewrite files in place; without this flag the command is check-only.",
    )
    args = parser.parse_args()

    directory = args.directory.expanduser().resolve()
    changed: list[Path] = []
    for path in workflow_paths(directory):
        content = path.read_text(encoding="utf-8-sig")
        sanitized = sanitize(content)
        if sanitized == content:
            continue
        changed.append(path)
        if args.write:
            path.write_text(sanitized, encoding="utf-8", newline="")

    if changed and not args.write:
        print("Workflow privacy metadata requires sanitization:")
        for path in changed:
            print(f"- {path.relative_to(REPOSITORY_ROOT)}")
        print("Run: python scripts/sanitize_workflows.py --write")
        return 1

    action = "Sanitized" if args.write else "Validated"
    print(
        f"{action} {len(workflow_paths(directory))} workflow files; changed {len(changed)}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
