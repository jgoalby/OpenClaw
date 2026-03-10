#!/usr/bin/env bash
set -euo pipefail

show_openclaw_notes() {
  ui_note "OpenClaw onboarding is a manual step."
  ui_note "Config path: /home/${CLAWCTL_DEFAULT_USER}/.openclaw/openclaw.json"
  ui_note "If needed, change the profile from messaging to full in that file."
}

install_openclaw() {
  local machine="$1"
  validate_machine_name "$machine"
  ensure_machine_exists "$machine"
  start_machine "$machine"

  ui_header "OpenClaw install"
  ui_spin "Installing OpenClaw in ${machine}" \
    machine_exec_user "$machine" "$CLAWCTL_DEFAULT_USER" \
    "curl -fsSL https://openclaw.ai/install.sh | bash"

  show_openclaw_notes
  ui_status "OpenClaw installer completed in ${machine}."
}

run_openclaw_doctor() {
  local machine="$1"
  validate_machine_name "$machine"
  ensure_machine_exists "$machine"
  start_machine "$machine"

  ui_header "OpenClaw doctor"
  ui_spin "Running openclaw doctor --fix in ${machine}" \
    machine_exec_user "$machine" "$CLAWCTL_DEFAULT_USER" \
    "openclaw doctor --fix"

  show_openclaw_notes
  ui_status "OpenClaw doctor completed in ${machine}."
}

show_openclaw_config_path() {
  local machine="${1:-$CLAWCTL_DEFAULT_MACHINE}"
  validate_machine_name "$machine"
  printf '/home/%s/.openclaw/openclaw.json\n' "$CLAWCTL_DEFAULT_USER"
}
