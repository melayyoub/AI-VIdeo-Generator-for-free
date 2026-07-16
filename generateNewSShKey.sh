#!/usr/bin/env bash
set -euo pipefail

key_path="${CUSTOM_WAN_SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519}"
comment="${CUSTOM_WAN_SSH_KEY_COMMENT:-custom-wan}"

if [[ -e "${key_path}" || -e "${key_path}.pub" ]]; then
  printf 'Refusing to overwrite an existing SSH key: %s\n' "${key_path}" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "${key_path}")"
ssh-keygen -t ed25519 -C "${comment}" -f "${key_path}"
eval "$(ssh-agent -s)"
ssh-add "${key_path}"

printf '%s\n' 'Add this public key to your Git hosting account:'
cat -- "${key_path}.pub"
