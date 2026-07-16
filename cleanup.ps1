[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string] $ProjectPath = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = [IO.Path]::GetFullPath($ProjectPath)
$root = Join-Path $projectRoot 'ComfyUI\custom_nodes'
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "Custom-node directory was not found: $root"
}

# List of failed node folder names from your log:
$failed = @(
"arabic_auto_transliterate_node",
"ComfyUI-GGUF-FantasyTalking",
"ComfyUI-LMCQ",
"ComfyUI-XTTS",
"comfyui_sunxAI_facetools",
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
    if ((Test-Path -LiteralPath $path) -and $PSCmdlet.ShouldProcess($path, 'Remove custom node directory')) {
        Write-Host "Deleting $path" -ForegroundColor Red
        Remove-Item -LiteralPath $path -Recurse -Force
    }
}
