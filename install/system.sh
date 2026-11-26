#!/usr/bin/env bash
check_greetd_conflicts() {
  local display_manager
  display_manager=$(systemctl show --property=Id --value display-manager.service 2>/dev/null) || true
  case $display_manager in
    ''|display-manager.service|greetd.service) ;;
    *) die "Display manager already configured: $display_manager. Disable it before enabling greetd." ;;
  esac
}

install_greetd() {
  local config=/etc/greetd/minarch.toml
  local dropin=/etc/systemd/system/greetd.service.d/50-minarch.conf
  log 'Enable Minarch password login at boot'
  install_config "$ROOT/etc/greetd/minarch.toml" "$config" system
  install_config "$ROOT/etc/systemd/system/greetd.service.d/50-minarch.conf" "$dropin" system
  if ! sudo cmp -s "$ROOT/etc/greetd/minarch.toml" "$config" ||
     ! sudo cmp -s "$ROOT/etc/systemd/system/greetd.service.d/50-minarch.conf" "$dropin"; then
    die 'Minarch login configuration differs. Review the preserved files before enabling greetd.'
  fi
  # Enable for the next boot without interrupting the current TTY or X session.
  sudo systemctl enable greetd.service
  sudo systemctl set-default graphical.target
}

install_system() {
  local file unit
  log 'System configuration (existing differences are preserved by default)'
  for file in "$ROOT"/etc/X11/xorg.conf.d/*.conf; do
    install_config "$file" "/etc/X11/xorg.conf.d/$(basename "$file")" system
  done
  install_config "$ROOT/etc/udev/rules.d/99-minarch-mouse.rules" /etc/udev/rules.d/99-minarch-mouse.rules system
  sudo udevadm control --reload
  # Input rules apply on next boot/replug; do not disrupt a live input session.
  if [[ ${REPLACE_CONFIG:-false} != true ]]; then
    upgrade_shipped_file "$ROOT/etc/firefox/policies/policies.json" \
      /etc/firefox/policies/policies.json \
      3fb0f78cac6f0e95e7faf679d17dd233f72382b0533bf08ee2e7382a89762dcc system
    upgrade_shipped_file "$ROOT/etc/firefox/policies/policies.json" \
      /etc/firefox/policies/policies.json \
      8090e11ae73dc9ee1369731db123c73392cbc30c258d469b74b1b01ed73460cf system
    upgrade_shipped_file "$ROOT/etc/firefox/policies/policies.json" \
      /etc/firefox/policies/policies.json \
      d1a6f0a68b3b2f9a7a934980940ec084c92812b47fd5d902327dc525c74a926b system
  fi
  install_config "$ROOT/etc/firefox/policies/policies.json" /etc/firefox/policies/policies.json system
  install_config "$ROOT/etc/fonts/conf.d/52-minarch-fonts.conf" /etc/fonts/conf.d/52-minarch-fonts.conf system
  install_config "$ROOT/etc/systemd/system-sleep/minarch-unlock" /usr/lib/systemd/system-sleep/minarch-unlock system
  # Keep manual pages available without periodic index maintenance.
  sudo systemctl mask --now man-db.timer
  # Only enable periodic discard if a device advertises discard support.
  if lsblk -dnbo DISC-MAX | awk '$1+0 > 0 {found=1} END {exit !found}'; then
    sudo systemctl enable --now fstrim.timer
  else
    printf 'No discard-capable device detected; fstrim.timer unchanged.\n'
  fi
  log 'Existing services: report only; do not remove user-owned software'
  for unit in NetworkManager systemd-networkd dhcpcd iwd bluetooth cups avahi-daemon ModemManager display-manager; do
    printf '%s: ' "$unit"
    systemctl is-enabled "$unit.service" 2>/dev/null || true
  done
  for file in bluez bluez-utils blueman; do
    if pacman -Q "$file" 2>/dev/null; then
      printf 'Pre-existing Bluetooth package retained: %s\n' "$file"
    fi
  done
  printf 'Networking ownership is unchanged. No network manager or sshd enabled.\n'
  printf 'Microcode packages are installed when appropriate; Minarch does not edit boot configuration.\n'
}
