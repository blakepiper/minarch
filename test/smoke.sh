#!/usr/bin/env bash
# pass/fail only report results; the compact check-and-report idiom is intentional.
# shellcheck disable=SC2015
set -uo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config=${XDG_CONFIG_HOME:-"$HOME/.config"}
failures=0
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
check_file() { [[ -f $1 ]] && pass "$1" || fail "Missing $1"; }
[[ -f /etc/arch-release ]] && pass Arch || fail 'Arch not detected'
for executable in Xorg startx oxwm st dmenu dmenu_run xfe firefox nvim tmux codex maim slop xclip \
  clipmenu clipmenud xss-lock xsecurelock picom fastfetch xkbcomp wpctl pipewire wireplumber playerctl git rg fd lazygit tree-sitter; do
  command -v "$executable" >/dev/null && pass "$executable" || fail "Missing $executable"
done
check_file "$HOME/.xinitrc"
grep -Eq '^exec oxwm[[:space:]]*$' "$HOME/.xinitrc" && pass 'xinit launches oxwm' || fail 'xinit must exec oxwm'
check_file "$config/oxwm/config.lua"
if command -v oxwm >/dev/null; then
  oxwm --validate "$config/oxwm/config.lua" && pass 'OXWM validation' || fail 'OXWM validation'
fi
for binding in 'spawn_terminal()' '"dmenu_run"' '"xfe"' '"firefox"' '"screenshot-region"' \
  '"clipboard-history"' '"minarch-lock"' '"control-menu"' 'oxwm.tag.view(i - 1)' 'oxwm.tag.move_to(i - 1)'; do
  grep -Fq "$binding" "$config/oxwm/config.lua" && pass "$binding" || fail "Missing binding: $binding"
done
for helper in dev screenshot-region control-menu clipboard-history minarch-lock minarch-brightness minarch-stats \
  minarch-hardware-hotplug oxwm-battery oxwm-cpu xsecurelock-without-picom; do
  file=$HOME/.local/bin/$helper
  [[ -x $file ]] && pass "$helper executable" || fail "$helper is not executable"
  bash -n "$file" && pass "$helper syntax" || fail "$helper syntax"
done
mkdir -p "$HOME/Pictures/Screenshots" && pass 'Screenshot directory' || fail 'Screenshot directory'
check_file "$config/tmux/tmux.conf"
check_file "$config/picom/picom.conf"
check_file "$config/xfe/xferc"
check_file "$config/fastfetch/config.jsonc"
check_file "$config/systemd/user/minarch-picom.service"
check_file "$config/systemd/user/minarch-hardware-hotplug.service"
[[ -x $HOME/.local/lib/clipmenu-text-probe/xsel ]] && pass 'Clipboard text probe executable' || fail 'Clipboard text probe missing'
grep -Fq 'set -g mouse on' "$config/tmux/tmux.conf" && pass 'tmux mouse' || fail 'tmux mouse'
if [[ -f ${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim/lua/lazy/init.lua ]]; then
  "$root/scripts/smoke-test.sh" --headless || fail 'Neovim headless startup'
else
  "$root/scripts/smoke-test.sh" || fail 'Neovim files'
  echo 'SKIP: Neovim bootstrap needs first-run downloads; run scripts/smoke-test.sh --headless explicitly.'
fi
if command -v codex >/dev/null; then codex --version && pass 'Codex version' || fail 'Codex version'; fi
# Repository policy checks distinguish user-owned services from Minarch choices.
if grep -Eq '^(bluez|bluez-utils|blueman|networkmanager|dhcpcd|iwd|sddm|gdm|lightdm|swaybg)$' "$root/install/packages"; then
  fail 'Unexpected service package in manifest'
else
  pass 'No competing network manager, Bluetooth, display manager, or wallpaper daemon added'
fi
for unit in NetworkManager systemd-networkd dhcpcd bluetooth display-manager; do
  printf 'Existing %s: ' "$unit"
  systemctl is-enabled "$unit.service" 2>/dev/null || true
done
# Do not fail merely because the user already owned one of these services.
if lsblk -dnbo DISC-MAX | awk '$1+0 > 0 {found=1} END {exit !found}'; then
  systemctl is-enabled --quiet fstrim.timer && pass fstrim.timer || fail 'fstrim.timer is not enabled on discard-capable storage'
else
  echo 'SKIP: no discard-capable storage; fstrim.timer need not be enabled'
fi
if [[ -n ${DISPLAY:-} ]]; then
  systemctl --user is-active --quiet minarch-session.target && pass 'Session services' || fail 'Session services not active'
else
  echo 'SKIP: live X clipboard, rendering, media keys, and lock/resume require an X session'
fi
printf '\nSmoke failures: %s\n' "$failures"
((failures == 0))
