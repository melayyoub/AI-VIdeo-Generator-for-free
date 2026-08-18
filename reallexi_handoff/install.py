#!/usr/bin/env python3
"""
install.py — deploy this package into <ComfyUI>/custom_nodes.

The repo copy is the source of truth. This script only pushes it out.

    python -m reallexi_handoff.install                     # auto-detect ComfyUI
    python reallexi_handoff/install.py --comfy <path>      # explicit
    python reallexi_handoff/install.py --link              # junction/symlink
    python reallexi_handoff/install.py --uninstall

--link is the one to use while developing: it points custom_nodes at the repo
folder rather than copying, so edits here are live after a ComfyUI restart with
no re-deploy step. On Windows it creates a directory junction, which does not
need Administrator (unlike a real symlink).
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import shutil
import subprocess
import sys
import traceback
from pathlib import Path

PKG = "reallexi_handoff"
REQUIRED = ("HandoffFrameSelect", "HandoffQualityGate", "HandoffColorMatch")

# Only these ship. Tests, caches and repo metadata stay behind.
DEPLOY = ("__init__.py", "nodes.py", "scoring.py", "pyproject.toml", "README.md")

CANDIDATES = (
    Path(r"C:\Users\samsa\python-projects\custom-wan\ComfyUI"),
    Path.home() / "python-projects" / "custom-wan" / "ComfyUI",
    Path.home() / "ComfyUI",
    Path("/opt/ComfyUI"),
)


def package_root() -> Path:
    """This file lives inside the package, so its parent IS the package."""
    here = Path(__file__).resolve().parent
    if (here / "__init__.py").is_file():
        return here
    sys.exit(f"{here} does not look like the {PKG} package (no __init__.py)")


def find_comfy(explicit) -> Path:
    if explicit:
        p = Path(explicit).expanduser().resolve()
        if not (p / "custom_nodes").is_dir():
            sys.exit(f"no custom_nodes/ under {p} — is that a ComfyUI root?")
        return p

    here = package_root()
    # walk up from the repo: ComfyUI is often a sibling
    probes = list(CANDIDATES)
    for up in (here, *here.parents[:4]):
        probes.append(up / "ComfyUI")
        probes.append(up.parent / "ComfyUI")
    for c in probes:
        if (c / "custom_nodes").is_dir():
            return c.resolve()

    print("could not locate ComfyUI. Looked for a custom_nodes/ folder under:")
    for c in dict.fromkeys(probes):
        print(f"    {c}")
    sys.exit("pass --comfy <path to ComfyUI root>")


def verify(target: Path) -> bool:
    """Import exactly the way ComfyUI's loader does."""
    spec = importlib.util.spec_from_file_location(
        PKG, target / "__init__.py", submodule_search_locations=[str(target)])
    mod = importlib.util.module_from_spec(spec)
    sys.modules[PKG] = mod
    try:
        spec.loader.exec_module(mod)
    except Exception:                                  # noqa: BLE001
        print("\n  import FAILED — ComfyUI would skip this pack:\n")
        traceback.print_exc()
        return False

    names = list(getattr(mod, "NODE_CLASS_MAPPINGS", {}))
    print(f"  import OK — v{getattr(mod, '__version__', '?')}, "
          f"{len(names)} nodes registered:")
    for n in names:
        print(f"    {n:22} → {mod.NODE_DISPLAY_NAME_MAPPINGS.get(n, n)}")
    missing = [n for n in REQUIRED if n not in names]
    if missing:
        print(f"  MISSING: {missing}")
        return False
    return True


def make_link(src: Path, dst: Path) -> None:
    if os.name == "nt":
        # junction: no Administrator needed, unlike mklink /D
        subprocess.run(["cmd", "/c", "mklink", "/J", str(dst), str(src)],
                       check=True, capture_output=True)
    else:
        os.symlink(src, dst, target_is_directory=True)


def remove(dst: Path) -> None:
    if dst.is_symlink():
        dst.unlink()
    elif dst.is_dir():
        if os.name == "nt":
            # a junction reports as a dir; rmdir removes the link, not the target
            try:
                os.rmdir(dst)
                return
            except OSError:
                pass
        shutil.rmtree(dst)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--comfy", help="ComfyUI root directory")
    ap.add_argument("--link", action="store_true",
                    help="junction/symlink instead of copying — edits in the "
                         "repo go live on the next ComfyUI restart")
    ap.add_argument("--uninstall", action="store_true")
    args = ap.parse_args()

    src = package_root()
    comfy = find_comfy(args.comfy)
    dst = comfy / "custom_nodes" / PKG

    print(f"repo    : {src}")
    print(f"ComfyUI : {comfy}")
    print(f"target  : {dst}")

    if args.uninstall:
        if dst.exists() or dst.is_symlink():
            remove(dst)
            print("removed. Restart ComfyUI.")
        else:
            print("nothing installed there.")
        return

    if src == dst:
        print("\nthe repo IS the install target — verifying in place.\n")
        sys.exit(0 if verify(dst) else 1)

    if dst.exists() or dst.is_symlink():
        remove(dst)

    if args.link:
        try:
            make_link(src, dst)
            print("mode    : linked (edits in the repo are live)")
        except (OSError, subprocess.CalledProcessError) as e:
            print(f"link failed ({e}); falling back to a copy")
            args.link = False
    if not args.link:
        dst.mkdir(parents=True)
        for name in DEPLOY:
            f = src / name
            if f.is_file():
                shutil.copy2(f, dst / name)
        print(f"mode    : copied {len([n for n in DEPLOY if (src / n).is_file()])} files")

    print()
    ok = verify(dst)
    print()
    if ok:
        print("Done. Restart ComfyUI, then hard-refresh the browser (Ctrl+Shift+R).")
        print("The nodes appear under 'Reallexi/handoff' in node search.")
    else:
        print("Did not verify. Use LTX25_Multi_Shot_COMPAT.json meanwhile — it")
        print("needs no custom nodes.")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
