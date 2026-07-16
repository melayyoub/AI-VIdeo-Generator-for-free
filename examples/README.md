# Workflow examples

These workflows are portable configuration examples. They do not include input
media, model weights, generated output, browser previews, or user workspace
metadata.

After importing a workflow, select your own input files through ComfyUI and
choose models that you are licensed to use. Placeholder filenames and relative
paths are not evidence that an asset is bundled with this repository.

Before contributing an exported workflow, remove preview `fullpath` values,
temporary media URLs, access-token query strings, node-owner identifiers, and
workspace identifiers:

```console
python scripts/sanitize_workflows.py --write
python scripts/sanitize_workflows.py
```

Only contribute workflows you created or have explicit permission to
redistribute. When attribution is required, include a verified source URL and
license in the pull request. Workflows with unknown redistribution terms are
not accepted.
