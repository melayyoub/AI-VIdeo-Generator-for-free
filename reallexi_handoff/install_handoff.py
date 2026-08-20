#!/usr/bin/env python3
"""
install_handoff.py — put reallexi_handoff where ComfyUI will find it.

    python install_handoff.py
    python install_handoff.py --comfy /path/to/ComfyUI

Copies the pack into <ComfyUI>/custom_nodes/reallexi_handoff/, then imports it
exactly the way ComfyUI does and prints the node names it registered. If the
import fails you get the traceback here instead of buried in the server log.
"""
import argparse
import importlib.util
import shutil
import sys
import traceback
from pathlib import Path

import os

_REALLEXI_COMFYUI_ROOT = os.environ.get("REALLEXI_COMFYUI_ROOT", "").strip()

CANDIDATES = [
    *([Path(_REALLEXI_COMFYUI_ROOT)] if _REALLEXI_COMFYUI_ROOT else []),
    Path.home() / "ComfyUI",
    Path("/opt/ComfyUI"),
    Path.cwd() / "ComfyUI",
    Path.cwd().parent / "ComfyUI",
]


def resolve_source(explicit):
    """Find the pack whether this script sits beside it or inside it."""
    if explicit:
        p = Path(explicit).expanduser()
        if (p / "__init__.py").is_file():
            return p
        if (p / "reallexi_handoff" / "__init__.py").is_file():
            return p / "reallexi_handoff"
        sys.exit(f"no __init__.py under {p}")

    here = Path(__file__).resolve().parent
    for cand in (here / "reallexi_handoff",      # script beside the pack
                 here,                            # script inside the pack
                 Path.cwd() / "reallexi_handoff",
                 Path.cwd()):
        if (cand / "__init__.py").is_file():
            return cand

    print("could not find reallexi_handoff/__init__.py. Looked in:")
    seen = []
    for cand in (here / "reallexi_handoff", here,
                 Path.cwd() / "reallexi_handoff", Path.cwd()):
        if cand not in seen:
            seen.append(cand)
            print(f"    {cand}")
    print()
    print(f"contents of {here}:")
    for f in sorted(here.iterdir())[:20]:
        print(f"    {f.name}{'/' if f.is_dir() else ''}")
    sys.exit("pass --source <folder containing __init__.py>")


def find_comfy(explicit):
    if explicit:
        p = Path(explicit).expanduser()
        if not (p / "custom_nodes").is_dir():
            sys.exit(f"no custom_nodes/ under {p} — is that a ComfyUI root?")
        return p
    for c in CANDIDATES:
        if (c / "custom_nodes").is_dir():
            return c
    sys.exit("could not locate ComfyUI. Pass --comfy <path to ComfyUI root>.")


def verify(pkg: Path) -> bool:
    spec = importlib.util.spec_from_file_location("reallexi_handoff",
                                                  pkg / "__init__.py")
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)
    except Exception:                                  # noqa: BLE001
        print("\nimport FAILED — ComfyUI would skip this pack:\n")
        traceback.print_exc()
        return False
    names = list(getattr(mod, "NODE_CLASS_MAPPINGS", {}))
    print(f"  import OK — registered {len(names)} nodes:")
    for n in names:
        print(f"    {n:22} → {mod.NODE_DISPLAY_NAME_MAPPINGS.get(n, n)}")
    missing = [n for n in ("HandoffFrameSelect", "HandoffQualityGate",
                           "HandoffColorMatch") if n not in names]
    if missing:
        print(f"  MISSING: {missing}")
        return False
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--comfy", help="path to the ComfyUI root directory")
    ap.add_argument("--source", help="path to the reallexi_handoff folder "
                                     "(auto-detected if omitted)")
    args = ap.parse_args()

    src = resolve_source(args.source)

    comfy = find_comfy(args.comfy)
    dst = comfy / "custom_nodes" / "reallexi_handoff"
    print(f"source  : {src}")
    print(f"ComfyUI : {comfy}")
    print(f"target  : {dst}")

    if src.resolve() == dst.resolve():
        print("source is already the install target — verifying in place.")
        print()
        ok = verify(dst)
        print()
        print("Restart ComfyUI and hard-refresh the browser (Ctrl+Shift+R)."
              if ok else "Import failed — see the traceback above.")
        sys.exit(0 if ok else 1)

    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    shutil.copy2(src / "__init__.py", dst / "__init__.py")
    print(f"copied  : {dst / '__init__.py'}")
    print()

    ok = verify(dst)
    print()
    if ok:
        print("Done. Restart ComfyUI, then hard-refresh the browser "
              "(Ctrl+Shift+R).")
        print("The nodes appear under 'Reallexi/handoff' in node search.")
    else:
        print("Install did not verify. Use LTX25_Multi_Shot_COMPAT.json, which "
              "needs no custom nodes.")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
