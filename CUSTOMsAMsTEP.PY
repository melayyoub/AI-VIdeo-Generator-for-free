import torch
from safetensors.torch import save_file

ckpt_path = r"E:\foxwolf-generator\aceTrainer\runs\SamStep-LoRA\checkpoints\samstep.ckpt"
out_path = r"E:\python-projects\custom-wan\ComfyUI\models\loras\samstep_lora.safetensors"

ckpt = torch.load(ckpt_path, map_location="cpu")
state_dict = ckpt["state_dict"]

# Keep only LoRA weights
lora_dict = {k.replace("model.", ""): v for k, v in state_dict.items() if "lora_" in k.lower()}

if not lora_dict:
    raise ValueError("No LoRA layers found — are you sure this is a LoRA fine-tune?")

save_file(lora_dict, out_path)
print(f"✅ Saved LoRA adapter for ComfyUI → {out_path}")