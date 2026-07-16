"""Download a Hugging Face model snapshot to a configurable local directory."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from huggingface_hub import snapshot_download


def parse_args() -> argparse.Namespace:
    default_destination = (
        Path(__file__).resolve().parent / "ComfyUI" / "models" / "LLM" / "Qwen-VL"
    )
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-id",
        default=os.getenv("CUSTOM_WAN_QWEN_REPOSITORY", "Qwen/Qwen3-VL-2B-Instruct"),
    )
    parser.add_argument("--destination", type=Path, default=default_destination)
    parser.add_argument(
        "--revision",
        default=os.getenv("CUSTOM_WAN_QWEN_REVISION"),
        help="Optional branch, tag, or immutable commit to download",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    destination = args.destination.expanduser().resolve()
    snapshot_download(
        repo_id=args.repo_id,
        local_dir=destination,
        revision=args.revision,
    )
    print(f"Download complete: {destination}")


if __name__ == "__main__":
    main()
