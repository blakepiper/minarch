#!/usr/bin/env bash
install_system() {
  local file unit
  log 'System configuration (existing differences are preserved by default)'
  for file in "$ROOT"/etc/X11/xorg.conf.d/*.conf; do
    install_config "$file" "/etc/X11/xorg.conf.d/$(basename "$file")" system
  done
  install_config "$ROOT/etc/udev/rules.d/99-minarch-mouse.rules" /etc/udev/rules.d/99-minarch-mouse.rules system
  sudo udevadm control --reload
  # Input rules apply on next boot/replug; do not disrupt a live input session.
  install_config "$ROOT/etc/firefox/policies/policies.json" /etc/firefox/policies/policies.json system
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
