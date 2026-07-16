# Model provenance and licensing

The installer downloads model files from the Hugging Face repository
`Comfy-Org/Wan_2.2_ComfyUI_Repackaged`. This identifies the configured delivery
source; it is not a claim that this community project created, owns, audited, or
endorses the models.

The repository's MIT license applies to project-authored source code and
documentation. It does not grant a license to downloaded model weights,
encoders, VAEs, input media, outputs, ComfyUI, or other dependencies. Before
use or redistribution, read the current model card, repository files, and terms
at the upstream source. Terms can differ by artifact and can change independently
of this project.

The delivery source and revision are runtime configuration rather than local
machine state. Use `CUSTOM_WAN_MODEL_REPOSITORY` and
`CUSTOM_WAN_MODEL_REVISION`, or the corresponding installer/CLI arguments, to
select an approved repository and immutable commit without editing source.

The same rule applies to workflow exports. Examples with unknown redistribution
terms, unverifiable creator attribution, embedded account metadata, or
third-party temporary assets are excluded rather than republished without
permission or attribution.

## Configured artifacts

| Selection | Diffusion model files |
| --- | --- |
| `5b` | `wan2.2_ti2v_5B_fp16.safetensors` |
| `14b` | `wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors`, `wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors` |
| `i2v` | `wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors`, `wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors` |
| `all` | all diffusion model files above |

The versioned source of truth is `config/models.json`. The configured shared
text encoder is `umt5_xxl_fp8_e4m3fn_scaled.safetensors`; the manifest maps
`wan2.2_vae.safetensors` to `5b` and `wan_2.1_vae.safetensors` to the `14b` and
`i2v` groups. The PowerShell and Python installers consume the same repository,
revision, artifact, selection, and destination mapping and place files under
the local `ComfyUI/models/` tree.

## Current verification limits

- Default downloads resolve through the immutable upstream revision recorded in
  `config/models.json`. An operator override may intentionally select another
  branch, tag, or commit.
- This project does not maintain expected cryptographic hashes or signatures
  for the model artifacts.
- The Windows downloader treats an existing file larger than its sanity
  threshold as reusable; that size check does not prove identity or integrity.
- Safetensors format reduces some risks associated with executable pickle data,
  but the format alone does not establish provenance, quality, suitability, or
  license rights.

For a higher-assurance or reproducible deployment, independently record the
upstream repository revision, artifact path, byte length, cryptographic digest,
retrieval date, model-card version, and applicable terms. Verify those values
before installation and again before redistribution.

## Tokens and local data

`HF_TOKEN` is optional and may be used by the downloader for upstream access.
Treat it as a secret: provide it through the process environment, scope it as
narrowly as the provider permits, and never commit it or paste it into logs or
Issues. Download services necessarily receive ordinary connection metadata and
artifact requests. Prompts, source images, and generated outputs are not sent
to the model repository by this project's downloader, but separately installed
custom nodes may have different behavior.

## Updating the manifest

A pull request that changes a repository, filename, revision strategy, token
flow, or selection mapping should explain the source, upstream terms reviewed,
compatibility evidence, expected storage impact, and validation actually run.
Do not copy a model into this repository or imply that technical download
success grants redistribution rights.
