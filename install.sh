#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=install/common.sh
source "$ROOT/install/common.sh"
REPLACE_CONFIG=false
CONFIG_ONLY=false
for arg in "$@"; do
  case $arg in
    --replace-config) REPLACE_CONFIG=true ;;
    --config-only) CONFIG_ONLY=true ;;
    --help)
      echo 'Usage: ./install.sh [--replace-config] [--config-only]'
      echo 'Existing differing configs are preserved unless --replace-config is used.'
      echo '--config-only seeds user files only, without packages, sudo, or system changes.'
      exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done
(( EUID != 0 )) || die 'Run as a normal sudo-capable user, not root.'
STATE=${XDG_STATE_HOME:-"$HOME/.local/state"}/minarch
mkdir -p "$STATE"
exec 9>"$STATE/install.lock"
flock -n 9 || die 'Another Minarch installation is running.'
trap 'printf "ERROR: stage failed at line %s; fix the error above and rerun.\n" "$LINENO" >&2' ERR
# shellcheck source=install/user.sh
source "$ROOT/install/user.sh"
if "$CONFIG_ONLY"; then
  install_user
  exit 0
fi
[[ -f /etc/arch-release ]] || die 'Minarch requires an existing Arch Linux installation.'
[[ $(uname -m) == x86_64 ]] || die 'Minarch v1 supports x86_64.'
command -v sudo >/dev/null || die 'Install sudo and grant this user access first.'
sudo -v || die 'Working sudo access is required.'
command -v git >/dev/null || die 'Install git first.'
log 'Checking HTTPS networking before package installation'
timeout 30s git ls-remote https://github.com/tonybanters/oxwm.git HEAD >/dev/null || die 'HTTPS networking failed; fix networking and retry.'
# shellcheck source=install/hardware.sh
source "$ROOT/install/hardware.sh"
# shellcheck source=install/packages.sh
source "$ROOT/install/packages.sh"
# shellcheck source=install/system.sh
source "$ROOT/install/system.sh"
install_packages
install_local_packages
install_system
install_user
log 'Validation'
oxwm --validate "${XDG_CONFIG_HOME:-$HOME/.config}/oxwm/config.lua"
codex --version
pacman -Q > "$STATE/packages-installed.txt"
printf '\nMinarch installed. Review preserved-file messages above, then reboot if the kernel changed.\n'
printf 'Log in on a TTY and run startx. Run ~/minarch/test/smoke.sh after installation.\n'
