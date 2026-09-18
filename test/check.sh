#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
command -v shellcheck >/dev/null || { echo 'Install shellcheck to run repository checks.' >&2; exit 1; }
mapfile -t scripts < <(find install bin lib test tests scripts -type f \( -name '*.sh' -o -path 'bin/*' -o -path 'lib/clipmenu-text-probe/xsel' \) -print)
scripts+=(install.sh config/session/xinitrc config/bash/bashrc config/bash/bash_profile)
for script in "${scripts[@]}"; do bash -n "$script"; done
shellcheck -x "${scripts[@]}"
bash -n config/st/PKGBUILD
# makepkg supplies these metadata/environment variables by contract.
shellcheck -s bash -e SC2034,SC2154 config/st/PKGBUILD
python test/test_workstation.py
if command -v oxwm >/dev/null; then
  oxwm --validate "$PWD/config/oxwm/config.lua"
else
  echo 'SKIP: oxwm --validate (build/install the pinned OXWM first)'
fi
