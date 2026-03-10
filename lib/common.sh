#!/usr/bin/env bash
set -euo pipefail

CLAWCTL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAWCTL_ROOT="$(cd "${CLAWCTL_LIB_DIR}/.." && pwd)"
CLAWCTL_CONFIG_FILE="${CLAWCTL_CONFIG_FILE:-$HOME/.config/clawctl/config.env}"
CLAWCTL_MACHINE_ROOT_BASE="/var/lib/machines"
CLAWCTL_NSPAWN_DIR="/etc/systemd/nspawn"
CLAWCTL_PING_SYSCTL_FILE="/etc/sysctl.d/99-clawctl-ping.conf"

set_default_config() {
  : "${CLAWCTL_DEFAULT_USER:=clawdbot}"
  : "${CLAWCTL_DEFAULT_MACHINE:=openclaw}"
  : "${CLAWCTL_BASE_MACHINE:=openclaw-base}"
  : "${CLAWCTL_UBUNTU_RELEASE:=noble}"
  : "${CLAWCTL_UBUNTU_MIRROR:=http://archive.ubuntu.com/ubuntu/}"
  # Placeholder only. Override this in ~/.config/clawctl/config.env on real systems.
  : "${CLAWCTL_DEFAULT_PASSWORD:=change-me-now}"
}

load_user_config() {
  set_default_config

  if [[ -f "$CLAWCTL_CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CLAWCTL_CONFIG_FILE"
  fi

  set_default_config
  export CLAWCTL_DEFAULT_USER CLAWCTL_DEFAULT_MACHINE CLAWCTL_BASE_MACHINE
  export CLAWCTL_UBUNTU_RELEASE CLAWCTL_UBUNTU_MIRROR CLAWCTL_DEFAULT_PASSWORD
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

is_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]]
}

run_root() {
  if is_root; then
    "$@"
  else
    sudo "$@"
  fi
}

die() {
  printf 'clawctl: %s\n' "$*" >&2
  exit 1
}

machine_root() {
  printf '%s/%s\n' "$CLAWCTL_MACHINE_ROOT_BASE" "$1"
}

nspawn_file() {
  printf '%s/%s.nspawn\n' "$CLAWCTL_NSPAWN_DIR" "$1"
}

backup_name() {
  printf '%s-backup\n' "$1"
}

validate_machine_name() {
  local name="$1"

  [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || die "Invalid machine name: $name"
}

machine_exists() {
  [[ -d "$(machine_root "$1")" ]]
}

machine_is_running() {
  machinectl show "$1" -p State --value 2>/dev/null | grep -qx 'running'
}

ensure_machine_exists() {
  local machine="$1"
  machine_exists "$machine" || die "Machine not found: $machine"
}

ensure_machine_missing() {
  local machine="$1"
  machine_exists "$machine" && die "Machine already exists: $machine"
}

ensure_base_exists() {
  machine_exists "$CLAWCTL_BASE_MACHINE" || die "Base machine not found: ${CLAWCTL_BASE_MACHINE}. Run: clawctl create-base"
}

require_apt() {
  have_cmd apt-get || die "apt-get is required on this host."
}

require_cmd() {
  local cmd="$1"
  have_cmd "$cmd" || die "Required command not found: $cmd"
}
