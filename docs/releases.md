# Release process

Releases are maintainer-driven and validated locally. This repository does not
require GitHub Actions to establish release readiness. A tag or archive should
only be described as tested for the platforms and configurations that were
actually exercised.

## Versioning

Use semantic versioning for project-authored installer, launcher, and CLI
behavior:

- **major**: an intentional incompatible command, default, filesystem, or
  support-policy change;
- **minor**: a backward-compatible capability or newly supported platform,
  backend, or model selection;
- **patch**: a backward-compatible bug, documentation, or security fix.

Third-party ComfyUI, model, package, driver, and CUDA versions have independent
lifecycles. The project version does not imply that those components share its
version or support window.

## Candidate checklist

1. Start from a clean, reviewed tree. Exclude local ComfyUI state, models,
   caches, logs, credentials, and generated media.
2. Review user-facing commands, defaults, architecture, support boundaries,
   security guidance, model provenance, and license notices.
3. Run `npm run check` on the intended release commit and record the actual
   output. Run additional disposable-platform or GPU smoke tests when the change
   affects those paths.
4. Confirm fresh-install and upgrade/reuse behavior separately when either has
   changed. Exercise `-LockedVenvAction Fail` before any explicit `Stop` path on
   Windows.
5. Review every new or changed external URL, dependency, repository, model
   filename, and credential flow.
6. Create an annotated tag only after the commit and documentation agree.
7. Publish release notes that distinguish verified results from expected or
   untested behavior.

## Release notes

Include:

- installer and launcher changes;
- supported or changed platform/backend/model choices;
- security and privacy impact;
- migration, rollback, and known limitations;
- exact local validation performed and checks not run;
- relevant upstream revisions or model repository paths when known.

Do not bundle third-party model weights, credentials, user workflows, or local
runtime state into a source release. The repository MIT license applies to the
project-authored source, not automatically to downloaded dependencies or
models.

## Rollback

Preserve the previous release and its notes. If a release is unsafe or unusable,
mark it clearly in the GitHub release description, publish a corrected version,
and document the safest recovery path. Avoid rewriting a published tag to point
at different code because that makes provenance and rollback auditing harder.
