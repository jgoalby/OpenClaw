#!/usr/bin/env bash
set -euo pipefail

ui_has_gum() {
  command -v gum >/dev/null 2>&1
}

ui_header() {
  local message="$1"

  if ui_has_gum; then
    gum style \
      --foreground 39 \
      --border-foreground 45 \
      --border rounded \
      --padding "0 1" \
      --margin "1 0" \
      "$message"
  else
    printf '\n== %s ==\n' "$message"
  fi
}

ui_status() {
  local message="$1"

  if ui_has_gum; then
    gum style --foreground 42 "$message"
  else
    printf '%s\n' "$message"
  fi
}

ui_note() {
  local message="$1"

  if ui_has_gum; then
    gum style --foreground 250 "$message"
  else
    printf '%s\n' "$message"
  fi
}

ui_warn() {
  local message="$1"

  if ui_has_gum; then
    gum style --foreground 214 "$message" >&2
  else
    printf 'WARN: %s\n' "$message" >&2
  fi
}

ui_error() {
  local message="$1"

  if ui_has_gum; then
    gum style --foreground 196 "$message" >&2
  else
    printf 'ERROR: %s\n' "$message" >&2
  fi
}

ui_choose() {
  local header="$1"
  shift

  if ui_has_gum; then
    gum choose --header "$header" "$@"
  else
    printf 'gum is required for interactive menu mode.\n' >&2
    return 1
  fi
}

ui_input() {
  local prompt="$1"
  local placeholder="${2:-}"
  local initial_value="${3:-}"

  if ui_has_gum; then
    gum input \
      --prompt "${prompt}: " \
      --placeholder "$placeholder" \
      --value "$initial_value"
  else
    local value
    printf '%s: ' "$prompt" >&2
    read -r value
    printf '%s\n' "${value:-$initial_value}"
  fi
}

ui_confirm() {
  local prompt="$1"

  if ui_has_gum; then
    gum confirm "$prompt"
  else
    local answer
    printf '%s [y/N]: ' "$prompt" >&2
    read -r answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
  fi
}

ui_spin() {
  local title="$1"
  shift

  if ui_has_gum && ! declare -F "${1:-}" >/dev/null 2>&1; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    "$@"
  fi
}

ui_page_file() {
  local file="$1"

  if ui_has_gum && [[ -t 0 && -t 1 ]]; then
    gum pager < "$file"
  else
    cat "$file"
  fi
}

ui_page_text() {
  local text="$1"
  local temp_file
  temp_file="$(mktemp)"
  printf '%s\n' "$text" > "$temp_file"
  ui_page_file "$temp_file"
  rm -f "$temp_file"
}
