![Minarch logo](minarch.png)

# Minarch

A small, keyboard-first post-install configuration for **Arch Linux x86_64**.
OXWM, st with Bash/ble.sh, and Picom provide the desktop. Vim and Codex
provide the development workflow. Minarch favors low idle activity and
understandable components.

This README is the project documentation. Package manifests, configuration,
and tests are linked below; historical implementation notes remain in Git history.

- [Installation](#installation)
- [Desktop and keybindings](#desktop-and-keybindings)
- [Terminal and Vim](#terminal-and-vim)
- [Firefox](#firefox)
- [Files, media, and hardware](#files-media-and-hardware)
- [Screenshots, clipboard, and locking](#screenshots-clipboard-and-locking)
- [Packages and builds](#packages-and-builds)
- [Services and performance](#services-and-performance)
- [Updates and configuration ownership](#updates-and-configuration-ownership)
- [Checks and troubleshooting](#checks-and-troubleshooting)

## Installation

Start with a minimal Arch installation, a configured bootloader, working
networking, `git`, and a normal sudo-capable user. Minarch does not install Arch,
partition disks, change filesystems, configure EFI, or install a bootloader.
It leaves your network manager in charge.

Run as your normal user:

```sh
git clone https://github.com/blakepiper/minarch.git ~/minarch
cd ~/minarch
./install.sh
```

The installer rejects root, checks Arch/x86_64 and HTTPS access, runs
`pacman -Syu --needed`, builds pinned AUR/local packages as your user, and
installs configuration. Package-manager prompts are expected. Fix failed
stages and rerun as needed.

Read the **Preserved:** messages: differing existing configurations are kept.
To replace managed configurations with adjacent backups:

```sh
./install.sh --replace-config
```

`./install.sh --config-only` copies user configuration without packages, sudo,
or system changes. It is useful for inspection, not a full installation.
`--cleanup-retired` additionally retires recognized old user files with backups;
see [configuration ownership](#updates-and-configuration-ownership) for cleanup
details and replacement behavior.

After a full installation, reboot. Tuigreet appears on VT1. Sign in with
your Linux account and it starts Minarch through `startx`. Logging out
returns to the greeter. The installer selects
`graphical.target` as the boot target and uses a separate Minarch greetd
configuration. An enabled display manager must be disabled before switching.
Press **Ctrl+Alt+F2** for a recovery TTY. To return to text login on the next
boot, sign in there and run `sudo systemctl disable greetd.service`.

## Desktop and keybindings

You can also launch Minarch manually from a local TTY with `startx`.
Quitting a manually started session returns to the TTY.

[Session startup](config/session/xinitrc) imports the local logind session,
configures input and external displays, starts session services, and ends in
`exec oxwm`. Picom defaults to fully opaque windows. Shadows, fading, blur, and
rounded corners are disabled.

The installer and session helpers honor `XDG_CONFIG_HOME`, falling back to
`~/.config`. X startup imports the XDG config/data/state/cache directories into
the user service environment. Picom's launcher resolves its config there too.

OXWM starts each workspace in dwindle layout with upstream gaps, borders, and
bar styling. Click **Vol** for the volume slider or **Bri** for the brightness
slider on systems with a panel backlight or an accessible DDC/CI monitor.
Click **Bat** on a laptop to query its power-profile service and select an
available mode in dmenu.
The bar also shows the date and time and a battery runtime estimate when available.

**Alt+S** opens or focuses Blix Settings. Its GTK interface includes display,
audio, network, Bluetooth, power, input, and shortcuts. Network and Bluetooth
controls use existing NetworkManager and BlueZ services when available. For
external brightness, enable DDC/CI on the monitor. The slider controls the
first DDC/CI display and requires local access to its I²C device.
The controls and GTK app are adapted from [Blix](https://github.com/blakepiper/blix).

Edit `~/.config/oxwm/config.lua` and restart OXWM or the X session to apply
changes. There is no reload binding.

Alt (Mod1) is the main shortcut modifier. The bindings are defined in
[config/oxwm/config.lua](config/oxwm/config.lua).

| Keys | Result |
| --- | --- |
| Alt+Enter | Launch st |
| Alt+Space | Search desktop applications by name in Rofi |
| Alt+D | Run an installed command with dmenu |
| Alt+F | Open Thunar |
| Alt+B | Launch Firefox |
| Alt+S | Open or focus Blix Settings |
| Alt+Q | Close focused window |
| Alt+P | Toggle focused window floating |
| Alt+Shift+F | Toggle fullscreen |
| Alt+Tab | Previous numbered tag, wrapping; **not** last-visited tag |
| Alt+1…9 | View tag 1…9 (Lua indices 0…8) |
| Alt+Shift+1…9 | Move focused window to tag 1…9 |
| Alt+Left / Up | Previous window in native stack order |
| Alt+Right / Down | Next window in native stack order |
| Alt+Shift+Left / Up | Move window backward in stack order |
| Alt+Shift+Right / Down | Move window forward in stack order |
| Alt+Ctrl+Left / Up | Previous monitor in OXWM monitor order |
| Alt+Ctrl+Right / Down | Next monitor in OXWM monitor order |
| Alt+Ctrl+Shift+Left / Up | Send window to previous monitor |
| Alt+Ctrl+Shift+Right / Down | Send window to next monitor |
| Alt+Minus / Equal | Decrease/increase master area by 5 percentage points (within native limits) |
| Alt+Shift+Minus / Equal | Decrease/increase master window count |
| Alt+N | Cycle native layouts |
| Alt+R | Select dwindle layout |
| Alt+C | Select classic master/stack tiling |
| Alt+Shift+Q | Native immediate quit; the confirmed control-menu logout invokes this binding |
| Alt+Shift+S | Drag-select, save PNG, copy exact saved PNG |
| Print | Full-screen PNG, save + clipboard |
| Alt+Print | Focused-window PNG, save + clipboard |
| Alt+V | dmenu text clipboard history |
| Alt+L | Lock through the session's xss-lock service |
| Alt+Shift+Space | Control menu |
| XF86AudioRaiseVolume | `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+` |
| XF86AudioLowerVolume | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-` |
| XF86AudioMute | Toggle sink mute |
| XF86AudioMicMute | Toggle source mute |
| XF86AudioPlay | `playerctl play-pause` |
| XF86AudioNext / Prev | `playerctl next` / `previous` |
| XF86MonBrightnessUp / Down | ±5% backlight, down clamped to 1; no-op without a backlight |

Arrow bindings follow native stack/monitor order, not geometric direction.
Alt+Tab moves to the previous numbered tag rather than the last visited tag.
The layout cycle contains tiling, monocle, floating, scrolling, grid, and dwindle.
Alt+Shift+Enter is unbound; gammastep has no default keybinding.

The control menu confirms logout before sending the native Alt+Shift+Q
binding through xdotool. Pressing that binding directly quits immediately.
The pinned OXWM build has no external quit IPC. Master resizing uses ±50 in
OXWM's 1/1000 units for a five-percentage-point change.

## Terminal and Vim

st 0.9.3 uses its upstream colors and font. The included patches add 5000 lines
of scrollback, mouse-wheel and Shift+PageUp/PageDown scrolling, Shift+Home/End
jumps, and underlined clickable HTTP(S) URLs. Ctrl+Shift+C/V copies/pastes;
middle-click pastes PRIMARY. Hold Shift to select text when an application
captures the mouse. Alternate-screen applications retain their own scrolling.

The st package launches Bash through `minarch-shell` and
`/usr/share/minarch/bashrc`. It loads your existing `~/.bashrc`, then enables
ble.sh if needed for highlighting, suggestions, and history search. This works
with preserved user startup files. `st -e ...` still runs the requested command,
and the account's login shell is unchanged. For TTY access to Minarch helpers,
ensure your Bash configuration exports `PATH="$HOME/.local/bin:$PATH"`.
X sessions already set that path.

Open st with Alt+Enter and run `vim path/to/file` or `vim .` in a project.
Minarch installs Vim with its stock defaults and sets `EDITOR` and `VISUAL`
to `vim` in its Bash configuration.

JetBrains Mono Nerd Font is the system Fontconfig default for sans-serif, serif,
and monospace. Noto fonts provide additional script and emoji coverage.

Codex is supplied by Arch's `openai-codex` package. Run `codex --version`, then
`codex` in a project and complete its first-run authentication. The installer
stores no credentials and installs no other AI agent or desktop keyring.

## Firefox

Minarch installs `etc/firefox/policies/policies.json` at
`/etc/firefox/policies/policies.json`. Policies apply to Firefox profiles on the
machine after a full browser restart.

### Privacy defaults

- Strict Enhanced Tracking Protection, including known and suspected
  fingerprinters, cryptominers, and email trackers.
- Global Privacy Control and tracking-query stripping in normal/private windows.
- HTTPS-only mode enabled by default, with user exceptions available.
- Telemetry uploads, Firefox studies, remote improvements, and automatic
  pending crash-report submission disabled.
- Search suggestions, Firefox Suggest, sponsored Home content, personalized
  extension recommendations, and feature promotions disabled.
- DNS prediction, link prefetching, and speculative connections disabled.
- Firefox AI features blocked by the existing AIControls policy.

Tracking protection and HTTPS-only mode remain adjustable for site compatibility.
Global Privacy Control and tracking-query stripping are also user-adjustable.
Telemetry/prediction preferences, Home/Suggest settings, and promotion settings
are locked. This configuration preserves password saving, form history,
address/card autofill, cookies and browsing sessions, WebRTC, Safe Browsing,
certificate checks, extension signature checks, and normal security updates. It does not provide anonymity or a VPN.

### Extensions

uBlock Origin remains supplied by Arch's `firefox-ublock-origin` package.
Firefox installs Enhancer for YouTube at startup through Mozilla's
`ExtensionSettings` policy using `normal_installed`. Users can disable it
or configure it through the extension UI.

| Extension | Verified add-on ID | Source |
| --- | --- | --- |
| Enhancer for YouTube | `enhancerforyoutube@maximerf.addons.mozilla.org` | [Mozilla Add-ons](https://addons.mozilla.org/firefox/addon/enhancer-for-youtube/) |

Firefox downloads the latest compatible signed extension from Mozilla Add-ons;
initial installation requires network access. Updates follow the add-ons' normal
update channel. Minarch uses the current compatible release and leaves users
free to install other extensions.

### Apply and verify

For an existing installation, the installer preserves differing policy files.
To apply only these Firefox changes, back up the installed policy file if present,
then install the new one:

```sh
sudo install -d /etc/firefox/policies
if sudo test -e /etc/firefox/policies/policies.json; then
  sudo cp --backup=numbered /etc/firefox/policies/policies.json /etc/firefox/policies/policies.json.backup
fi
sudo install -m644 etc/firefox/policies/policies.json /etc/firefox/policies/policies.json
```

Alternatively, `./install.sh --replace-config` applies all managed configurations
with backups. Fully restart Firefox, check `about:policies` for active policies
and errors, and check `about:addons` for both extensions. Existing manually
installed copies are matched by their add-on IDs.

Policy fields and extension IDs were checked against Mozilla's
[policy schema](https://github.com/mozilla-firefox/firefox/blob/main/browser/components/enterprisepolicies/schemas/policies-schema.json),
[ExtensionSettings documentation](https://firefox-admin-docs.mozilla.org/reference/policies/extensionsettings/),
and the Mozilla Add-ons API on 2026-09-28. Use current Arch Firefox;
`DisableRemoteImprovements` requires Firefox 148 or later.

## Files, media, and hardware

Thunar opens folders on demand and is the default directory handler. Firefox opens web
links, mpv opens audio/video, and feh opens images. Removable media is mounted
manually; no automounter is included. PipeWire, WirePlumber, and pipewire-pulse
handle audio. Media and brightness bindings are listed above.

Gammastep is installed for color-temperature adjustment, with no default
schedule or autostart. The X session uses the default root background.

Keyboard repeat is 200 ms/50 Hz. Touchpads use natural scrolling, tapping, and
disable-while-typing. Mouse natural scrolling excludes touchpads, tablets,
and pointing sticks. Machine-specific settings live in
[config/minarch/hardware.conf](config/minarch/hardware.conf), installed at
`${XDG_CONFIG_HOME:-$HOME/.config}/minarch/hardware.conf`. The shipped profile keeps
these defaults:

- Enable Ctrl+Alt+Backspace on `Gaming Keyboard` (`1fc9:e8c7`), including
  reconnects. Its physical Alt key uses the standard Alt mapping.
- Mirror HDMI-2 to eDP-1 at 1920×1080/60 Hz, including display hotplug.
- Merge duplicate mirrored Xinerama rectangles in OXWM to avoid overlapping bars.

Edit the profile to change the keyboard name, USB vendor/product IDs, layout,
XKB options, interface count, or monitor outputs/mode/refresh rate. Set
`keyboard_name=''` or `mirror_output=''` to disable the corresponding feature.
An empty `mirror_mode` selects the display's automatic mode; an empty
`mirror_rate` uses its default refresh rate. Mirroring requires both outputs to
be connected. Restart `minarch-hardware-hotplug.service` with
`systemctl --user restart minarch-hardware-hotplug.service` to load profile edits.
Missing profiles make the helper a no-op; differing installed profiles are
preserved under the normal installer rules.

Conditional packages in [install/hardware.sh](install/hardware.sh):

| Detected hardware | Packages and behavior |
| --- | --- |
| Intel/AMD CPU | Matching microcode package; existing boot setup must load it |
| Intel/AMD graphics | Mesa with kernel modesetting; no forced DDX configuration |
| NVIDIA graphics | Preserve installed `nvidia-utils`; otherwise use Mesa with the kernel's nouveau driver; select a vendor driver separately if required |
| Backlight interface | brightnessctl; brightness-down is clamped to 1 |
| Intel UHD 620 (`8086:3ea0`) | intel-media-driver and libva-utils for video decoding |

Other GPUs retain their video-decoding driver choice. Minarch does not guess
NVIDIA generations or install a broad collection of graphics drivers.

## Screenshots, clipboard, and locking

Screenshots save private, uniquely named PNG files in `~/Pictures/Screenshots/`
and place the exact saved image on the X clipboard as `image/png`. Use
Alt+Shift+S for a region, Print for the screen, or Alt+Print for the focused
window. Escape preserves the clipboard and saves nothing. xclip remains alive
while serving copied content, as required by X selections.

Alt+V opens clipmenu's text history through dmenu, limited to 100 entries.
The watcher is event-driven. Image history is not provided; the current image
can still be pasted. A private xsel probe skips image-only selections to avoid
interrupting large PNG pastes. Copied text can contain secrets. Pause/resume
collection with `clipctl disable` / `clipctl enable`; clear it with
`clipdel -d '.*'`. History uses private runtime storage.

The control menu offers Lock, Suspend, Reboot, Log Out, Monitors Off, and
Power Off. Reboot, logout, and poweroff require confirmation. The polkit backend
authorizes normal-user logind actions. Additional sessions or blocking inhibitors
may require a manual `sudo systemctl ...` action.

XSecureLock runs through xss-lock. Its wrapper stops Picom before locking and
restarts it after unlocking. The lock screen shows the time and prompts for the
current user's password as soon as a manual lock completes or the laptop
resumes. Tuigreet handles login after boot and logout. xss-lock holds a logind
delay inhibitor and waits
for the locker to be ready before normal suspend, including lid/external
suspend. X startup checks that the lock service owns this inhibitor before
launching OXWM. A local logind session is required; Minarch manages one X session
per user. No idle lock or automatic display blanking is configured.

Test password unlock and suspend/resume on your hardware before relying on
this setup. Forced suspend bypassing inhibitors is outside the readiness
protocol. X11 client grabs and X11's broader security limitations still apply.

## Packages and builds

The manifests are the source of truth:
[official packages](install/packages), [AUR pins](install/packages-aur), and
[local st package](config/st/PKGBUILD). On-demand tools consume disk space but
add no idle process merely by being installed.

| Purpose | Direct official packages | Rationale / persistent activity |
| --- | --- | --- |
| X server/session | xorg-server, xorg-xinit, xf86-input-libinput, xorg-xauth | Xorg, startx, and input |
| Login | greetd, greetd-tuigreet | Password prompt and automatic X session launch after login |
| X configuration/inspection | xorg-xset, xorg-setxkbmap, xorg-xkbcomp, xorg-xrandr, xorg-xprop, xorg-xdpyinfo | Keyboard remapping, display setup, DPMS, and inspection; xdpyinfo is also used by startx |
| URL/MIME opening | xdg-utils | Browser authentication links and MIME defaults without a DE |
| Browser | firefox, firefox-ublock-origin | Privacy policies, packaged uBlock Origin, and Enhancer for YouTube from Mozilla Add-ons |
| Launcher/media | rofi, dmenu, mpv, feh | On-demand application search, command prompts, playback and image viewing |
| File manager | thunar | Opens on demand from Alt+F or a folder link |
| Notifications | dunst, libnotify | D-Bus activates Dunst when a notification is sent |
| Screen color temperature | gammastep | One-shot color temperature adjustment for Night Light |
| Project workflow | git, openssh, vim, fastfetch | Requested editor, compact system display, Git and SSH client; sshd never enabled |
| CLI tools | ripgrep, fd, fzf, curl, jq, bat, eza, btop, less, man-db, unzip, bash-completion | Explicitly requested tools; no background services |
| Builds/checks | base-devel, shellcheck, libx11, libxft, libxext, fontconfig | AUR/st compilation and repo checks; gcc/make/patch come from base-devel |
| Codex | openai-codex | Maintained official Arch binary package; no AUR/npm/Node requirement |
| Screenshots | maim, slop, xclip | Region capture, selection, exact PNG X clipboard ownership |
| Clipboard | clipmenu | dmenu text history; its small clipnotify/xsel/xdotool dependencies serve X selections; event-driven watcher |
| Lock/suspend | xsecurelock, xss-lock | Secure X locker with logind readiness handoff; no idle animation or screenshot background |
| Compositor | picom | Compositing with fully opaque windows and no visual effects; stopped during XSecureLock |
| Power authorization | polkit | Required logind backend for normal-user suspend/reboot/poweroff; D-Bus activated, no GUI agent or custom rules |
| Audio | pipewire, wireplumber, pipewire-pulse | Reliable normal application audio; only intentional audio user services |
| Media keys | playerctl | On-demand MPRIS transport commands |
| Fonts | ttf-jetbrains-mono-nerd, noto-fonts, noto-fonts-emoji | Requested coding font, basic multilingual/emoji coverage |
| Audit | mesa-utils, pciutils, psmisc | glxinfo, lspci and pstree; on demand |

| Package built locally | Source and purpose |
| --- | --- |
| oxwm-git | Pinned AUR recipe/source; Zig window manager with microphone keysym and mirrored-screen patches |
| blesh-git | Pinned AUR recipe plus ble.sh/contrib source commits; interactive Bash editing |
| st-minarch | Local recipe for st 0.9.3, scrollback/URL patch and Bash/ble.sh startup |

AUR packages are built directly with makepkg as the normal user; no AUR helper
is required. Build dependencies may remain installed. Official dependencies may
include libraries for other graphical platforms without enabling those platforms.
`xdotool` comes through clipmenu and supplies the confirmed logout action.
Arch's ncurses owns st terminfo; the local recipe does not overwrite it.

OXWM's source/recipe pins are in the AUR manifest. Its two patches are in
[config/oxwm-patches](config/oxwm-patches). The ble.sh contrib pin is recorded in
[install/packages.sh](install/packages.sh). The st recipe records the upstream
tarball SHA-256. Build caching includes recipe/source/config identity and the
installed package version, so changed or removed builds are retried.
Changed builds are reinstalled even when the package version stays the same;
failed installs do not advance the cache. Stamps from the older installer are
invalidated once to recover builds that may previously have been skipped.

## Services and performance

| Unit/process | When | Why |
| --- | --- | --- |
| `polkit.service` / polkitd | D-Bus activated as logind authorizes power actions; not explicitly enabled | Allows the normal active local user to use the requested power menu; no GUI agent |
| `fstrim.timer` | Enabled system-wide only when lsblk reports discard support | Standard periodic SSD discard; no continuous worker |
| `man-db.timer` | Masked by the full installer | Skips scheduled manual index maintenance while keeping `man` available |
| `minarch-session.target` | Started explicitly by .xinitrc; not enabled at boot | Groups X-specific services |
| `minarch-lock.service` / xss-lock | During X | Receives X/logind events, holds suspend delay inhibitor, launches XSecureLock only when needed |
| `minarch-clipboard.service` / clipmenud + clipnotify | During X | Event-driven text clipboard history required for Alt+V |
| `minarch-hardware-hotplug.service` / udev monitor | During X | Restores the selected external keyboard map and HDMI mirror after reconnects |
| `minarch-bar-volume.service` / pactl subscribe | During X | Refreshes the volume block on sink and server changes |
| `minarch-picom.service` / picom | During X except while locked | Compositing with fully opaque windows; stopped before XSecureLock and restarted after unlock |
| `minarch-nightlight.service` | At X startup, on setting changes, and after display hotplug | Runs Gammastep once to apply or reset display warmth |
| `dunst.service` | From the first notification until X session shutdown | Shows desktop notifications, including failures from shortcut actions |
| `pipewire.socket`, `pipewire-pulse.socket` | Started with the X session | On-demand native/Pulse audio endpoints |
| `wireplumber.service` and PipeWire audio processes | User audio session | Device/session routing and reliable browser audio |

The session target binds to xss-lock. When its X connection disappears, the
target stops clipboard, hotplug, and Picom services. Audio may remain while the
TTY session is logged in; no user lingering is enabled. The hotplug helper
watches input, display, and backlight events through one udev subscription.
The volume and brightness blocks refresh on changes. The battery menu and
the Blix Settings Power page query power profiles on demand. At login, the
session contacts the service only to restore a previously saved power mode.
OXWM reads battery data every 30 seconds in-process. The clock updates every
minute.
Blix Settings refreshes when focused, when switching pages, after edits, and
when you press F5.

Minarch does not enable another network manager, sshd, Bluetooth, printing,
automounting, portals, a graphical privilege agent, keyrings,
indexing, or a tuning daemon. Existing user services are reported and retained.
No governors, sysctl settings, kernel command-line parameters, or filesystem
optimizations are forced.

Use `minarch-stats` for an on-demand audit. For performance comparisons, use
the same hardware, resolution, power source, applications, and workload; allow
startup to settle and measure repeatedly. The project makes no measured idle
RAM, CPU, boot-time, or battery-life claims.

## Updates and configuration ownership

```sh
sudo pacman -Syu
git -C ~/minarch pull --ff-only
cd ~/minarch && ./install.sh
```

Use full Arch upgrades. Official packages follow the rolling repositories;
the project is reproducible configuration with pinned AUR/st inputs, not a
frozen OS snapshot. Installed versions are recorded under
`~/.local/state/minarch/packages-installed.txt`.

To update AUR packages, review the recipes and source revisions, update their
pins, adapt local patches when needed, run `tests/validate-oxwm.sh`, and rerun
the installer. Add official packages to the manifest and rerun. Removing a
manifest entry does not uninstall an existing package.

To clean up retired Minarch user files while updating user configuration:

```sh
./install.sh --config-only --cleanup-retired
```

The explicit [retirement catalog](install/retired-files) currently recognizes
the previously shipped `~/.local/bin/dev` and XDG `tmux/tmux.conf`. Only regular
files matching a known SHA-256 are retired. Modified/unknown files, directories,
and symlink paths are preserved, including when `--replace-config` is supplied.
Retired files move to adjacent `<target>.retired.XXXXXXXX/original` backups;
restore them by moving `original` back. Repeated cleanup creates no extra backup
once the old path is gone. This never removes packages or unrelated user files.

Managed user and system files follow the same rules:

- Absent files are installed; identical files are left alone.
- Differing files are preserved by default.
- `--replace-config` stages the replacement, then moves the old file, directory,
  or symlink to `<target>.backup.XXXXXXXX/original`. Paths are printed and
  identical reruns do not create duplicate backups.
- To restore, move the replacement aside and move `original` back to its old
  pathname; use sudo for system paths. Symlinks are backed up as links.

Package-owned files, including st's launcher, are updated by pacman. The
installer never uninstalls unrelated packages or removes user-owned services.

## Checks and troubleshooting

All test runners and supporting files live in `tests/`. Run from the repository
root; `check.sh` accepts optional unittest selectors for focused checks:

```sh
./tests/check.sh                 # lint, shell syntax, isolated integration tests
./tests/check.sh ConfigSafety    # lint and installer tests
./tests/smoke.sh                 # installed-workstation checks
./tests/validate-oxwm.sh         # builds pinned OXWM and checks parsed bindings
python3 tests/x11.py             # optional nested-X integration tests
minarch-stats                   # on-demand system audit
```

Repository checks require Python and ShellCheck. OXWM build checks require
Zig and its build dependencies. The nested-X test also needs `xorg-server-xvfb`
and the installed X11 tools; it does not operate on the main X session.
Tests do not perform real suspend, reboot, or poweroff.

The September 28 checks passed 23 isolated integration tests, repository shell
lint and syntax checks, OXWM configuration validation, Firefox policy schema and
extension ID checks, and Picom configuration diagnostics. Git history contains
the earlier nested-X and package-build results.

Installer regressions cover same-version rebuilds and failure retries, custom
configuration paths, conservative retired-file cleanup, and configurable
keyboard/display handling. Package installation and hotplug commands are mocked
in those tests; actual package transactions and physical hotplug remain hardware
checks.

Still verify on the installed workstation: a complete Arch package transaction,
first tuigreet login and TTY recovery, actual extension installation, password locking,
lid/suspend/resume, GPU acceleration, display/input hotplug, audio, and brightness.

| Area | Checks |
| --- | --- |
| Xorg | Start from a local TTY without sudo. Inspect `~/.local/share/xorg/Xorg.0.log`, `journalctl -b`, `lspci -k`, and `xrandr`. |
| OXWM | Run `oxwm --validate ~/.config/oxwm/config.lua`; parser tests cover all 67 bindings and duplicate combinations. |
| Lock/session | Inspect `journalctl --user -u minarch-lock.service` and `systemctl --user status minarch-session.target`; confirm DISPLAY and XDG_SESSION_ID in `systemctl --user show-environment`. |
| st | Check `fc-match 'JetBrainsMono Nerd Font'`, `locale`, and `infocmp st-256color`; rerun the installer after source/config changes. |
| Firefox | Restart fully, inspect `about:policies` for errors and `about:addons` for the extensions. |
| Audio | Run `wpctl status` and inspect user PipeWire/WirePlumber units. |
| Network | Inspect your existing stack; use `nmcli` with NetworkManager. |
| Microcode | Check that the bootloader loads the installed microcode; inspect `journalctl -k -b`. |

Useful audit commands include `systemd-analyze`, `systemd-analyze blame`,
`systemctl --type=service --state=running`,
`systemctl --user --type=service --state=running`, `free -h`,
`ps aux --sort=-%mem`, `pstree`, `pacman -Q`, and `glxinfo -B`.
