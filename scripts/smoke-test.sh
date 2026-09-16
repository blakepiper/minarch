#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
headless=false
case ${1:-} in
  '') ;;
  --headless) headless=true ;;
  *) echo 'Usage: scripts/smoke-test.sh [--headless]' >&2; exit 2 ;;
esac
config=${XDG_CONFIG_HOME:-"$HOME/.config"}/nvim
for file in init.lua lua/config/lazy.lua lua/plugins/seafoam.lua lua/plugins/snacks.lua \
  colors/seafoam.lua lazy-lock.json lazyvim.json stylua.toml .neoconf.json LICENSE .gitignore; do
  [[ -f "$config/$file" ]] || { echo "FAIL: missing $config/$file" >&2; exit 1; }
done
echo "PASS: Blarchy Neovim configuration files exist in $config"
if ! "$headless"; then
  echo 'SKIP: headless startup (run with --headless; first run downloads plugins/tools).'
  exit 0
fi
command -v nvim >/dev/null || { echo 'FAIL: nvim is unavailable' >&2; exit 1; }
log=$(mktemp)
trap 'rm -f -- "$log"' EXIT
# NVIM_APPNAME must not redirect this check to a different config.
if ! env -u NVIM_APPNAME MINARCH_SMOKE_ROOT="$root" timeout 180s nvim --headless -i NONE \
  --cmd 'lua dofile(vim.env.MINARCH_SMOKE_ROOT .. "/tests/nvim-capture.lua")' \
  -c 'lua dofile(vim.env.MINARCH_SMOKE_ROOT .. "/tests/nvim-startup.lua")' >"$log" 2>&1; then
  cat "$log" >&2
  echo 'FAIL: Neovim startup failed or timed out (check network on first bootstrap).' >&2
  exit 1
fi
if grep -Eq 'Error detected while processing|E[0-9]+:|stack traceback:' "$log"; then
  cat "$log" >&2
  echo 'FAIL: Neovim reported an error despite exiting successfully.' >&2
  exit 1
fi
echo 'PASS: Neovim started headlessly with LazyVim and Seafoam'
