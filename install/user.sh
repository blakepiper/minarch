#!/usr/bin/env bash
install_user() {
  local config_home=${XDG_CONFIG_HOME:-"$HOME/.config"} data_home=${XDG_DATA_HOME:-"$HOME/.local/share"} file
  log 'User configuration and helpers'
  # Upgrade the stock files shipped before display zoom and bar underlines.
  # Edited copies still follow the normal preservation and backup rules.
  if [[ ${REPLACE_CONFIG:-false} != true ]]; then
    upgrade_shipped_file "$ROOT/config/oxwm/config.lua" "$config_home/oxwm/config.lua" \
      6d91871191ad6f0ffce40559539d6443f7e81281b7c31f0ea81025af6cbec2df
    upgrade_shipped_file "$ROOT/lib/blix-settings/core.py" "$data_home/minarch/blix-settings/core.py" \
      08249da07775ece4975c5bfba6dc780659f29262fd85ad4c978e9795ea79d92b
    upgrade_shipped_file "$ROOT/bin/minarch-hardware-hotplug" "$HOME/.local/bin/minarch-hardware-hotplug" \
      e8d7cd46dd856cb0f76b04ea15f68f21a9b95ce66aeeb1ddee0b34522198b3fe
  fi
  install_config "$ROOT/config/minarch/hardware.conf" "$config_home/minarch/hardware.conf"
  install_config "$ROOT/config/oxwm" "$config_home/oxwm"
  install_config "$ROOT/config/picom/picom.conf" "$config_home/picom/picom.conf"
  install_config "$ROOT/config/fastfetch/config.jsonc" "$config_home/fastfetch/config.jsonc"
  install_config "$ROOT/config/mimeapps.list" "$config_home/mimeapps.list"
  install_config "$ROOT/config/session/xinitrc" "$HOME/.xinitrc"
  install_config "$ROOT/config/bash/bashrc" "$HOME/.bashrc"
  install_config "$ROOT/config/bash/bash_profile" "$HOME/.bash_profile"
  install_config "$ROOT/lib/blix-settings" "$data_home/minarch/blix-settings"
  for file in "$ROOT"/bin/*; do
    install_config "$file" "$HOME/.local/bin/$(basename "$file")"
  done
  install_config "$ROOT/lib/clipmenu-text-probe/xsel" "$HOME/.local/lib/clipmenu-text-probe/xsel"
  for file in "$ROOT"/config/systemd/user/*; do
    [[ -f $file ]] || continue
    install_config "$file" "$config_home/systemd/user/$(basename "$file")"
  done
  install_config "$ROOT/config/systemd/user/dunst.service.d/50-minarch-session.conf" \
    "$config_home/systemd/user/dunst.service.d/50-minarch-session.conf"
  mkdir -p "$HOME/Pictures/Screenshots"
  if [[ ${CLEANUP_RETIRED:-false} == true ]]; then
    cleanup_retired
  fi
}
