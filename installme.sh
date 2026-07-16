#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
printf '%s\n' 'installme.sh is a compatibility wrapper. Prefer install.sh for new automation.' >&2
exec "${script_dir}/install.sh" "$@"
