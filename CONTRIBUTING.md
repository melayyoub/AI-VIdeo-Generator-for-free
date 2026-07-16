# Contributing

Thank you for helping improve this community-maintained installer and launcher.
This repository is not the upstream ComfyUI or Wan project. Changes here should
stay focused on making the local setup safer, more repeatable, and easier to
understand.

## Before opening a change

- Search the repository's Issues and existing pull requests for related work.
- Use an Issue for a reproducible bug or a scoped proposal. Support questions
  belong in the support workflow described in [SUPPORT.md](SUPPORT.md).
- Report security-sensitive findings privately as described in
  [SECURITY.md](SECURITY.md).

Small, single-purpose pull requests are easiest to review. When a product choice
is uncertain, prefer an optional argument or a narrowly defined interface over
changing established defaults. In particular, keep loopback-only network
binding and non-destructive virtual-environment lock handling as the defaults.

## Development setup

Use a supported Python 3 installation, Git, PowerShell 7, npm, and `ruff`. On
Windows, the lock-handling integration test also uses Windows PowerShell 5.1
and the Python 3.10 launcher. Git Bash or another Bash executable is needed for
shell syntax and dry-run validation.

Do not commit a generated `ComfyUI/` checkout, virtual environments, models,
download caches, logs, credentials, prompts, outputs, or machine-specific
paths. The root `.gitignore` covers the common local artifacts, but contributors
remain responsible for reviewing the staged diff.

## Make and validate a change

1. Create a branch from the current default branch.
2. Add or update tests for behavior changes. Tests must not modify a real
   `ComfyUI/.venv` or require model downloads.
3. Update the relevant README or `docs/` page when commands, defaults, model
   selection, network behavior, or security boundaries change.
4. Run the local validation suite:

   ```powershell
   npm run check
   ```

5. Inspect the final diff for secrets, personal data, absolute local paths, and
   unrelated generated changes.

See [docs/testing.md](docs/testing.md) for individual checks and platform
expectations.

## Review-sensitive changes

Call out these changes explicitly in the pull request:

- new download hosts, Git repositories, packages, custom nodes, or executable
  content;
- changes to process termination, recursive deletion, path normalization, token
  handling, or network binding;
- model filenames, repositories, selection rules, or licensing assumptions;
- dependency upgrades that alter supported Python, CUDA, or operating-system
  combinations.

Do not describe a dependency or model as trusted merely because the installer
can download it. Record its source and the verification that was actually
performed. Model-specific guidance is in
[docs/model-provenance.md](docs/model-provenance.md).

## Pull request description

Include:

- the user-visible problem and intended behavior;
- platforms and backend selections tested;
- exact commands run and their actual results;
- security, privacy, compatibility, and rollback considerations;
- any checks that could not be run and why.

Submission does not guarantee acceptance or a response time. Review and support
are provided by the community on a best-effort basis.
