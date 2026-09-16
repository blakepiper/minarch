#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
export XDG_CONFIG_HOME="$test_home/.config"
"$root/install.sh" --config-only
diff -r "$root/config/nvim" "$test_home/.config/nvim"
echo 'user content' > "$test_home/.config/nvim/init.lua"
"$root/install.sh" --config-only
[[ $(cat "$test_home/.config/nvim/init.lua") == 'user content' ]]
"$root/install.sh" --config-only --replace-config
diff -r "$root/config/nvim" "$test_home/.config/nvim"
backups=("$test_home"/.config/nvim.backup.*/nvim/init.lua)
[[ ${#backups[@]} == 1 && $(cat "${backups[0]}") == 'user content' ]]
"$root/scripts/smoke-test.sh"

# Respect XDG paths with spaces and preserve dangling links without following them.
export XDG_CONFIG_HOME="$test_home/custom config"
mkdir -p "$XDG_CONFIG_HOME"
ln -s "$test_home/missing" "$XDG_CONFIG_HOME/nvim"
"$root/install.sh" --config-only
[[ -L "$XDG_CONFIG_HOME/nvim" ]]
"$root/install.sh" --config-only --replace-config
diff -r "$root/config/nvim" "$XDG_CONFIG_HOME/nvim"
links=("$XDG_CONFIG_HOME"/nvim.backup.*/nvim)
[[ ${#links[@]} == 1 && -L ${links[0]} ]]
[[ $(readlink "${links[0]}") == "$test_home/missing" ]]
echo 'PASS: installer seeding, preservation, backup, symlinks, and XDG paths'
