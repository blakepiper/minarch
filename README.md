![Minarch logo](minarch.png)

# Minarch

A small, keyboard-first post-install configuration for **Arch Linux x86_64**.
OXWM, st with Bash/ble.sh, and Picom provide the desktop. Neovim and Codex
provide the development workflow. Minarch favors low idle activity and
understandable components.

This README is the project documentation. Package manifests, configuration,
and tests are linked below; historical implementation notes remain in Git history.

- [Installation](#installation)
- [Desktop and keybindings](#desktop-and-keybindings)
- [Terminal and Neovim](#terminal-and-neovim)
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

## Desktop and keybindings

Reboot if the kernel or input rules changed. Log in on a local TTY and run
`startx`. There is no graphical login manager, autologin, or automatic restart
loop. Quitting OXWM returns to the TTY.

[Session startup](config/session/xinitrc) imports the local logind session,
configures input and external displays, sets a solid dark background, starts
session services, and ends in `exec oxwm`. Picom keeps all windows fully opaque;
shadows, fading, blur, and rounded corners are disabled.

The installer and session helpers honor `XDG_CONFIG_HOME`, falling back to
`~/.config`. X startup imports the XDG config/data/state/cache directories into
the user service environment. Picom's launcher resolves its config there too.

OXWM starts each workspace in dwindle layout with 8 px gaps and 2 px borders.
Its built-in bar shows tags, RAM, CPU, a minute-resolution clock, and a battery
runtime estimate when a battery exists. Edit `~/.config/oxwm/config.lua` and
restart OXWM or the X session to apply changes; there is no reload binding.

Super means Mod4 and Alt means Mod1. The source of truth is
[config/oxwm/config.lua](config/oxwm/config.lua).

| Keys | Result |
| --- | --- |
| Super+Enter | Launch st |
| Super+Space, Super+D | Launch dmenu_run (installed commands) |
| Super+F | Launch Xfe |
| Super+B | Launch Firefox |
| Super+Q | Close focused window |
| Super+P | Toggle focused window floating |
| Super+Shift+F | Toggle fullscreen |
| Super+Tab | Previous numbered tag, wrapping; **not** last-visited tag |
| Super+1…9 | View tag 1…9 (Lua indices 0…8) |
| Super+Shift+1…9 | Move focused window to tag 1…9 |
| Super+Left / Up | Previous window in native stack order |
| Super+Right / Down | Next window in native stack order |
| Super+Shift+Left / Up | Move window backward in stack order |
| Super+Shift+Right / Down | Move window forward in stack order |
| Super+Ctrl+Left / Up | Previous monitor in OXWM monitor order |
| Super+Ctrl+Right / Down | Next monitor in OXWM monitor order |
| Super+Ctrl+Shift+Left / Up | Send window to previous monitor |
| Super+Ctrl+Shift+Right / Down | Send window to next monitor |
| Super+Minus / Equal | Decrease/increase master area by 5 percentage points (within native limits) |
| Super+Shift+Minus / Equal | Decrease/increase master window count |
| Super+N | Cycle native layouts |
| Super+R | Select dwindle layout |
| Super+C | Select classic master/stack tiling |
| Super+Shift+Q | Native immediate quit; the confirmed control-menu logout invokes this binding |
| Super+Shift+S | Drag-select, save PNG, copy exact saved PNG |
| Print | Full-screen PNG, save + clipboard |
| Alt+Print | Focused-window PNG, save + clipboard |
| Super+V | dmenu text clipboard history |
| Super+L | Lock through the session's xss-lock service |
| Super+Shift+Space | Control menu |
| XF86AudioRaiseVolume | `wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+` |
| XF86AudioLowerVolume | `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-` |
| XF86AudioMute | Toggle sink mute |
| XF86AudioMicMute | Toggle source mute |
| XF86AudioPlay | `playerctl play-pause` |
| XF86AudioNext / Prev | `playerctl next` / `previous` |
| XF86MonBrightnessUp / Down | ±5% backlight, down clamped to 1; no-op without a backlight |

Arrow bindings follow native stack/monitor order, not geometric direction.
Super+Tab moves to the previous numbered tag rather than the last visited tag.
The layout cycle contains tiling, monocle, floating, scrolling, grid, and dwindle.
Super+Shift+Enter is unbound; gammastep has no default keybinding.

The control menu confirms logout before sending the native Super+Shift+Q
binding through xdotool. Pressing that binding directly quits immediately.
The pinned OXWM build has no external quit IPC. Master resizing uses ±50 in
OXWM's 1/1000 units for a five-percentage-point change.

## Terminal and Neovim

st 0.9.3 includes the Seafoam palette, JetBrains Mono Nerd Font, 5000 lines of
scrollback, mouse-wheel and Shift+PageUp/PageDown scrolling, Shift+Home/End
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

Open st with Super+Enter and run `nvim .` in a project. For the integrated editor
layout, use:

```sh
nvimide [project-directory] [Neovim arguments...]
```

A leading directory becomes the working directory; remaining arguments pass
through to Neovim. The launcher sets `MINARCH_NVIMIDE=1` to open a 30-column
left file explorer and two bottom terminals, retaining editor focus. Plain
`nvim` does not enable this layout.

[config/nvim](config/nvim) contains the complete LazyVim/lazy.nvim configuration,
Seafoam colorscheme, plugin overrides, and lockfile. Plugins and parsers download
on first use. Minarch uses system `lua-language-server` and `shfmt`, disables
Mason, selects Blink's Lua fuzzy matcher, and uses LSP formatting for Lua.
Disabled Mason plugins are omitted from the lockfile.
The parser build tools and archive utilities are in the package manifest.
The lazy.nvim update checker is enabled.

The bootstrap seeds its working lockfile from the repository only when the
state copy is absent. To restore the repository's plugin pins, close Neovim
and run from the repository root:

```sh
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
cp config/nvim/lazy-lock.json "${XDG_STATE_HOME:-$HOME/.local/state}/nvim/lazy-lock.json"
nvim --headless '+Lazy! restore' '+qa!'
```

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
The two requested extensions are installed at browser startup via Mozilla's
`ExtensionSettings` policy using `normal_installed`; users can disable them.
Their settings remain configurable through the extension UI.

| Extension | Verified add-on ID | Source |
| --- | --- | --- |
| Dark Reader | `addon@darkreader.org` | [Mozilla Add-ons](https://addons.mozilla.org/firefox/addon/darkreader/) |
| Enhancer for YouTube | `enhancerforyoutube@maximerf.addons.mozilla.org` | [Mozilla Add-ons](https://addons.mozilla.org/firefox/addon/enhancer-for-youtube/) |

Firefox downloads the latest compatible signed extension from Mozilla Add-ons;
initial installation requires network access. Updates follow the add-ons' normal
update channel. These extensions are not vendored or pinned to a particular
version. No wildcard extension blocklist is imposed.

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

Xfe has a dark profile and is the default directory handler. Firefox opens web
links, mpv opens audio/video, and feh opens images. Removable media is mounted
manually; no automounter is included. PipeWire, WirePlumber, and pipewire-pulse
handle audio. Media and brightness bindings are listed above.

Gammastep is installed for color-temperature adjustment, with no default
schedule or autostart. `horizon.png` and `night.png` install under
`~/.config/wallpaper/`; startup still uses a solid background. To display one
for the current session:

```sh
feh --bg-fill "${XDG_CONFIG_HOME:-$HOME/.config}/wallpaper/horizon.png"
```

feh exits after setting the background; no wallpaper daemon is needed.

Keyboard repeat is 200 ms/50 Hz. Touchpads use natural scrolling, tapping, and
disable-while-typing. Mouse natural scrolling excludes touchpads, tablets,
and pointing sticks. Machine-specific settings live in
[config/minarch/hardware.conf](config/minarch/hardware.conf), installed at
`${XDG_CONFIG_HOME:-$HOME/.config}/minarch/hardware.conf`. The shipped profile keeps
these defaults:

- Swap Command/Alt positions on `Gaming Keyboard` (`1fc9:e8c7`), including
  reconnects; the laptop keyboard keeps its mapping.
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
Super+Shift+S for a region, Print for the screen, or Alt+Print for the focused
window. Escape preserves the clipboard and saves nothing. xclip remains alive
while serving copied content, as required by X selections.

Super+V opens clipmenu's text history through dmenu, limited to 100 entries.
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
restarts it after unlocking. xss-lock holds a logind delay inhibitor and waits
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
| X server/session | xorg-server, xorg-xinit, xf86-input-libinput, xorg-xauth | Xorg, startx and input; no display manager |
| X configuration/inspection | xorg-xset, xorg-xsetroot, xorg-setxkbmap, xorg-xkbcomp, xorg-xrandr, xorg-xprop, xorg-xdpyinfo | Keyboard remapping, display setup, DPMS, and inspection; xdpyinfo is also used by startx |
| URL/MIME opening | xdg-utils | Browser authentication links and MIME defaults without a DE |
| Browser | firefox, firefox-ublock-origin | Privacy policies; packaged uBlock Origin; Dark Reader and Enhancer for YouTube installed through Mozilla Add-ons |
| Launcher/media | dmenu, mpv, feh | Immediate command search; on-demand playback/image viewing |
| Screen color temperature | gammastep | Included for user-configured color temperature adjustment; no default autostart |
| Project workflow | git, openssh, neovim, fastfetch, lazygit | Requested editor, compact system display, Git tools and SSH client; sshd never enabled |
| CLI tools | ripgrep, fd, fzf, curl, jq, bat, eza, btop, less, man-db, unzip, bash-completion | Explicitly requested tools; no background services |
| Builds/checks | base-devel, shellcheck, libx11, libxft, libxext, fontconfig | AUR/st compilation and repo checks; gcc/make/patch come from base-devel |
| Editor tools | lua-language-server, shfmt, tree-sitter-cli, tar, gzip | System Lua LSP and shell formatter; Treesitter parser generation and archive extraction |
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
| xfe | Pinned AUR recipe for the graphical file manager |
| blesh-git | Pinned AUR recipe plus ble.sh/contrib source commits; interactive Bash editing |
| st-minarch | Local recipe for st 0.9.3, scrollback/URL patch, palette, and Bash/ble.sh startup |

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
| `minarch-session.target` | Started explicitly by .xinitrc; not enabled at boot | Groups X-specific services |
| `minarch-lock.service` / xss-lock | During X | Receives X/logind events, holds suspend delay inhibitor, launches XSecureLock only when needed |
| `minarch-clipboard.service` / clipmenud + clipnotify | During X | Event-driven text clipboard history required for Super+V |
| `minarch-hardware-hotplug.service` / udev monitor | During X | Restores the selected external keyboard map and HDMI mirror after reconnects |
| `minarch-picom.service` / picom | During X except while locked | Compositing with fully opaque windows; stopped before XSecureLock and restarted after unlock |
| `pipewire.socket`, `pipewire-pulse.socket` | Started with the X session | On-demand native/Pulse audio endpoints |
| `wireplumber.service` and PipeWire audio processes | User audio session | Device/session routing and reliable browser audio |

The session target binds to xss-lock. When its X connection disappears, the
target stops clipboard, hotplug, and Picom services. Audio may remain while the
TTY session is logged in; no user lingering is enabled. The hotplug helper
watches udev events. CPU and RAM bar updates run every five seconds, battery
updates every 30 seconds, and the clock every minute.

Minarch does not enable another network manager, sshd, Bluetooth, printing,
automounting, notifications, portals, a graphical privilege agent, keyrings,
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

The entire Neovim directory is one managed unit. Package-owned files, including
st's launcher, are updated by pacman. The installer never uninstalls unrelated
packages or removes user-owned services.

## Checks and troubleshooting

All test runners and supporting files live in `tests/`. Run from the repository
root; `check.sh` accepts optional unittest selectors for focused checks:

```sh
./tests/check.sh                 # lint, shell syntax, isolated integration tests
./tests/check.sh ConfigSafety    # lint and installer tests
./tests/smoke.sh                 # installed-workstation checks
./tests/nvim.sh --headless       # Neovim startup; first run needs downloads
./tests/validate-oxwm.sh         # builds pinned OXWM and checks parsed bindings
python3 tests/x11.py             # optional nested-X integration tests
minarch-stats                   # on-demand system audit
```

Repository checks require Python and ShellCheck. OXWM build checks require
Zig and its build dependencies. The nested-X test also needs `xorg-server-xvfb`
and the installed X11 tools; it does not operate on the main X session.
Tests do not perform real suspend, reboot, or poweroff.

The September 28 checks passed 23 isolated integration tests, repository shell
lint and syntax checks, OXWM configuration validation, normal/IDE-mode headless
Neovim startup, Firefox policy schema and extension
ID checks, and Picom configuration diagnostics. Headless editor startup does not
verify the visible IDE layout. Earlier nested-X and package-build results are in
Git history; they are not a full validation of the current installation.

Installer regressions cover same-version rebuilds and failure retries, custom
configuration paths, conservative retired-file cleanup, and configurable
keyboard/display handling. Package installation and hotplug commands are mocked
in those tests; actual package transactions and physical hotplug remain hardware
checks.

Still verify on the installed workstation: a complete Arch package transaction,
first TTY/startx session, actual extension installation, password locking,
lid/suspend/resume, GPU acceleration, display/input hotplug, audio, brightness,
and the visible Neovim IDE layout.

| Area | Checks |
| --- | --- |
| Xorg | Start from a local TTY without sudo. Inspect `~/.local/share/xorg/Xorg.0.log`, `journalctl -b`, `lspci -k`, and `xrandr`. |
| OXWM | Run `oxwm --validate ~/.config/oxwm/config.lua`; parser tests cover all 66 bindings and duplicate combinations. |
| Lock/session | Inspect `journalctl --user -u minarch-lock.service` and `systemctl --user status minarch-session.target`; confirm DISPLAY and XDG_SESSION_ID in `systemctl --user show-environment`. |
| st | Check `fc-match 'JetBrainsMono Nerd Font'`, `locale`, and `infocmp st-256color`; rerun the installer after source/config changes. |
| Neovim | Check system language tools and network access for plugin/parser downloads; use the lockfile restore commands above. |
| Firefox | Restart fully, inspect `about:policies` for errors and `about:addons` for the extensions. |
| Audio | Run `wpctl status` and inspect user PipeWire/WirePlumber units. |
| Network | Inspect your existing stack; use `nmcli` with NetworkManager. |
| Microcode | Check that the bootloader loads the installed microcode; inspect `journalctl -k -b`. |

Useful audit commands include `systemd-analyze`, `systemd-analyze blame`,
`systemctl --type=service --state=running`,
`systemctl --user --type=service --state=running`, `free -h`,
`ps aux --sort=-%mem`, `pstree`, `pacman -Q`, and `glxinfo -B`.
