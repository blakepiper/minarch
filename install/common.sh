#!/usr/bin/env bash
# Sourced by the installer and isolated tests.
log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
read_manifest() { sed 's/#.*//; /^[[:space:]]*$/d' "$1"; }

# Whole directories (notably nvim) are managed as a unit, including dotfiles.
# Scope is user or system; system operations use sudo, never run makepkg as root.
install_config() {
  local source=$1 target=$2 scope=${3:-user} parent stage backup
  local -a privilege=()
  [[ $scope != system ]] || privilege=(sudo)
  parent=$(dirname -- "$target")
  "${privilege[@]}" mkdir -p -- "$parent"
  if [[ -e $target || -L $target ]]; then
    if "${privilege[@]}" diff -qr -- "$source" "$target" >/dev/null 2>&1; then
      printf 'Unchanged: %s\n' "$target"
      return
    fi
    if [[ ${REPLACE_CONFIG:-false} != true ]]; then
      printf 'Preserved: %s (use --replace-config to back up and replace)\n' "$target"
      return
    fi
  fi
  stage=$("${privilege[@]}" mktemp -d "$parent/.minarch-stage.XXXXXXXX")
  if ! "${privilege[@]}" cp -a -- "$source" "$stage/content"; then
    "${privilege[@]}" rm -rf -- "$stage"
    die "Could not stage $target"
  fi
  if [[ $scope == system ]]; then
    sudo chown -R root:root "$stage/content"
  fi
  backup=''
  if [[ -e $target || -L $target ]]; then
    backup=$("${privilege[@]}" mktemp -d "$parent/$(basename -- "$target").backup.XXXXXXXX")
    "${privilege[@]}" mv -T -- "$target" "$backup/original"
    printf 'Backup: %s\n' "$backup/original"
  fi
  if ! "${privilege[@]}" mv -T -- "$stage/content" "$target"; then
    [[ -z $backup ]] || "${privilege[@]}" mv -T -- "$backup/original" "$target"
    "${privilege[@]}" rm -rf -- "$stage"
    die "Could not install $target"
  fi
  "${privilege[@]}" rmdir -- "$stage"
  printf 'Installed: %s\n' "$target"
}
