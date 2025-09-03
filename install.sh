# Full install (CUDA 12.1) + 5B model + Manager + start
python wan2_cli.py install --cuda cu121 --models 5b --with-manager --start

# CPU-only with all model variants, bind all interfaces
python wan2_cli.py install --cuda cpu --models all --start --listen-all

# Download models later
python wan2_cli.py models --models 14b

# Create React loader targeting local ComfyUI
python wan2_cli.py react --name comfy-loader --url http://127.0.0.1:8188

# Start ComfyUI any time
python wan2_cli.py start --port 8188
