#!/usr/bin/env bash
install_packages() {
  local -a packages hardware
  mapfile -t packages < <(read_manifest "$ROOT/install/packages")
  mapfile -t hardware < <(hardware_packages)
  log 'Official packages: full upgrade and --needed installation'
  sudo pacman -Syu --needed -- "${packages[@]}" "${hardware[@]}"
}

# Cache build identity plus the installed version, so interrupted builds retry
# and a later removed/replaced package is not accidentally skipped.
build_package() (
  set -euo pipefail
  local name=$1 recipe=$2 upstream=${3:--} identity stamp work installed
  local ble_contrib_rev=d2109203480a7dfe1dead5f5f8f9f15a9146c90d
  stamp="$STATE/builds/$name"
  mkdir -p "$STATE/builds"
  identity="$recipe:$upstream"
  if [[ $name == oxwm-git ]]; then
    identity+=":$(sha256sum "$ROOT"/config/oxwm-patches/*.patch | sha256sum | cut -d ' ' -f1)"
  elif [[ $name == blesh-git ]]; then
    identity+=":$ble_contrib_rev"
  fi
  installed=$(pacman -Q "$name" 2>/dev/null || true)
  if [[ -n $installed && -f $stamp ]] && [[ $(cat "$stamp") == "$identity $installed" ]]; then
    printf 'Unchanged package build: %s\n' "$name"
    return
  fi
  work=$(mktemp -d)
  trap 'rm -rf -- "$work"' EXIT
  if [[ $name == st-minarch ]]; then
    cp -a "$ROOT/config/st/." "$work/"
  else
    git clone --quiet "https://aur.archlinux.org/$name.git" "$work/aur"
    git -C "$work/aur" checkout --quiet --detach "$recipe"
    cp -a "$work/aur/." "$work/"
    rm -rf "$work/aur" "$work/.git"
    if [[ $name == oxwm-git ]]; then
      # Pin the VCS source while retaining the reviewed AUR build recipe.
      sed -i "s|https://github.com/tonybanters/oxwm.git\"|https://github.com/tonybanters/oxwm.git#commit=$upstream\"|" "$work/PKGBUILD"
      grep -Fq "#commit=$upstream" "$work/PKGBUILD" || die 'OXWM source pin failed'
      cp "$ROOT/config/oxwm-patches/0001-microphone-keysym.patch" "$work/microphone.patch"
      cp "$ROOT/config/oxwm-patches/0002-unique-mirrored-screens.patch" "$work/unique-screens.patch"
      cat >> "$work/PKGBUILD" <<'PREPARE'
prepare() {
    patch -d "$srcdir/oxwm" -p1 < "$startdir/microphone.patch"
    patch -d "$srcdir/oxwm" -p1 < "$startdir/unique-screens.patch"
}
PREPARE
    elif [[ $name == blesh-git ]]; then
      # Pin both VCS sources. The contrib revision is the submodule recorded by
      # the reviewed ble.sh source commit.
      cat >> "$work/PKGBUILD" <<SOURCES
source[0]="git+https://github.com/akinomyoga/ble.sh#commit=$upstream"
source[1]="git+https://github.com/akinomyoga/blesh-contrib#commit=$ble_contrib_rev"
SOURCES
    fi
  fi
  cd "$work"
  makepkg --syncdeps --cleanbuild --clean
  local -a archives=()
  mapfile -t archives < <(makepkg --packagelist)
  ((${#archives[@]})) || die "No package produced for $name"
  sudo pacman -U --needed -- "${archives[@]}"
  installed=$(pacman -Q "$name")
  printf '%s %s\n' "$identity" "$installed" > "$stamp"
)

install_local_packages() {
  local name recipe upstream identity entry
  local -a entries
  # Finish reading the manifest before builds run; prompts retain caller stdin.
  mapfile -t entries < <(read_manifest "$ROOT/install/packages-aur")
  for entry in "${entries[@]}"; do
    read -r name recipe upstream <<< "$entry"
    log "Reviewed AUR build: $name"
    build_package "$name" "$recipe" "$upstream"
  done
  identity=$(sha256sum "$ROOT/config/st/PKGBUILD" "$ROOT/config/st/config.h" \
    "$ROOT/config/st/0001-scrollback-and-urls.patch" | sha256sum | cut -d ' ' -f1)
  log 'Local patched st build'
  build_package st-minarch "$identity"
}
