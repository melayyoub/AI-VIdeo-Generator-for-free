# Security policy

This is a community-maintained installer and launcher, not an upstream ComfyUI,
Wan, PyTorch, Hugging Face, or custom-node project. Its security scope covers
the code and documentation maintained in this repository.

## Supported code

Security fixes are considered for the current default branch. There is no
commitment to backport fixes to older revisions, tags, forks, locally modified
copies, or downloaded third-party components. Check the repository's Releases
and default branch before assuming a particular revision is maintained.

## Report a vulnerability

Use the repository's **Security** tab and GitHub's private vulnerability
reporting flow when it is available. Include the affected revision, platform,
configuration, reproduction steps, impact, and a minimal proof of concept.
Remove access tokens, prompts, generated media, usernames, hostnames, and local
filesystem details that are not essential to the report.

If private vulnerability reporting is unavailable, open a GitHub Issue with no
exploit details or sensitive data and ask for a private reporting path to be
enabled. Do not publish credentials, weaponized examples, or information that
would put users at immediate risk.

The project does not promise a response or disclosure deadline. Reporters and
maintainers should coordinate a disclosure only after users have a practical
mitigation or fix.

## Security boundaries

The installers clone or update third-party code and download Python packages
and large model files over the network. The current model downloads are not
pinned to an immutable repository revision and are not checked against
project-maintained cryptographic hashes. Review
[docs/model-provenance.md](docs/model-provenance.md) before using or
redistributing them in a higher-assurance environment.

The launcher binds to `127.0.0.1` by default. `--listen-all` and the equivalent
installer option expose ComfyUI to other network peers; they do not add
authentication, authorization, TLS, or a firewall. Do not expose ComfyUI
directly to the public internet.

Prompts and generated media are handled by the local ComfyUI deployment, but
installed custom nodes and other third-party components may implement their own
network or data behavior. Review those components separately.

The repository's MIT license covers this project's source. It does not grant
rights to ComfyUI, models, Python packages, custom nodes, input media, or
generated output. Their upstream terms apply independently.

## Out of scope

Use the relevant upstream project's security process for vulnerabilities that
exist only in an unmodified upstream dependency, model host, model, driver,
operating system, GPU runtime, or third-party custom node. A concise Issue may
still be used to track whether this installer needs a version constraint,
warning, or mitigation, but sensitive details should remain in the upstream
private report.
