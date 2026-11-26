#!/usr/bin/env bash
hardware_packages() {
  local sys_root=${1:-/sys} cpuinfo=${2:-/proc/cpuinfo}
  local vendor device class gpu_vendor gpu_device has_gpu=false
  vendor=$(awk -F ': ' '/vendor_id/ {print $2; exit}' "$cpuinfo")
  case $vendor in
    GenuineIntel) echo intel-ucode ;;
    AuthenticAMD) echo amd-ucode ;;
  esac
  for device in "$sys_root"/bus/pci/devices/*; do
    [[ -r $device/class && -r $device/vendor ]] || continue
    read -r class < "$device/class"
    [[ $class == 0x03* ]] || continue
    read -r gpu_vendor < "$device/vendor"
    case $gpu_vendor in
      0x8086)
        has_gpu=true
        gpu_device=''
        [[ ! -r $device/device ]] || read -r gpu_device < "$device/device"
        # Whiskey Lake UHD 620 on the documented workstation. Other Intel
        # generations need their own VA-API driver choice.
        if [[ $gpu_device == 0x3ea0 ]]; then
          echo intel-media-driver
          echo libva-utils
        fi ;;
      0x1002) has_gpu=true ;;
      0x10de)
        # Preserve an existing proprietary userspace driver. Otherwise use the
        # in-kernel nouveau driver with Mesa; do not guess GPU generations.
        if ! pacman -Q nvidia-utils >/dev/null 2>&1; then
          has_gpu=true
        fi ;;
    esac
  done
  "$has_gpu" && echo mesa
  if compgen -G "$sys_root/class/backlight/*/brightness" >/dev/null; then
    echo brightnessctl
  fi
  for device in "$sys_root"/class/power_supply/*; do
    [[ -r $device/type ]] && [[ $(<"$device/type") == Battery ]] || continue
    [[ ! -r $device/scope || $(<"$device/scope") != Device ]] || continue
    # Respect an existing profile manager and its optional compatibility service.
    if ! pacman -Q tlp >/dev/null 2>&1 && ! pacman -Q tuned >/dev/null 2>&1 &&
       ! pacman -Q system76-power >/dev/null 2>&1; then
      echo power-profiles-daemon
    fi
    break
  done
  return 0
}
