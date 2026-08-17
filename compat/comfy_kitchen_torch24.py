"""Compatibility shim: comfy-kitchen on the DirectML (torch 2.4.1) stack.

torch-directml 0.2.5 pins torch 2.4.1, but comfy-kitchen 0.2.28 and newer
declare their custom ops with PEP 585 annotations (``list[int]``) that torch's
schema inference only accepts from 2.5 on, so those builds raise on import
here. The DirectML environment therefore holds comfy-kitchen at 0.2.27 -- the
newest build that imports on torch 2.4.1 -- and this module supplies the
symbols ComfyUI expects from the newer builds.

Six of them are accelerated paths ComfyUI reaches only after an
``*_is_available()`` check, so reporting them unavailable is enough; they raise
if something calls them anyway. The seventh, ``na3d``, is called
unconditionally by the LTX 2.x neighborhood-attention VAE decoder, so it is
provided as the pure-torch eager implementation from comfy-kitchen 0.2.31
(Apache-2.0, Copyright (c) 2025 Comfy Org) with the custom-op registration --
the part torch 2.4.1 rejects -- dropped.

wan2_cli.ensure_directml_kitchen_compat copies this file into the DirectML
environment's site-packages and writes a .pth beside it so the import hook is
installed before ComfyUI runs.
"""

from __future__ import annotations

import math
import sys
from typing import TYPE_CHECKING

# torch is imported inside the functions that need it, not here: the .pth that
# loads this module runs on every interpreter start in the environment, and a
# top-level torch import would add seconds to each one.
if TYPE_CHECKING:
    import torch

MODULE_NAME = "comfy_kitchen"

# Element budget for one tile's [Nq, Nk] attention mask (bounds the mask
# allocation and, on CPU, the math-backend score materialization).
NA_SCORE_BUDGET = 2 ** 25
# Element budget for the stacked K/V copies of one batched SDPA call on CUDA.
NA_KV_STACK_BUDGET = 2 ** 28


def _window_bounds(length, kernel, causal):
    """Per-index (start, end) of the attended window along one axis."""
    starts = []
    ends = []
    if causal:
        for i in range(length):
            starts.append(max(0, i - kernel + 1))
            ends.append(i + 1)
    else:
        kernel = min(kernel, length)
        lo = length - kernel
        half = kernel // 2
        for i in range(length):
            s = min(max(i - half, 0), lo)
            starts.append(s)
            ends.append(s + kernel)
    return starts, ends


def _pick_tiles(dims, kernels):
    """Per-axis query-tile lengths keeping one tile's [Nq, Nk] under budget."""
    tiles = list(dims)

    def cost(ts):
        nq = math.prod(ts)
        nk = math.prod(
            min(d, t + k - 1) for t, k, d in zip(ts, kernels, dims, strict=True)
        )
        return nq * nk

    while cost(tiles) > NA_SCORE_BUDGET and max(tiles) > 1:
        i = max(range(3), key=lambda a: tiles[a] / kernels[a])
        if tiles[i] <= 1:
            break
        tiles[i] = max(1, (tiles[i] + 1) // 2)
    return tiles


def _group_mask(rel_bounds, dtype, device):
    """Additive ``[1, 1, Nq, Nk]`` mask for one tile-geometry group.

    ``rel_bounds``: per-axis (starts, ends) relative to the key region origin.
    """
    import torch

    bools = []
    for starts, ends in rel_bounds:
        st = torch.tensor(starts, device=device)
        en = torch.tensor(ends, device=device)
        kj = torch.arange(int(en.max()), device=device)
        bools.append((kj[None, :] >= st[:, None]) & (kj[None, :] < en[:, None]))
    visible = (bools[0][:, None, None, :, None, None]
               & bools[1][None, :, None, None, :, None]
               & bools[2][None, None, :, None, None, :])
    nq = visible.shape[0] * visible.shape[1] * visible.shape[2]
    nk = visible.shape[3] * visible.shape[4] * visible.shape[5]
    mask = torch.zeros((nq, nk), dtype=dtype, device=device)
    mask.masked_fill_(~visible.reshape(nq, nk), torch.finfo(dtype).min)
    return mask.reshape(1, 1, nq, nk)


def na3d(
    q: torch.Tensor,
    k: torch.Tensor,
    v: torch.Tensor,
    kernel_size: list[int],
    is_causal: list[bool] | None = None,
    scale: float | None = None,
) -> torch.Tensor:
    """3D neighborhood attention over ``(B, T, H, W, NH, HD)`` tensors."""
    import torch
    import torch.nn.functional as functional

    batch, t, h, w, nh, hd = q.shape
    dims = (t, h, w)
    causal = [False, False, False] if is_causal is None else list(is_causal)
    kernels = [
        k_ if c else min(k_, d)
        for k_, c, d in zip(kernel_size, causal, dims, strict=True)
    ]
    if scale is None:
        scale = hd ** -0.5
    device = q.device
    if scale != 1.0:
        q = q * scale

    bounds = [
        _window_bounds(d, k_, c) for d, k_, c in zip(dims, kernels, causal, strict=True)
    ]
    tile_t, tile_h, tile_w = _pick_tiles(
        dims, [min(k_, d) for k_, d in zip(kernels, dims, strict=True)]
    )

    # Group tiles by relative window geometry so each group shares one mask
    # and stacks into batched SDPA calls.
    groups: dict = {}
    for t0 in range(0, t, tile_t):
        t1 = min(t0 + tile_t, t)
        rt0, rt1 = bounds[0][0][t0], bounds[0][1][t1 - 1]
        rel_t = (tuple(s - rt0 for s in bounds[0][0][t0:t1]),
                 tuple(e - rt0 for e in bounds[0][1][t0:t1]))
        for h0 in range(0, h, tile_h):
            h1 = min(h0 + tile_h, h)
            rh0, rh1 = bounds[1][0][h0], bounds[1][1][h1 - 1]
            rel_h = (tuple(s - rh0 for s in bounds[1][0][h0:h1]),
                     tuple(e - rh0 for e in bounds[1][1][h0:h1]))
            for w0 in range(0, w, tile_w):
                w1 = min(w0 + tile_w, w)
                rw0, rw1 = bounds[2][0][w0], bounds[2][1][w1 - 1]
                rel_w = (tuple(s - rw0 for s in bounds[2][0][w0:w1]),
                         tuple(e - rw0 for e in bounds[2][1][w0:w1]))
                groups.setdefault((rel_t, rel_h, rel_w), []).append((
                    (slice(t0, t1), slice(h0, h1), slice(w0, w1)),
                    (slice(rt0, rt1), slice(rh0, rh1), slice(rw0, rw1)),
                ))

    out = torch.empty((batch, t, h, w, nh, hd), device=device, dtype=v.dtype)
    for rel, tiles in groups.items():
        mask = _group_mask(rel, q.dtype, device)
        nq, nk = mask.shape[2], mask.shape[3]
        if device.type == "cuda":
            g_max = max(1, NA_KV_STACK_BUDGET // max(1, batch * nh * nk * hd * 2))
        else:
            g_max = 1  # CPU math backend materializes [G*B, NH, Nq, Nk]
        qs0, _ = tiles[0]
        tq, th, tw = (qs0[0].stop - qs0[0].start,
                      qs0[1].stop - qs0[1].start,
                      qs0[2].stop - qs0[2].start)
        for c0 in range(0, len(tiles), g_max):
            chunk = tiles[c0:c0 + g_max]
            g = len(chunk)
            q_s = torch.stack([q[:, qs[0], qs[1], qs[2]] for qs, _ in chunk])
            k_s = torch.stack([k[:, rs[0], rs[1], rs[2]] for _, rs in chunk])
            v_s = torch.stack([v[:, rs[0], rs[1], rs[2]] for _, rs in chunk])
            # [G, B, t, h, w, NH, HD] -> [G*B, NH, N, HD]
            q_s = q_s.permute(0, 1, 5, 2, 3, 4, 6).reshape(g * batch, nh, nq, hd)
            k_s = k_s.permute(0, 1, 5, 2, 3, 4, 6).reshape(g * batch, nh, nk, hd)
            v_s = v_s.permute(0, 1, 5, 2, 3, 4, 6).reshape(g * batch, nh, nk, hd)
            o = functional.scaled_dot_product_attention(
                q_s, k_s, v_s, attn_mask=mask, scale=1.0
            )
            o = o.view(g, batch, nh, tq, th, tw, hd).permute(0, 1, 3, 4, 5, 2, 6)
            for i, (qs, _) in enumerate(chunk):
                out[:, qs[0], qs[1], qs[2]] = o[i]

    return out


def _unavailable(*_arguments, **_keywords) -> bool:
    """Stand in for a comfy-kitchen ``*_is_available`` probe this build lacks."""
    return False


def _unsupported(name: str):
    def raise_unsupported(*_arguments, **_keywords):
        raise RuntimeError(
            f"comfy_kitchen.{name} is unavailable on the DirectML torch build. "
            "It is guarded by an availability check that reports False, so "
            "reaching it means ComfyUI changed and this shim needs updating."
        )

    return raise_unsupported


# Only names comfy-kitchen 0.2.27 is missing are filled in; anything the
# installed build already provides is left alone.
_REPLACEMENTS = {
    "int8_attention_is_available": _unavailable,
    "flash_attention_decode_is_available": _unavailable,
    "int8_attention": _unsupported("int8_attention"),
    "int8_attention_from_prequantized": _unsupported("int8_attention_from_prequantized"),
    "prequantize_int8_attention": _unsupported("prequantize_int8_attention"),
    "flash_attention_decode": _unsupported("flash_attention_decode"),
    "na3d": na3d,
}


def patch(module) -> list[str]:
    """Add the missing symbols to an imported ``comfy_kitchen``."""
    added = []
    for name, replacement in _REPLACEMENTS.items():
        if not hasattr(module, name):
            setattr(module, name, replacement)
            added.append(name)
    return added


class _CompatLoader:
    """Delegating loader that patches ``comfy_kitchen`` once it has executed."""

    def __init__(self, loader):
        self._loader = loader

    def create_module(self, spec):
        return self._loader.create_module(spec)

    def exec_module(self, module) -> None:
        self._loader.exec_module(module)
        patch(module)

    def __getattr__(self, name):
        return getattr(self._loader, name)


class _CompatFinder:
    """Wrap the real ``comfy_kitchen`` spec so its loader gets the patch step."""

    def find_spec(self, fullname, path=None, target=None):
        if fullname != MODULE_NAME:
            return None
        for finder in sys.meta_path:
            if finder is self:
                continue
            find_spec = getattr(finder, "find_spec", None)
            if find_spec is None:
                continue
            spec = find_spec(fullname, path, target)
            if spec is not None and spec.loader is not None:
                spec.loader = _CompatLoader(spec.loader)
                return spec
        return None


def install() -> None:
    """Arrange for ``comfy_kitchen`` to be patched, importing nothing eagerly."""
    if any(isinstance(finder, _CompatFinder) for finder in sys.meta_path):
        return
    existing = sys.modules.get(MODULE_NAME)
    if existing is not None:
        patch(existing)
    sys.meta_path.insert(0, _CompatFinder())


try:
    install()
except Exception as error:  # pragma: no cover - a .pth failure must not be fatal
    print(f"[ovs] comfy_kitchen compatibility shim not installed: {error}")
