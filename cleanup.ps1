$root = "E:\python-projects\custom-wan\ComfyUI\custom_nodes"

# List of failed node folder names from your log:
$failed = @(
"arabic_auto_transliterate_node",
"ComfyUI-GGUF-FantasyTalking",
"ComfyUI-LMCQ",
"ComfyUI-XTTS",
"comfyui_sunxAI_facetools",
"reallexi_video_output",
"ComfyUI_PuLID_Flux_ll_FaceNet",
"pulid_comfyui",
"comfyui_pulid_flux_ll",
"comfyui_zenid",
"comfyui_instantid",
"ComfyUI-ReActor",
"ComfyUI-MagicAnimate",
"ComfyUI-YoloWorld-EfficientSAM",
"ComfyUI_Fill-ChatterBox",
"comfyui-f5-tts",
"PyramidFlow-ComfyUI",
"chattts",
"comfyui-LatentSync",
"comfyui-hunyuanvideowrapper",
"ComfyUI-speech-dataset-toolkit",
"ComfyUI-tbox",
"ComfyUI_RH_DMOSpeech2",
"stepaudiotts_mw",
"ComfyUI-3D-Pack"
)

foreach ($f in $failed) {
    $path = Join-Path $root $f
    if (Test-Path $path) {
        Write-Host "Deleting $path" -ForegroundColor Red
        Remove-Item $path -Recurse -Force
    }
}
