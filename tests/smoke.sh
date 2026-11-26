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
for executable in Xorg startx oxwm st dmenu dmenu_run rofi thunar dunst notify-send firefox vim codex maim slop xclip \
  clipmenu clipmenud xss-lock xsecurelock picom gammastep fastfetch xkbcomp wpctl pipewire wireplumber playerctl git rg fd fc-match; do
  command -v "$executable" >/dev/null && pass "$executable" || fail "Missing $executable"
done
check_file "$HOME/.xinitrc"
check_file /usr/share/blesh/ble.sh
check_file /usr/share/minarch/bashrc
check_file /etc/fonts/conf.d/52-minarch-fonts.conf
if command -v fc-match >/dev/null; then
  for family in sans-serif serif monospace; do
    if [[ $(fc-match -f '%{family[0]}' "$family:lang=en") == 'JetBrainsMono Nerd Font' ]]; then
      pass "JetBrainsMono Nerd Font for $family"
    else
      fail "JetBrainsMono Nerd Font did not match $family"
    fi
  done
fi
[[ -x /usr/bin/minarch-shell ]] && pass 'st Bash/ble.sh launcher' || fail 'Missing st shell launcher'
grep -Eq '^exec oxwm[[:space:]]*$' "$HOME/.xinitrc" && pass 'xinit launches oxwm' || fail 'xinit must exec oxwm'
check_file "$config/oxwm/config.lua"
if command -v oxwm >/dev/null; then
  oxwm --validate "$config/oxwm/config.lua" && pass 'OXWM validation' || fail 'OXWM validation'
fi
for binding in 'spawn_terminal()' '"dmenu_run"' '"rofi -show drun' '"thunar"' '"firefox"' '"blix-settings"' 'screenshot-region' \
  'clipboard-history' 'minarch-lock' 'control-menu' 'oxwm.tag.view(i - 1)' 'oxwm.tag.move_to(i - 1)'; do
  grep -Fq "$binding" "$config/oxwm/config.lua" && pass "$binding" || fail "Missing binding: $binding"
done
for helper in screenshot-region control-menu clipboard-history minarch-lock minarch-brightness minarch-stats minarch-notify-failure \
  blix-settings blix-settings-apply oxwm-volume oxwm-brightness minarch-monitor-brightness \
  minarch-hardware-hotplug minarch-picom oxwm-watch-volume xsecurelock-without-picom; do
  file=$HOME/.local/bin/$helper
  [[ -x $file ]] && pass "$helper executable" || fail "$helper is not executable"
  bash -n "$file" && pass "$helper syntax" || fail "$helper syntax"
done
mkdir -p "$HOME/Pictures/Screenshots" && pass 'Screenshot directory' || fail 'Screenshot directory'
check_file "$config/picom/picom.conf"
check_file "$config/minarch/hardware.conf"
check_file "$config/systemd/user/dunst.service.d/50-minarch-session.conf"
grep -Fxq 'inode/directory=thunar.desktop' "$config/mimeapps.list" && pass 'Thunar folder handler' || fail 'Thunar folder handler missing'
check_file "$config/fastfetch/config.jsonc"
check_file "$config/systemd/user/minarch-picom.service"
check_file "$config/systemd/user/minarch-hardware-hotplug.service"
check_file "${XDG_DATA_HOME:-$HOME/.local/share}/minarch/blix-settings/main.py"
[[ -x $HOME/.local/lib/clipmenu-text-probe/xsel ]] && pass 'Clipboard text probe executable' || fail 'Clipboard text probe missing'
if command -v vim >/dev/null; then
  vim -N -u NONE -i NONE -n -es -c 'qa!' </dev/null && pass 'Vim startup' || fail 'Vim startup'
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
