#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
command -v shellcheck >/dev/null || { echo 'Install shellcheck to run repository checks.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Install Python 3 to run repository checks.' >&2; exit 1; }
mapfile -t scripts < <(find install bin lib tests -type f \( -name '*.sh' -o -path 'bin/*' -o -path 'lib/clipmenu-text-probe/xsel' \) -print)
scripts+=(install.sh config/session/xinitrc config/bash/bashrc config/bash/bash_profile)
scripts+=(config/st/minarch-shell config/st/bashrc)
scripts+=(config/minarch/hardware.conf)
for script in "${scripts[@]}"; do bash -n "$script"; done
shellcheck -x "${scripts[@]}"
bash -n config/st/PKGBUILD
# makepkg supplies these metadata/environment variables by contract.
shellcheck -s bash -e SC2034,SC2154 config/st/PKGBUILD
# Optional unittest selectors (for example ConfigSafety) narrow the test run.
python3 tests/test_workstation.py "$@"
if command -v oxwm >/dev/null; then
  oxwm --validate "$PWD/config/oxwm/config.lua"
else
  echo 'SKIP: oxwm --validate (build/install the pinned OXWM first)'
fi
