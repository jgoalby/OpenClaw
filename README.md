# clawctl

`clawctl` is a terminal-first OpenClaw VPS and container management tool for Ubuntu/Debian hosts. It uses Bash for the implementation, `just` for task execution, and `gum` for the interactive UI.

The primary workflow is:

1. Prepare a fresh VPS for `systemd-nspawn` containers.
2. Build an `openclaw-base` machine with baseline packages and a ready `clawdbot` user.
3. Clone named instances from that base.
4. Install OpenClaw inside an instance and run follow-up checks.

The project is intended to work well over SSH and to keep the public interface thin and predictable.

## Features

- Interactive menu mode with `gum` when you run `clawctl` with no arguments
- Direct subcommands for scripting and repeated operations
- Optional installation of missing `just` and `gum` dependencies
- Host preparation for `systemd-nspawn`
- Base container creation with `debootstrap noble`
- Instance clone/start/stop/shell/exec/backup/restore/destroy flows
- OpenClaw install and doctor helpers
- `journalctl -M` log access for running machines

## Install

From this repo checkout:

```bash
./install.sh
```

Remote install from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/jgoalby/OpenClaw/main/install.sh | bash
```

That command installs from `https://github.com/jgoalby/OpenClaw.git` and updates the existing checkout if you rerun it later.

This installs the project into:

- `~/.local/share/clawctl`
- `~/.local/bin/clawctl`

Make sure `~/.local/bin` is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Installer behavior:

- local checkout install copies the project files into `~/.local/share/clawctl`
- remote install clones the Git repo into `~/.local/share/clawctl`
- rerunning the same remote install command updates the existing checkout in place
- `CLAWCTL_REF` can still be overridden if you want to install a different branch or tag

## Dependency Behavior

Runtime dependencies:

- `bash`
- `just`
- `gum`
- `systemd-container`
- `debootstrap`
- `curl`
- `git`

When `bin/clawctl` starts, it checks for `just` and `gum`.

- If a dependency is missing, `clawctl` offers to install it on apt-based systems.
- Use `--install-deps` to install missing dependencies automatically.
- Use `--no-install` to fail immediately instead of prompting.

Examples:

```bash
clawctl --install-deps help
clawctl --no-install list
```

## Interactive Usage

Run without arguments to open the menu UI:

```bash
clawctl
```

Top-level sections:

- Host setup
- Base container
- Instances
- OpenClaw
- Logs / status
- Help
- Quit

The UI uses `gum choose`, `gum input`, `gum confirm`, `gum spin`, `gum style`, and `gum pager`.

## Direct Commands

Examples:

```bash
clawctl help
clawctl host-init
clawctl create-base
clawctl create openclaw
clawctl start openclaw
clawctl stop openclaw
clawctl shell openclaw
clawctl shell openclaw --root
clawctl exec openclaw 'openclaw status'
clawctl backup openclaw
clawctl restore openclaw
clawctl destroy openclaw --force
clawctl logs openclaw
clawctl doctor openclaw
clawctl openclaw-install openclaw
clawctl list
clawctl config-path openclaw
```

## Suggested Workflow

### Fresh VPS setup

```bash
clawctl host-init
```

This:

- installs required host packages
- creates `/etc/systemd/nspawn`
- writes a standard `.nspawn` config for `openclaw-base`
- enables container ping support with a sysctl drop-in

### Create the base container

```bash
clawctl create-base
```

This:

- bootstraps `openclaw-base` with Ubuntu `noble`
- writes `resolv.conf`
- starts the base container
- creates the `clawdbot` user
- sets a placeholder password
- adds the user to `sudo`
- installs baseline packages
- stops the base container again

### Create a working OpenClaw instance

```bash
clawctl create openclaw
clawctl start openclaw
clawctl openclaw-install openclaw
clawctl doctor openclaw
clawctl shell openclaw
```

OpenClaw onboarding is intentionally left manual. After install, open a shell in the machine and finish any first-run authentication steps yourself.

### Backup and restore

```bash
clawctl backup openclaw
clawctl restore openclaw
```

Backups are stored as machine roots under `/var/lib/machines/<name>-backup`.

## Configuration

The first version keeps configuration simple. Optional overrides can be placed in:

```bash
~/.config/clawctl/config.env
```

Supported variables:

```bash
CLAWCTL_DEFAULT_USER=clawdbot
CLAWCTL_DEFAULT_MACHINE=openclaw
CLAWCTL_BASE_MACHINE=openclaw-base
CLAWCTL_UBUNTU_RELEASE=noble
CLAWCTL_DEFAULT_PASSWORD=change-me-now
```

## OpenClaw Notes

- Installer command used inside the container:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

- Config path helper output points at:

```bash
/home/clawdbot/.openclaw/openclaw.json
```

- If you need the full profile, change the config profile from `messaging` to `full` in `~/.openclaw/openclaw.json`.
- `clawctl doctor <machine>` runs `openclaw doctor --fix` as the default user.

## Notes and Caveats

- Most operations require root. `clawctl` uses `sudo` automatically when needed.
- Normal deletion is done by removing `/var/lib/machines/<name>` directly. `machinectl remove` is intentionally not used.
- Backup directories are not auto-overwritten.
- The base container defaults to the internal hostname `openclaw`.
- Instance hostnames are set to the instance machine name.

## Project Structure

```text
.
├── README.md
├── install.sh
├── justfile
├── bin/
│   └── clawctl
└── lib/
    ├── common.sh
    ├── openclaw.sh
    ├── system.sh
    └── ui.sh
```
