"""Shared command-line argument validators for the Wan launchers."""

from __future__ import annotations

import argparse

MIN_PORT = 1
MAX_PORT = 65_535


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
