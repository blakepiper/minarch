#!/usr/bin/env bash
install_user() {
  local config_home=${XDG_CONFIG_HOME:-"$HOME/.config"} file
  log 'User configuration and helpers'
  install_config "$ROOT/config/nvim" "$config_home/nvim"
  install_config "$ROOT/config/oxwm" "$config_home/oxwm"
  install_config "$ROOT/config/picom/picom.conf" "$config_home/picom/picom.conf"
  install_config "$ROOT/config/fastfetch/config.jsonc" "$config_home/fastfetch/config.jsonc"
  install_config "$ROOT/config/xfe/xferc" "$config_home/xfe/xferc"
  install_config "$ROOT/config/tmux/tmux.conf" "$config_home/tmux/tmux.conf"
  install_config "$ROOT/config/mimeapps.list" "$config_home/mimeapps.list"
  install_config "$ROOT/config/session/xinitrc" "$HOME/.xinitrc"
  install_config "$ROOT/config/bash/bashrc" "$HOME/.bashrc"
  install_config "$ROOT/config/bash/bash_profile" "$HOME/.bash_profile"
  for file in "$ROOT"/bin/*; do
    install_config "$file" "$HOME/.local/bin/$(basename "$file")"
  done
  install_config "$ROOT/lib/clipmenu-text-probe/xsel" "$HOME/.local/lib/clipmenu-text-probe/xsel"
  for file in "$ROOT"/config/systemd/user/*; do
    install_config "$file" "$config_home/systemd/user/$(basename "$file")"
  done
  mkdir -p "$HOME/Pictures/Screenshots"
}
