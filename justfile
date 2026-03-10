set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()

@default:
    @just --justfile "{{root}}/justfile" --list

host-init:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; host_init

create-base:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; create_base_container

create machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; create_instance "{{machine}}"

start machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; start_machine "{{machine}}"

stop machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; stop_machine "{{machine}}"

shell-user machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; open_shell "{{machine}}" "$CLAWCTL_DEFAULT_USER"

shell-root machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; open_shell "{{machine}}" "root"

exec machine cmd:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; exec_in_machine "{{machine}}" "{{cmd}}"

backup machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; backup_instance "{{machine}}"

restore machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; restore_instance "{{machine}}"

destroy machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; destroy_instance "{{machine}}" "prompt"

destroy-force machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; destroy_instance "{{machine}}" "force"

logs machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; show_machine_logs "{{machine}}"

doctor machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; run_openclaw_doctor "{{machine}}"

openclaw-install machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; install_openclaw "{{machine}}"

config-path machine:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; show_openclaw_config_path "{{machine}}"

list:
    @source "{{root}}/lib/common.sh"; source "{{root}}/lib/ui.sh"; source "{{root}}/lib/system.sh"; source "{{root}}/lib/openclaw.sh"; load_user_config; list_machines_and_images
