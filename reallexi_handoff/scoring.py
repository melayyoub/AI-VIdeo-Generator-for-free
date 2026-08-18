"""
Frame-quality metrics for chained image-to-video handoff.

Deliberately pure numpy and free of any ComfyUI or torch import, so the maths
can be unit-tested on any machine. `nodes.py` owns the tensor boundary.

Every function takes float32 arrays in 0..1, shaped [H, W, C] (or [H, W]).
"""

from __future__ import annotations

import numpy as np

_LAPLACIAN = np.array([[0.0, 1.0, 0.0],
                       [1.0, -4.0, 1.0],
                       [0.0, 1.0, 0.0]], dtype=np.float32)


def _gray(img: np.ndarray) -> np.ndarray:
    """[H,W,C] float 0..1 -> [H,W] luma."""
    if img.ndim == 2:
        return img
    c = img.shape[-1]
    if c == 1:
        return img[..., 0]
    return (0.2126 * img[..., 0] + 0.7152 * img[..., 1] + 0.0722 * img[..., 2])


def _downsample(img: np.ndarray, max_edge: int = 256) -> np.ndarray:
    """Cheap strided decimation. Scoring does not need full resolution, and
    downsampling also suppresses per-pixel noise that would otherwise read as
    'sharpness'."""
    h, w = img.shape[:2]
    step = max(1, int(max(h, w) / max_edge))
    return img[::step, ::step]


def _conv2d_valid(x: np.ndarray, k: np.ndarray) -> np.ndarray:
    kh, kw = k.shape
    h, w = x.shape
    if h < kh or w < kw:
        return np.zeros((1, 1), dtype=np.float32)
    win = np.lib.stride_tricks.sliding_window_view(x, (kh, kw))
    return np.einsum("ijkl,kl->ij", win, k)


def sharpness(img: np.ndarray) -> float:
    """Variance of the Laplacian. Higher = crisper. This is the metric that
    actually catches motion blur on the tail frames."""
    g = _downsample(_gray(img))
    lap = _conv2d_valid(g, _LAPLACIAN)
    return float(lap.var())


def exposure_penalty(img: np.ndarray) -> float:
    """Fraction of pixels crushed to black or blown to white. Video models
    sometimes flare or collapse on the final frames; those frames look 'sharp'
    to a Laplacian but are useless as an identity anchor."""
    g = _downsample(_gray(img))
    clipped = np.mean((g < 0.02) | (g > 0.98))
    return float(clipped)


def _hist(img: np.ndarray, bins: int = 32) -> np.ndarray:
    d = _downsample(img)
    if d.ndim == 2:
        d = d[..., None]
    out = []
    for c in range(d.shape[-1]):
        h, _ = np.histogram(d[..., c], bins=bins, range=(0.0, 1.0))
        out.append(h.astype(np.float32))
    v = np.concatenate(out)
    n = np.linalg.norm(v)
    return v / n if n > 0 else v


def _structure(img: np.ndarray, size: int = 32) -> np.ndarray:
    g = _gray(img)
    h, w = g.shape
    ys = np.linspace(0, h - 1, size).astype(int)
    xs = np.linspace(0, w - 1, size).astype(int)
    small = g[np.ix_(ys, xs)].astype(np.float32).ravel()
    small = small - small.mean()
    n = np.linalg.norm(small)
    return small / n if n > 0 else small


def similarity(img: np.ndarray, ref: np.ndarray) -> float:
    """Gross-drift detector: colour-histogram + coarse structural cosine.

    This catches wholesale identity collapse - wrong palette, wrong layout,
    subject gone. It does NOT catch subtle face changes; nothing this cheap
    does. Treat it as a tripwire, not a face-verification model.
    """
    hs = float(np.dot(_hist(img), _hist(ref)))
    ss = float(np.dot(_structure(img), _structure(ref)))
    return 0.5 * hs + 0.5 * (0.5 * ss + 0.5)          # both mapped to 0..1


def score_window(frames: np.ndarray, ref: np.ndarray | None,
                 w_sharp: float, w_ident: float, w_recency: float,
                 clip_penalty: float):
    """frames: [N,H,W,C] float 0..1, oldest -> newest. Returns (scores, parts)."""
    n = len(frames)
    sharp = np.array([sharpness(f) for f in frames], dtype=np.float32)
    clip = np.array([exposure_penalty(f) for f in frames], dtype=np.float32)
    ident = (np.array([similarity(f, ref) for f in frames], dtype=np.float32)
             if ref is not None else np.ones(n, dtype=np.float32))

    # normalise sharpness within the window - absolute values are scene-dependent
    lo, hi = float(sharp.min()), float(sharp.max())
    sharp_n = (sharp - lo) / (hi - lo) if hi > lo else np.ones(n, dtype=np.float32)

    # recency: prefer the latest frame so the cut stays tight and motion connects
    recency = np.linspace(0.0, 1.0, n, dtype=np.float32) if n > 1 else np.ones(1)

    total = (w_sharp * sharp_n + w_ident * ident + w_recency * recency
             - clip_penalty * clip)
    return total, {"sharp_raw": sharp, "sharp_norm": sharp_n,
                   "ident": ident, "clip": clip, "recency": recency}


def _meanstd_match(img: np.ndarray, ref: np.ndarray) -> np.ndarray:
    """Reinhard-style per-channel transfer. Gentle: keeps local contrast."""
    out = np.empty_like(img)
    for c in range(img.shape[-1]):
        a, b = img[..., c], ref[..., min(c, ref.shape[-1] - 1)]
        sa, sb = a.std(), b.std()
        gain = (sb / sa) if sa > 1e-5 else 1.0
        out[..., c] = (a - a.mean()) * gain + b.mean()
    return out


def _hist_match(img: np.ndarray, ref: np.ndarray) -> np.ndarray:
    """Full per-channel CDF match. Strong: will also flatten contrast
    differences, at some risk of banding on smooth gradients."""
    out = np.empty_like(img)
    for c in range(img.shape[-1]):
        a = img[..., c].ravel()
        b = ref[..., min(c, ref.shape[-1] - 1)].ravel()
        vals, inv, counts = np.unique(a, return_inverse=True, return_counts=True)
        bvals, bcounts = np.unique(b, return_counts=True)
        acdf = np.cumsum(counts).astype(np.float64) / a.size
        bcdf = np.cumsum(bcounts).astype(np.float64) / b.size
        interp = np.interp(acdf, bcdf, bvals)
        out[..., c] = interp[inv].reshape(img.shape[:2])
    return out
