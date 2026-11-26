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
  local oxwm_zig_version=0.16.0
  local oxwm_zig_sha256=70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00
  stamp="$STATE/builds/$name"
  mkdir -p "$STATE/builds"
  # Invalidate stamps written when --needed could skip changed same-version builds.
  identity="reinstall-v2:$recipe:$upstream"
  if [[ $name == oxwm-git ]]; then
    identity+=":zig-$oxwm_zig_version:$oxwm_zig_sha256"
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
      # The pinned source uses Zig 0.16 features removed in Zig 0.17.
      sed -i "/^makedepends=/s/'zig' //" "$work/PKGBUILD"
      cat >> "$work/PKGBUILD" <<TOOLCHAIN

source+=("https://ziglang.org/download/$oxwm_zig_version/zig-x86_64-linux-$oxwm_zig_version.tar.xz")
sha256sums+=("$oxwm_zig_sha256")

zig() {
    "\$srcdir/zig-x86_64-linux-$oxwm_zig_version/zig" "\$@"
}
TOOLCHAIN
      mkdir "$work/minarch-patches"
      cp "$ROOT"/config/oxwm-patches/*.patch "$work/minarch-patches/"
      cat >> "$work/PKGBUILD" <<'PREPARE'
prepare() {
    local patch_file
    for patch_file in "$startdir"/minarch-patches/*.patch; do
        patch -d "$srcdir/oxwm" -p1 < "$patch_file" || return
    done
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
  local package_list archive
  local -a archives=()
  package_list=$(makepkg --packagelist) || die "Could not list packages for $name"
  while IFS= read -r archive; do
    [[ -n $archive ]] || continue
    # makepkg can list a debug archive even when it found no debug symbols to package.
    if [[ ${archive##*/} == "$name-debug-"* && ! -e $archive ]]; then
      continue
    fi
    [[ -f $archive && -r $archive ]] || die "Missing or unreadable package: $archive"
    archives+=("$archive")
  done <<< "$package_list"
  ((${#archives[@]})) || die "No package produced for $name"
  # The identity check above already skips unchanged builds. Reinstall changed
  # artifacts even when their pkgver/pkgrel is identical to the installed one.
  sudo pacman -U -- "${archives[@]}"
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
    "$ROOT/config/st/minarch-shell" "$ROOT/config/st/bashrc" \
    "$ROOT/config/st/0001-scrollback-and-urls.patch" | sha256sum | cut -d ' ' -f1)
  log 'Local patched st build'
  build_package st-minarch "$identity"
}
