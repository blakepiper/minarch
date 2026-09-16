#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v zig >/dev/null || { echo 'Install zig and OXWM build dependencies first.' >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
revision=$(awk '$1 == "oxwm-git" {print $3}' "$root/install/packages-aur")
git -C "$work" init -q
git -C "$work" fetch --quiet --depth 1 https://github.com/tonybanters/oxwm.git "$revision"
git -C "$work" checkout --quiet --detach FETCH_HEAD
patch -d "$work" -p1 < "$root/config/oxwm-patches/0001-microphone-keysym.patch"
cp -a "$root/config/oxwm" "$work/minarch-config"
cat "$root/test/oxwm-config.zig" >> "$work/tests/lua_config_tests.zig"
cd "$work"
zig build -Doptimize=ReleaseSmall
zig build test -Doptimize=ReleaseSmall
zig-out/bin/oxwm --validate minarch-config/config.lua
echo 'PASS: upstream tests, real Minarch binding parser checks, and config validator'
