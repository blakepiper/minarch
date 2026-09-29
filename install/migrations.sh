#!/usr/bin/env bash
# Retire only explicitly listed, checksum-matched regular files. User edits,
# symlinks (including parent directories), and unknown versions stay untouched.
cleanup_retired() {
  local scope relative expected target_root target component current actual backup
  local -a components
  log 'Retired user files (recognized versions only)'
  while read -r scope relative expected; do
    case $scope in
      home) target_root=$HOME ;;
      config) target_root=${XDG_CONFIG_HOME:-$HOME/.config} ;;
      *) die "Invalid retired-file scope: $scope" ;;
    esac
    [[ $relative != /* && $expected =~ ^[a-f0-9]{64}(,[a-f0-9]{64})*$ ]] || die 'Invalid retired-file entry'
    IFS=/ read -r -a components <<< "$relative"
    target=$target_root/$relative
    if [[ -L $target_root ]]; then
      printf 'Preserved retired path (symlink root): %s\n' "$target"
      continue
    fi
    current=$target_root
    for component in "${components[@]}"; do
      [[ -n $component && $component != . && $component != .. ]] || die 'Unsafe retired-file path'
      current+=/$component
      if [[ -L $current ]]; then
        printf 'Preserved retired path (symlink): %s\n' "$target"
        continue 2
      fi
    done
    [[ -e $target ]] || continue
    if [[ ! -f $target ]]; then
      printf 'Preserved retired path (not a regular file): %s\n' "$target"
      continue
    fi
    actual=$(sha256sum -- "$target")
    actual=${actual%% *}
    if [[ ,$expected, != *",$actual,"* ]]; then
      printf 'Preserved retired file (modified or unknown version): %s\n' "$target"
      continue
    fi
    backup=$(mktemp -d "$(dirname -- "$target")/$(basename -- "$target").retired.XXXXXXXX")
    mv -T -- "$target" "$backup/original"
    printf 'Retired: %s (backup: %s/original)\n' "$target" "$backup"
  done < <(read_manifest "$ROOT/install/retired-files")
}
