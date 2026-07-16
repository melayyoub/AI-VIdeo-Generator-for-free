"""Shared command-line argument validators for the Wan launchers."""

from __future__ import annotations

import argparse
import re

MIN_PORT = 1
MAX_PORT = 65_535
MODEL_REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$")
MODEL_REVISION_PATTERN = re.compile(r"^[A-Za-z0-9._/-]+$")


def port_number(value: str) -> int:
    """Return a TCP/UDP port number accepted by command-line parsers."""
    try:
        port = int(value)
    except (TypeError, ValueError) as error:
        raise argparse.ArgumentTypeError(
            f"port must be an integer from {MIN_PORT} through {MAX_PORT}"
        ) from error

    if not MIN_PORT <= port <= MAX_PORT:
        raise argparse.ArgumentTypeError(
            f"port must be an integer from {MIN_PORT} through {MAX_PORT}"
        )
    return port


def model_repository(value: str) -> str:
    """Validate a Hugging Face repository identifier without URL/code syntax."""
    if len(value) > 200 or not MODEL_REPOSITORY_PATTERN.fullmatch(value):
        raise argparse.ArgumentTypeError(
            "model repository must use the owner/repository form"
        )
    return value


def model_revision(value: str) -> str:
    """Validate a branch, tag, or commit used in generated download code."""
    if (
        len(value) > 200
        or not MODEL_REVISION_PATTERN.fullmatch(value)
        or ".." in value
        or value.startswith("/")
        or value.endswith("/")
    ):
        raise argparse.ArgumentTypeError(
            "model revision must be a branch, tag, or commit without traversal"
        )
    return value
