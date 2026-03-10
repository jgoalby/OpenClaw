#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="clawctl"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$PWD}")" && pwd)"
INSTALL_ROOT="${CLAWCTL_INSTALL_ROOT:-${HOME}/.local/share/${PROJECT_NAME}}"
BIN_DIR="${CLAWCTL_BIN_DIR:-${HOME}/.local/bin}"
BIN_LINK="${CLAWCTL_BIN_LINK:-${BIN_DIR}/${PROJECT_NAME}}"
CLAWCTL_REPO_URL="${CLAWCTL_REPO_URL:-https://github.com/jgoalby/OpenClaw.git}"
CLAWCTL_REF="${CLAWCTL_REF:-main}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

is_apt_system() {
  have_cmd apt-get
}

run_root() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

local_source_available() {
  [[ -f "${SOURCE_DIR}/bin/clawctl" ]] &&
  [[ -f "${SOURCE_DIR}/justfile" ]] &&
  [[ -d "${SOURCE_DIR}/lib" ]]
}

install_packages() {
  local packages=("$@")

  if ((${#packages[@]} == 0)); then
    return 0
  fi

  if ! is_apt_system; then
    printf 'Missing packages: %s\n' "${packages[*]}" >&2
    printf 'apt-get is not available; install them manually.\n' >&2
    return 1
  fi

  run_root apt-get update
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

ensure_command() {
  local cmd="$1"
  shift
  local packages=("$@")

  if have_cmd "$cmd"; then
    return 0
  fi

  printf 'Installing missing dependency: %s\n' "$cmd"
  install_packages "${packages[@]}"
}

prepare_bin_link() {
  mkdir -p "$BIN_DIR"
  chmod +x "${INSTALL_ROOT}/install.sh" "${INSTALL_ROOT}/bin/clawctl"
  ln -sfn "${INSTALL_ROOT}/bin/clawctl" "$BIN_LINK"
}

install_tree_from_local_source() {
  mkdir -p "$INSTALL_ROOT" "$BIN_DIR"

  rm -rf "${INSTALL_ROOT}/bin" "${INSTALL_ROOT}/lib"
  rm -f "${INSTALL_ROOT}/README.md" "${INSTALL_ROOT}/install.sh" "${INSTALL_ROOT}/justfile" "${INSTALL_ROOT}/.gitignore"

  cp "${SOURCE_DIR}/README.md" "${INSTALL_ROOT}/README.md"
  cp "${SOURCE_DIR}/install.sh" "${INSTALL_ROOT}/install.sh"
  cp "${SOURCE_DIR}/justfile" "${INSTALL_ROOT}/justfile"
  cp "${SOURCE_DIR}/.gitignore" "${INSTALL_ROOT}/.gitignore"
  cp -R "${SOURCE_DIR}/bin" "${INSTALL_ROOT}/bin"
  cp -R "${SOURCE_DIR}/lib" "${INSTALL_ROOT}/lib"
}

install_tree_from_git() {
  mkdir -p "$(dirname "$INSTALL_ROOT")"

  if [[ -d "${INSTALL_ROOT}/.git" ]]; then
    printf 'Updating existing install from %s (%s)\n' "$CLAWCTL_REPO_URL" "$CLAWCTL_REF"
    git -C "$INSTALL_ROOT" remote set-url origin "$CLAWCTL_REPO_URL"
    git -C "$INSTALL_ROOT" fetch --depth 1 origin "$CLAWCTL_REF"
    git -C "$INSTALL_ROOT" checkout --force FETCH_HEAD
  else
    rm -rf "$INSTALL_ROOT"
    printf 'Cloning %s into %s\n' "$CLAWCTL_REPO_URL" "$INSTALL_ROOT"
    git clone "$CLAWCTL_REPO_URL" "$INSTALL_ROOT"
    git -C "$INSTALL_ROOT" fetch --depth 1 origin "$CLAWCTL_REF"
    git -C "$INSTALL_ROOT" checkout --force FETCH_HEAD
  fi
}

detect_shell_config() {
  case "${SHELL##*/}" in
    bash)
      [[ -f "$HOME/.bashrc" ]] && echo "$HOME/.bashrc" || echo "$HOME/.bash_profile"
      ;;
    zsh)
      echo "$HOME/.zshrc"
      ;;
    fish)
      echo "$HOME/.config/fish/config.fish"
      ;;
    *)
      echo "$HOME/.profile"
      ;;
  esac
}

ensure_local_bin_in_path() {
  local BIN_DIR="$HOME/.local/bin"

  if echo "$PATH" | grep -q "$BIN_DIR"; then
    return
  fi

  local CONFIG
  CONFIG="$(detect_shell_config)"

  echo
  echo "Adding $BIN_DIR to PATH in $CONFIG"

  mkdir -p "$BIN_DIR"

  if ! grep -q ".local/bin" "$CONFIG" 2>/dev/null; then
    echo '' >> "$CONFIG"
    echo '# Added by clawctl installer' >> "$CONFIG"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CONFIG"

		echo
		echo "Run this to refresh your shell:"
		echo "source $CONFIG"
  fi
}

install_gum() {
  if command -v gum >/dev/null 2>&1; then
    return
  fi

  local version="0.17.0"
  local arch

  case "$(uname -m)" in
    x86_64) arch="x86_64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      return 1
      ;;
  esac

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  curl -fsSL \
    "https://github.com/charmbracelet/gum/releases/download/v${version}/gum_${version}_Linux_${arch}.tar.gz" \
    -o "$tmp_dir/gum.tar.gz"

  tar -xzf "$tmp_dir/gum.tar.gz" -C "$tmp_dir"
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp_dir/gum" "$HOME/.local/bin/gum"
}

main() {
  ensure_command git git
  ensure_command curl curl

  if ! have_cmd just; then
    printf 'Attempting to install missing dependency: just\n'
    install_packages just || true
  fi

  if ! have_cmd gum; then
    printf 'Attempting to install missing dependency: gummy\n'
    install_gum
  fi

  if local_source_available; then
    printf 'Installing %s from local checkout: %s\n' "$PROJECT_NAME" "$SOURCE_DIR"
    install_tree_from_local_source
  else
    install_tree_from_git
  fi

  prepare_bin_link
  ensure_local_bin_in_path

  cat <<EOF
Installed ${PROJECT_NAME} to:
  ${INSTALL_ROOT}

Symlinked launcher:
  ${BIN_LINK}

Next steps:
  1. Ensure ~/.local/bin is in your PATH
  2. Run: clawctl help
  3. Run: clawctl host-init
  4. To update later, rerun the same install command
EOF
}

main "$@"
