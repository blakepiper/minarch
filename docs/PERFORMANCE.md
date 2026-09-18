# Performance and service review

The target is low **idle activity**, not the smallest package database. Compilers,
fonts, manual pages, and on-demand development tools consume disk but do not
need persistent processes. Reliability takes priority over speculative tuning.

## Every service Minarch enables or starts

| Unit/process | When | Why |
| --- | --- | --- |
| `polkit.service` / polkitd | D-Bus activated as logind authorizes power actions; not explicitly enabled | Allows the normal active local user to use the requested power menu; no GUI agent |
| `fstrim.timer` | Enabled system-wide only when lsblk reports discard support | Standard periodic SSD discard; no continuous worker |
| `minarch-session.target` | Started explicitly by .xinitrc; not enabled at boot | Groups X-specific services |
| `minarch-lock.service` / xss-lock | During X | Receives X/logind events, holds suspend delay inhibitor, launches XSecureLock only when needed |
| `minarch-clipboard.service` / clipmenud + clipnotify | During X | Event-driven text clipboard history required for Super+V |
| `minarch-hardware-hotplug.service` / udev monitor | During X | Restores the selected external keyboard map and HDMI mirror after reconnects |
| `minarch-picom.service` / picom | During X except while locked | Window transparency; stopped before XSecureLock and restarted after unlock |
| `pipewire.socket`, `pipewire-pulse.socket` | Started with the X session | On-demand native/Pulse audio endpoints |
| `wireplumber.service` and PipeWire audio processes | User audio session | Device/session routing and reliable browser audio |

The session target binds to the xss-lock service. When X disappears, xss-lock
exits, the target stops, and PartOf stops the clipboard, hotplug and Picom services.
Thus clipmenud cannot linger in its X-disconnection retry loop. A bounded startup
check verifies its sleep inhibitor, then exits. The hotplug service watches udev
events; the CPU bar helper runs at five-second intervals. Audio may remain while
the TTY user stays logged in; systemd manages the user manager's normal logout lifecycle. No user lingering
is enabled. XSecureLock exists only while locked. Xclip may remain while owning
copied content, as required by X11 selections.

No networking service is enabled or replaced by Minarch. The expected existing
NetworkManager remains the user's choice; systemd-networkd and other existing
stacks are likewise retained. No sshd, Bluetooth, cups, discovery, modem manager,
package management daemon, display manager, or firewall service is enabled.
Pre-existing services are reported, not disabled.

## What is deliberately absent

No desktop environment, secondary bar, wallpaper process, tray
applet, indexer, desktop search, notification daemon, portals, automounter,
Polkit GUI agent, keyring daemon, Bluetooth, printing, idle screensaver framework,
or background performance suite. The solid root background is set once. The
built-in clock updates every 60 seconds; battery data is read every 30 seconds
only when a battery exists. RAM and CPU blocks update every five seconds.
Picom uses XRender with shadows, fading, blur and rounded corners disabled.
Weather and other network widgets are omitted.

No governors are forced and there are no sysctl, kernel-command-line, scheduler,
filesystem, or latency "optimizations". CPU scaling uses the normal kernel
stack. Hardware probing selects CPU microcode, Mesa where appropriate,
brightnessctl when a backlight exists, and the Intel media driver for the
documented UHD 620 PCI ID. No broad GPU-driver collection is installed.

## Measuring fairly

Use `minarch-stats` on demand; it never runs in the background. Record:

```sh
systemd-analyze
systemd-analyze blame
systemctl --type=service --state=running
systemctl --user --type=service --state=running
free -h
ps aux --sort=-%mem
pstree
pacman -Q
xrandr
glxinfo -B
```

For a fair comparison with another desktop use the same kernel/drivers,
resolution/refresh, power source, browser profile/tabs, and applications. After
boot and login, wait for package updates, first-run editor downloads and browser
startup to settle. Compare available memory and swap as well as RSS; shared
pages make summed RSS misleading. Sample idle CPU over at least a minute with
`top` or on-demand btop. Distinguish clean-session measurements from a restored
browser/development workload. Repeat each measurement; report conditions and
variation, not a single flattering number. This repository claims no measured
RAM/CPU savings on hardware it has not tested.

## Locking and physical-machine validation

XSecureLock is slightly larger than slock but supports the xss-lock sleep-fd
readiness protocol directly. This removes the unsafe "sleep a moment and hope
it locked" approach. The .xinitrc exports the **local logind session ID** to the
user service because a systemd user service has no implicit TTY session. Normal
logind suspend honors the delay inhibitor, including lid/external suspend
requests. Automatic idle locking is disabled with `xset s off`.

Test actual password unlocking with Picom active, lid/system suspend and resume,
multi-monitor hotplug, brightness permissions, audio keys, GPU acceleration, and your locale
on the installed machine. A virtual X server cannot establish those properties.
Do not bypass inhibitors with forced suspend. X11's security limitations and
locker failures due to another client's active grab are not solved by Minarch;
check the lock visibly before leaving the machine. No destructive session-kill
fallback is configured.
