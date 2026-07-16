# Support

This repository is a community project and is not an official support channel
for ComfyUI, Wan, PyTorch, Hugging Face, GPU vendors, or custom-node authors.
Support is best effort, with no guaranteed response time or compatibility
commitment.

## Start here

1. Read the README troubleshooting section and the platform guide in `docs/`.
2. Run the smallest relevant dry run or validation command from
   [docs/testing.md](docs/testing.md).
3. Search the repository's Issues for the exact error text.
4. If the problem remains, open a GitHub Issue with a concise reproduction.

Include the project revision, operating system, Python version, selected
backend and model set, command shape, expected behavior, actual behavior, and
the shortest useful log excerpt. Say whether the failure occurs before or
after ComfyUI itself starts.

Before posting, remove access tokens, cookies, private prompts, source images,
generated media, usernames, machine names, public IP addresses, and absolute
local paths. Replace them with descriptive placeholders. Do not attach an
entire environment, model file, or unreviewed log archive.

## Where an issue belongs

- Use this repository when its installer, launcher, validation, or
  project-authored documentation is the likely cause.
- Use the upstream ComfyUI project when the same problem occurs in a clean,
  independently installed ComfyUI checkout.
- Use the relevant custom-node project for a problem isolated to that node.
- Use the model repository or publisher's channel for model access, terms,
  model-card, or model-content questions.
- Use PyTorch or the GPU vendor's support resources for driver/runtime problems
  reproduced outside this installer.

Security-sensitive findings follow [SECURITY.md](SECURITY.md), not the public
support workflow.
