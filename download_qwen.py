from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="Qwen/Qwen3-VL-2B-Instruct",
    local_dir=r"E:\python-projects\custom-wan\ComfyUI\models\LLM\Qwen-VL",
    local_dir_use_symlinks=False
)

print("Download complete")
