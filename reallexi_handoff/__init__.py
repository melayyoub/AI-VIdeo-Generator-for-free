"""
reallexi_handoff — frame-quality gating for chained image-to-video pipelines.

When shot N+1 is seeded with a frame from shot N, one bad frame poisons every
shot downstream. These nodes score a window of candidate frames, reject the
ones that fail, and pin the palette to a known-good reference.

Repo layout:
    scoring.py   pure numpy metrics, unit-tested, no ComfyUI dependency
    nodes.py     ComfyUI node classes
    install.py   sync this folder into <ComfyUI>/custom_nodes
    tests/       run with `python -m reallexi_handoff.tests.test_scoring`
"""

from __future__ import annotations

from .nodes import (NODE_CLASS_MAPPINGS, NODE_DISPLAY_NAME_MAPPINGS,
                    HandoffColorMatch, HandoffFrameSelect, HandoffQualityGate)

__version__ = "1.0.0"

__all__ = [
    "NODE_CLASS_MAPPINGS",
    "NODE_DISPLAY_NAME_MAPPINGS",
    "HandoffFrameSelect",
    "HandoffQualityGate",
    "HandoffColorMatch",
    "__version__",
]
