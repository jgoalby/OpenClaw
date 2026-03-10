#!/usr/bin/env bash
set -euo pipefail

bootstrap_confirm() {
  local prompt="$1"

  if command -v gum >/dev/null 2>&1; then
    gum confirm "$prompt"
  else
    local answer
    printf '%s [y/N]: ' "$prompt" >&2
    read -r answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
  fi
}

ensure_runtime_dependencies() {
  local mode="${1:-prompt}"
  local missing=()

  have_cmd just || missing+=("just")
  have_cmd gum || missing+=("gum")

  if ((${#missing[@]} == 0)); then
    return 0
  fi

  case "$mode" in
    auto)
      install_runtime_dependencies "${missing[@]}"
      ;;
    never)
      die "Missing runtime dependencies: ${missing[*]}"
      ;;
    prompt)
      if bootstrap_confirm "Install missing dependencies: ${missing[*]}?"; then
        install_runtime_dependencies "${missing[@]}"
      else
        die "Missing runtime dependencies: ${missing[*]}"
      fi
      ;;
    *)
      die "Unknown install mode: $mode"
      ;;
  esac
}

install_runtime_dependencies() {
  local packages=("$@")

  require_apt
  ui_status "Installing runtime dependencies: ${packages[*]}"
  run_root apt-get update
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

install_host_packages() {
  local packages=(
    systemd-container
    debootstrap
    curl
    git
    nano
    just
    gum
    sudo
    ca-certificates
  )

  require_apt
  ui_spin "Installing host packages" run_root apt-get update
  ui_spin "Installing host packages" run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

write_nspawn_config() {
  local machine="$1"
  local hostname="$2"
  local file
  file="$(nspawn_file "$machine")"

  run_root mkdir -p "$CLAWCTL_NSPAWN_DIR"
  run_root tee "$file" >/dev/null <<EOF
[Exec]
Boot=yes
Hostname=${hostname}

[Network]
VirtualEthernet=yes

[Link]
RequiredForOnline=no
EOF
}

configure_ping_support() {
  run_root tee "$CLAWCTL_PING_SYSCTL_FILE" >/dev/null <<'EOF'
net.ipv4.ping_group_range = 0 2147483647
EOF
  ui_spin "Applying sysctl settings" run_root sysctl --system >/dev/null
}

host_init() {
  ui_header "Host setup"
  install_host_packages
  run_root mkdir -p "$CLAWCTL_NSPAWN_DIR"
  write_nspawn_config "$CLAWCTL_BASE_MACHINE" "$CLAWCTL_DEFAULT_MACHINE"
  configure_ping_support
  ui_status "Host setup complete."
}

machine_exec_root() {
  local machine="$1"
  local command="$2"

  run_root systemd-run \
    --quiet \
    --wait \
    --collect \
    --pipe \
    --service-type=exec \
    --machine="$machine" \
    /bin/bash -lc "$command"
}

machine_exec_user() {
  local machine="$1"
  local user="$2"
  local command="$3"
  local home_dir="/home/${user}"

  run_root systemd-run \
    --quiet \
    --wait \
    --collect \
    --pipe \
    --service-type=exec \
    --machine="$machine" \
    --uid="$user" \
    --setenv="HOME=${home_dir}" \
    --setenv="USER=${user}" \
    --setenv="LOGNAME=${user}" \
    --working-directory="$home_dir" \
    /bin/bash -lc "$command"
}

start_machine() {
  local machine="$1"
  validate_machine_name "$machine"
  ensure_machine_exists "$machine"

  if machine_is_running "$machine"; then
    ui_note "Machine already running: $machine"
    return 0
  fi

  ui_spin "Starting ${machine}" run_root machinectl start "$machine"
  ui_status "Started ${machine}."
}

stop_machine() {
  local machine="$1"
  validate_machine_name "$machine"
  ensure_machine_exists "$machine"

  if ! machine_is_running "$machine"; then
    ui_note "Machine already stopped: $machine"
    return 0
  fi

  ui_spin "Stopping ${machine}" run_root machinectl stop "$machine"
  ui_status "Stopped ${machine}."
}

write_resolv_conf() {
  local machine="$1"
  local file
  file="$(machine_root "$machine")/etc/resolv.conf"

  run_root mkdir -p "$(dirname "$file")"
  run_root tee "$file" >/dev/null <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
}

set_machine_hostname_files() {
  local machine="$1"
  local hostname="$2"
  local root
  root="$(machine_root "$machine")"

  run_root tee "${root}/etc/hostname" >/dev/null <<EOF
${hostname}
EOF

  run_root tee "${root}/etc/hosts" >/dev/null <<EOF
127.0.0.1 localhost
127.0.1.1 ${hostname}

::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
}

create_base_container() {
  ui_header "Base container"
  ensure_machine_missing "$CLAWCTL_BASE_MACHINE"
  require_cmd debootstrap

  run_root mkdir -p "$CLAWCTL_MACHINE_ROOT_BASE"

  ui_spin "Bootstrapping ${CLAWCTL_BASE_MACHINE} (${CLAWCTL_UBUNTU_RELEASE})" \
    run_root debootstrap \
      --include=dbus,systemd,systemd-sysv \
      "$CLAWCTL_UBUNTU_RELEASE" \
      "$(machine_root "$CLAWCTL_BASE_MACHINE")" \
      "$CLAWCTL_UBUNTU_MIRROR"

  write_resolv_conf "$CLAWCTL_BASE_MACHINE"
  write_nspawn_config "$CLAWCTL_BASE_MACHINE" "$CLAWCTL_DEFAULT_MACHINE"
  set_machine_hostname_files "$CLAWCTL_BASE_MACHINE" "$CLAWCTL_DEFAULT_MACHINE"

  start_machine "$CLAWCTL_BASE_MACHINE"

  ui_spin "Installing baseline packages in ${CLAWCTL_BASE_MACHINE}" \
    machine_exec_root "$CLAWCTL_BASE_MACHINE" \
    "apt-get update && env DEBIAN_FRONTEND=noninteractive apt-get install -y sudo curl git nano ca-certificates less procps iproute2 iputils-ping"

  ui_spin "Creating ${CLAWCTL_DEFAULT_USER} in ${CLAWCTL_BASE_MACHINE}" \
    machine_exec_root "$CLAWCTL_BASE_MACHINE" \
    "id -u '${CLAWCTL_DEFAULT_USER}' >/dev/null 2>&1 || useradd -m -s /bin/bash '${CLAWCTL_DEFAULT_USER}'"

  ui_spin "Setting password and sudo access for ${CLAWCTL_DEFAULT_USER}" \
    machine_exec_root "$CLAWCTL_BASE_MACHINE" \
    "echo '${CLAWCTL_DEFAULT_USER}:${CLAWCTL_DEFAULT_PASSWORD}' | chpasswd && usermod -aG sudo '${CLAWCTL_DEFAULT_USER}'"

  stop_machine "$CLAWCTL_BASE_MACHINE"
  ui_status "Base container ready: ${CLAWCTL_BASE_MACHINE}"
}

create_instance() {
  local machine="$1"
  validate_machine_name "$machine"
  ensure_base_exists
  ensure_machine_missing "$machine"

  if machine_is_running "$CLAWCTL_BASE_MACHINE"; then
    ui_warn "Stopping base machine before cloning."
    stop_machine "$CLAWCTL_BASE_MACHINE"
  fi

  ui_spin "Cloning ${CLAWCTL_BASE_MACHINE} to ${machine}" \
    run_root cp -a "$(machine_root "$CLAWCTL_BASE_MACHINE")" "$(machine_root "$machine")"

  write_nspawn_config "$machine" "$machine"
  set_machine_hostname_files "$machine" "$machine"
  ui_status "Created machine: ${machine}"
}

open_shell() {
  local machine="$1"
  local user="$2"
  validate_machine_name "$machine"
  ensure_machine_exists "$machine"
  start_machine "$machine"
  exec run_root machinectl shell "${user}@${machine}"
}

exec_in_machine() {
  local machine="$1"
  local command="$2"
  validate_machine_name "$machine"
  ensure_machine_exists "$machine"
  start_machine "$machine"
  machine_exec_user "$machine" "$CLAWCTL_DEFAULT_USER" "$command"
}

backup_instance() {
  local machine="$1"
  local backup
  backup="$(backup_name "$machine")"

  validate_machine_name "$machine"
  ensure_machine_exists "$machine"

  if machine_exists "$backup"; then
    die "Backup already exists: $backup"
  fi

  if machine_is_running "$machine"; then
    ui_warn "Stopping ${machine} before backup."
    stop_machine "$machine"
  fi

  ui_spin "Backing up ${machine} to ${backup}" \
    run_root cp -a "$(machine_root "$machine")" "$(machine_root "$backup")"

  ui_status "Backup created: ${backup}"
}

destroy_instance_internal() {
  local machine="$1"

  if machine_is_running "$machine"; then
    stop_machine "$machine"
  fi

  run_root rm -rf "$(machine_root "$machine")"
  run_root rm -f "$(nspawn_file "$machine")"
}

destroy_instance() {
  local machine="$1"
  local mode="${2:-prompt}"

  validate_machine_name "$machine"
  ensure_machine_exists "$machine"

  [[ "$machine" != "$CLAWCTL_BASE_MACHINE" ]] || die "Refusing to destroy the base machine via destroy. Remove it manually if you really intend to."

  if [[ "$mode" != "force" ]]; then
    ui_confirm "Destroy ${machine}? This deletes $(machine_root "$machine")" || die "Cancelled."
  fi

  ui_spin "Destroying ${machine}" destroy_instance_internal "$machine"
  ui_status "Destroyed ${machine}."
}

restore_instance() {
  local machine="$1"
  local backup
  backup="$(backup_name "$machine")"

  validate_machine_name "$machine"
  machine_exists "$backup" || die "Backup not found: $backup"

  if machine_exists "$machine"; then
    ui_confirm "Restore ${machine} from ${backup}? Current machine data will be replaced." || die "Cancelled."
    destroy_instance_internal "$machine"
  fi

  ui_spin "Restoring ${machine} from ${backup}" \
    run_root cp -a "$(machine_root "$backup")" "$(machine_root "$machine")"

  write_nspawn_config "$machine" "$machine"
  set_machine_hostname_files "$machine" "$machine"
  ui_status "Restored ${machine} from ${backup}."
}

list_machines_and_images() {
  local temp_file
  temp_file="$(mktemp)"

  {
    printf 'Machines\n'
    printf '========\n'
    run_root machinectl list || true
    printf '\nImages\n'
    printf '======\n'
    run_root machinectl list-images || true
  } > "$temp_file"

  ui_page_file "$temp_file"
  rm -f "$temp_file"
}

show_machine_logs() {
  local machine="$1"
  local temp_file

  validate_machine_name "$machine"
  ensure_machine_exists "$machine"

  temp_file="$(mktemp)"
  run_root journalctl -M "$machine" -n 200 -e > "$temp_file"
  ui_page_file "$temp_file"
  rm -f "$temp_file"
}
