"""Extract LoRA tensors from a PyTorch checkpoint into safetensors format."""

from __future__ import annotations

import argparse
from pathlib import Path

import torch
from safetensors.torch import save_file


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Source PyTorch checkpoint")
    parser.add_argument("output", type=Path, help="Destination .safetensors file")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    checkpoint_path = args.input.expanduser().resolve()
    output_path = args.output.expanduser().resolve()

    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    state_dict = checkpoint.get("state_dict", checkpoint)
    if not isinstance(state_dict, dict):
        raise TypeError(
            "Checkpoint must contain a tensor mapping or a 'state_dict' mapping."
        )

    lora_tensors = {
        key.removeprefix("model."): value
        for key, value in state_dict.items()
        if "lora_" in key.lower()
    }
    if not lora_tensors:
        raise ValueError("No LoRA tensors were found in the checkpoint.")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    save_file(lora_tensors, output_path)
    print(f"Saved {len(lora_tensors)} LoRA tensors to {output_path}")


if __name__ == "__main__":
    main()
