#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
replace=false
packages=true
for arg in "$@"; do
  case "$arg" in
    --replace-config) replace=true ;;
    --config-only) packages=false ;;
    --help)
      echo 'Usage: ./install.sh [--config-only] [--replace-config]'
      echo 'Installs editor packages and seeds config; existing config is preserved by default.'
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if "$packages"; then
  mapfile -t editor_packages < <(sed 's/#.*//; /^[[:space:]]*$/d' "$root/packages/neovim.txt")
  sudo pacman -S --needed -- "${editor_packages[@]}"
fi

config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
mkdir -p -- "$config_home"
target=$config_home/nvim
if [[ -e "$target" || -L "$target" ]]; then
  if ! "$replace"; then
    echo "Preserved existing $target (use --replace-config to back it up and replace it)."
    exit 0
  fi
fi

# Stage the complete copy before moving any existing configuration.
stage=$(mktemp -d "$config_home/.minarch-nvim.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
cp -a -- "$root/config/nvim" "$stage/nvim"
if [[ -e "$target" || -L "$target" ]]; then
  backup=$(mktemp -d "$config_home/nvim.backup.XXXXXXXX")
  mv -T -- "$target" "$backup/nvim"
  echo "Backed up existing configuration to $backup/nvim"
fi
if ! mv -T -- "$stage/nvim" "$target"; then
  if [[ -n ${backup:-} ]]; then
    mv -T -- "$backup/nvim" "$target"
  fi
  exit 1
fi
echo "Installed Blarchy Neovim configuration to $target"
