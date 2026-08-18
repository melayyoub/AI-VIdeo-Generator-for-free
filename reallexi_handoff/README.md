# reallexi_handoff

Frame-quality gating for **chained image-to-video** pipelines (LTX-2.x, Wan, any
setup where shot N+1 is seeded with a frame from shot N).

In a chain, one bad frame poisons every shot downstream. `GetImagesFromBatchIndexed`
at `-1` takes the literal last frame, which is usually the most motion-blurred and the
weakest tail of a long latent. Backing off to a fixed `-6` is still a guess. These
nodes look at the frames instead.

## Nodes

### Handoff Frame Select
Scores a window of candidate frames from the tail of a clip and returns the best one.

| term | catches | default |
|---|---|---|
| sharpness (variance of Laplacian) | motion blur | 1.0 |
| identity (histogram + coarse structural cosine vs a reference) | gross drift | 1.0 |
| recency (linear, favours later frames) | **protects the cut** | 0.6 |
| clipping (fraction crushed or blown) | flare frames that read as sharp but are useless | −2.0 |

Recency is what keeps the connection smooth: the node searches only the last `window`
frames and prefers the latest, so it picks *the latest good frame* rather than the best
frame anywhere in the clip. Raise it to favour continuity, lower it to favour quality.

Outputs `frame`, `index`, `score`, and a `report` table showing every candidate's
scores and which one won.

### Handoff Quality Gate
If the chosen frame still fails against a known-good reference, forwards the reference
instead. ComfyUI cannot branch mid-graph, so this is a pure selection between two
already-computed inputs. Falling back trades continuity for identity, so it should trip
rarely — read `passed` and the report.

### Handoff Color Match
Transfers the reference's colour statistics onto the frame, so grade drift cannot
accumulate down the chain. `mean/std` (Reinhard, keeps local contrast) or `histogram`
(full CDF match, stronger, can band). `strength` blends against the original;
`preserve_luminance` corrects hue and saturation but keeps the frame's brightness.

Place it **after** the gate — the gate should judge the raw pick, not a frame already
rescued by a grade correction that hides real drift.

## Install

```bash
python reallexi_handoff/install.py --comfy "<path to ComfyUI>"
python reallexi_handoff/install.py --link       # junction/symlink for development
python reallexi_handoff/install.py --uninstall
```

`--link` points `custom_nodes` at this folder instead of copying, so repo edits go live
on the next ComfyUI restart. On Windows it makes a directory junction, which does not
need Administrator.

Restart ComfyUI and hard-refresh the browser afterwards — the frontend caches its node
list.

## Tests

```bash
python -m reallexi_handoff.tests.test_scoring
```

No GPU and no torch required. `scoring.py` is pure numpy with no ComfyUI import, which
is the whole reason the maths is testable; `nodes.py` owns the tensor boundary.

## Layout

```
reallexi_handoff/
├── __init__.py      node registration
├── nodes.py         ComfyUI node classes, torch boundary
├── scoring.py       pure numpy metrics
├── install.py       deploy into custom_nodes
├── pyproject.toml   Comfy Registry metadata
└── tests/
    └── test_scoring.py
```

## Limits

The identity metric is a tripwire for wholesale collapse — wrong palette, wrong layout,
subject gone. It will not notice a subtly different jawline. For that you need a
character LoRA or a real face-embedding node. Colour match fixes grade, not render
medium: a frame that came out as 3D animation stays 3D animation, correctly graded.
