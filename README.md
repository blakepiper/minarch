![Minarch logo](minarch.png)

# Minarch

A small, keyboard-first **post-install configuration for Arch Linux x86_64**.
Xorg runs OXWM, its built-in bar, patched st, and Picom. tmux supplies panes;
the Minarch Neovim configuration and Codex supply the primary
development workflow. No desktop environment, graphical login manager, or
background optimization suite.

Minarch does not install Arch, partition disks, change filesystems, configure
EFI, or install a bootloader. It prefers low idle activity and understandable
components over counting installed packages.

## Starting state and installation

Use `archinstall` to install a minimal system with no desktop. Use the normal
Linux kernel, configure your bootloader, and create a normal sudo-capable user.
Networking must already work (NetworkManager is a good choice), and `git` must
be installed. Minarch leaves network ownership unchanged; it does not enable a
second network manager or install a network applet.

As that normal user:

```sh
git clone https://github.com/blakepiper/minarch.git ~/minarch
cd ~/minarch
./install.sh
```

The SSH clone URL `git@github.com:blakepiper/minarch.git` also works if your SSH
keys are already configured. The installer rejects root, checks Arch/x86_64,
sudo and HTTPS access, upgrades official packages with `pacman -Syu --needed`,
builds reviewed/pinned AUR packages as your user, and installs configuration.
Package-manager prompts are normal. A failed stage can be fixed and rerun.
Nothing uninstalls unrelated user packages or enables an SSH server.

Read all **Preserved:** messages. On a fresh installation, Arch's existing Bash
startup files may be retained. Session PATH setup works independently. To
replace differing managed defaults with backups:

```sh
./install.sh --replace-config
```

`--config-only` installs user files without packages, sudo, or system changes;
it is useful for inspection and tests, not a substitute for the full install.

## First login and X

Reboot after installation if the kernel or input rules changed. Log in on a
local TTY and run:

```sh
startx
```

Minarch deliberately uses **manual startx**. There is no autologin or automatic
restart loop. Exiting OXWM returns to the TTY shell. `~/.xinitrc` imports the
local logind session into the user service manager, configures keyboard repeat,
external devices and a solid dark root background, starts session services, and
ends in `exec oxwm`. No wallpaper process runs.

The default layout is dwindle on every workspace, with 8 px gaps and 2 px
borders. The bar shows tags, RAM, CPU, a minute-resolution clock, and a battery
runtime estimate when a battery is present. OXWM configuration is Lua at
`~/.config/oxwm/config.lua`. Edit it and restart OXWM from a shell or new X
session to change bindings; there is no reload key. See the complete
[actual keybindings](docs/KEYBINDS.md), including stack and monitor semantics.

Common actions:

| Keys | Action |
| --- | --- |
| Super+Enter | st |
| Super+Space / Super+D | dmenu command search |
| Super+F / Super+B | Xfe / Firefox |
| Super+1…9 | View tag |
| Super+Shift+1…9 | Send window to tag |
| Super+Q / Super+P | Close / toggle floating |
| Super+R / Super+C | Dwindle / classic master-stack layout |
| Super+L | Lock |
| Super+Shift+Space | Control menu |
| Super+Shift+S | Drag-region screenshot |
| Super+V | Text clipboard history |

## Screenshots, clipboard, and locking

`screenshot-region` saves a private PNG in `~/Pictures/Screenshots/` with a
unique timestamped filename, then puts that exact PNG on the X clipboard as
`image/png`. Drag with Super+Shift+S, capture the full screen with Print, or the
focused window with Alt+Print. Escape leaves both saved screenshots and the
clipboard unchanged. There is no editor or post-capture dialog. As usual on X11,
xclip remains alive to serve a copied image until clipboard ownership changes.

Super+V uses clipmenu and dmenu for **text history** (100 entries). The watcher
uses X selection events rather than a polling timer. Image history is not
provided; the current screenshot image can still be pasted. A private `xsel`
probe skips image-only selections so clipmenu cannot interrupt large PNG pastes.
History is private to the user but contains copied text, potentially including
secrets. Use
`clipctl disable` / `clipctl enable` to pause/resume collection and `clipdel -d '.*'`
to clear it. History uses clipmenu's runtime storage and does not need a daemon
outside the X session.

The control menu contains exactly Lock, Suspend, Reboot, Log Out, Monitors Off,
and Power Off. Reboot, logout, and poweroff require Yes/No confirmation.
The small polkit backend authorizes normal-user logind power actions; no GUI
authentication agent or custom permission rules are installed. With additional
active user sessions or blocking inhibitors, power actions may require a manual
`sudo systemctl ...` from a terminal instead.
XSecureLock is managed by `xss-lock`, which receives both explicit lock requests
and logind suspend events. The lock wrapper stops Minarch's Picom service before
XSecureLock takes the X Composite Overlay Window and restarts it after unlock.
The xss-lock delay-inhibitor handshake waits for the lock to be ready before
normal system suspend, including suspend initiated outside the
menu. No idle timeout is enabled. Locking requires a normal local logind session;
X startup checks that the lock service owns a logind sleep inhibitor before
launching OXWM. Minarch manages one X session per user. Test lock/resume once on your
actual machine before relying on it. Forced suspend that bypasses inhibitors is
outside this guarantee. See [services and testing limits](docs/PERFORMANCE.md).

## Files, browser, media, input

Xfe is the maintained AUR `xfe` package with a dark color profile. No automounter
is included: manual mounting is sufficient. If you later want removable-media automation, install
and configure udisks2/udiskie yourself; these are not part of Minarch's default.

XDG defaults open directories with Xfe, web links with Firefox, audio/video with
mpv, and common images with feh. feh is launched on demand as a viewer only.
Firefox has Arch-packaged uBlock Origin and the requested enterprise policies:
no sponsored shortcuts/stories/suggestions, no recommended Home stories, and
AIControls default blocked, Strict tracking protection, and Global Privacy
Control. Check `about:policies` after opening Firefox. The UHD 620 (`8086:3ea0`)
also gets `intel-media-driver` and `libva-utils` for video decoding. Other GPUs
keep their existing driver choice. Dark Reader and Enhancer for YouTube were
installed manually on the original machine; they are not managed by Minarch.
Firefox IP Protection is also an account/browser setting, not a device VPN.

PipeWire, WirePlumber, and pipewire-pulse handle audio. Volume, mute, microphone
mute, media transport, and brightness keys are configured. Brightness is a no-op
without a backlight interface. Touchpads use natural scrolling, tapping, and
disable-while-typing. A udev classification applies natural scrolling to mice,
excluding touchpads, tablets, and pointing sticks. Keyboard repeat is 200 ms/50 Hz.
The `Gaming Keyboard` (`1fc9:e8c7`) has its Command/Alt positions swapped per
device so its Command keys act as Super; the laptop keyboard keeps its normal
mapping. If connected, HDMI-2 mirrors eDP-1 at 1920×1080/60 Hz, including after
hotplug. Mirrored Xinerama rectangles are collapsed by the patched OXWM build
so the bar is not duplicated.

## Development

Run `dev` in a project directory:

```text
+--------------------------+--------------+
|                          | shell        |
| nvim .                   |              |
| ~65% width               +--------------+
|                          | fastfetch    |
|                          | then shell   |
+--------------------------+--------------+
```

All panes start in the physical project directory. Session names combine a safe
basename with a 12-character path hash, so equally named directories do not
collide. Repeated `dev` reattaches, and running it inside tmux switches clients
without nesting. The editor pane is selected on creation. Initial dimensions
come from the terminal/client, with a sensible detached fallback. fastfetch
uses its compact `arch_small` logo in the narrow pane. tmux's only supplied option is
`set -g mouse on`; stock Ctrl+B bindings and copy mode provide scrollback.
If you already have `~/.tmux.conf`, tmux may prefer it to the new XDG config.

st is built from upstream 0.9.3 with a local font/palette and reviewed patches.
It has 5000 lines of scrollback, mouse wheel and Shift+PageUp/PageDown navigation,
Shift+Home/End jumps, and underlined left-clickable HTTP(S) URLs. Alternate-screen
applications keep their own mouse scrolling. Ctrl+Shift+C/V copy/paste,
middle-click pastes PRIMARY, and Shift lets you select text when an application
such as tmux handles the mouse. tmux also has its own scrollback.

Minarch owns and maintains its Neovim configuration in `config/nvim`; see the
[editor notes](docs/NEOVIM.md). It uses LazyVim/lazy.nvim with Minarch's Seafoam
palette, keybindings, plugin specifications, and lockfile. First launch downloads
plugins, parsers, and Mason tools. To restore the locked plugin versions after
bootstrap/updates, close Neovim, copy the repository's `lazy-lock.json` back to
the installed config, and run
`nvim --headless '+Lazy! restore' '+qa!'`.

Codex comes from Arch **`openai-codex`**, now available in the official extra
repository. Run `codex --version`, then `codex` in a project and choose your
first-run authentication method. Browser authentication is manual; Minarch
stores no keys or credentials and installs no other AI agents or desktop keyring.
The package choice and current official guidance are recorded in
[upstream verification](docs/UPSTREAM.md).

Bash loads ble.sh when the pinned package is installed, adding syntax highlighting,
autosuggestions, and history search. If preserved startup files do not already expose user
commands on the TTY, add `export PATH="$HOME/.local/bin:$PATH"` to your own Bash
configuration. X sessions already export this PATH. JetBrains Mono Nerd Font,
basic Noto coverage, and Noto Emoji are the only requested font families.

## Updates and configuration ownership

Official packages follow supported Arch rolling updates:

```sh
sudo pacman -Syu
git -C ~/minarch pull --ff-only
cd ~/minarch && ./install.sh
```

Do not use partial Arch upgrades. This is reproducible configuration plus pinned
AUR/st inputs, not a frozen Arch package snapshot. Each installation records its
installed package versions in `~/.local/state/minarch/packages-installed.txt`.
For bit-identical OS packages, independently manage an Arch Linux Archive snapshot.

AUR recipe commits and OXWM/ble.sh source revisions are pinned in
`install/packages-aur`. Minarch builds them directly with makepkg; no AUR helper
is required. Build dependencies may remain installed, consuming disk rather than
idle CPU/RAM. To update AUR packages deliberately, review the new PKGBUILD, update
the manifest pins, adapt the microphone keysym patch if necessary, run
`test/validate-oxwm.sh`, and rerun the installer. AUR updates are not silently
fetched from an unreviewed moving branch. st's version/config/patch lives in `config/st`.
`yay` may be installed separately for manual AUR maintenance; it is not part of
Minarch's pinned install path.

Add official packages to `install/packages` and rerun. Removing a manifest entry
does not uninstall it from an existing system; review usage and use pacman
manually when removal is intended. [Package rationale](docs/PACKAGES.md) and
[service/performance review](docs/PERFORMANCE.md) explain every direct choice.

For all managed user/system config paths: absent files are installed; identical
contents are left alone; differing files are **preserved** by default. Explicit
`--replace-config` stages a complete copy first, then moves the previous file,
directory, or symlink to `<target>.backup.XXXXXXXX/original`. Backups are adjacent
to the target, printed to the terminal, and never duplicated for identical
contents on rerun. To restore, move the replacement aside, then move `original`
back to its original pathname (use sudo for `/etc`). Symlinks are moved as links.
The complete Neovim directory is one managed unit. Package-managed binaries are
updated through pacman rather than this config policy.

## Checks and troubleshooting

```sh
./test/check.sh                 # shellcheck, bash -n, isolated helper/tmux tests
./test/smoke.sh                 # installed-workstation checks
./scripts/smoke-test.sh --headless  # explicit Neovim bootstrap/startup check
./test/validate-oxwm.sh         # builds pinned OXWM and tests real parsed bindings
python test/x11.py             # optional: Xvfb + installed X11 tools
minarch-stats                  # on-demand system audit
```

The optional nested-X test needs `xorg-server-xvfb`, not installed by default.
The OXWM build test needs `zig` and its build dependencies (installed when OXWM
is built). No tests perform real suspend/reboot/poweroff or modify your main X
session. See [validation results and remaining hardware checks](docs/VALIDATION.md).

* **Xorg:** run `startx` from a local TTY, not sudo/SSH. Read
  `~/.local/share/xorg/Xorg.0.log` and `journalctl -b`. Check `/dev/dri`, `lspci -k`,
  and `xrandr`. Minarch uses kernel modesetting; no forced GPU Xorg config is
  generated. Intel/AMD use Mesa. With NVIDIA detected, an existing proprietary
  userspace is retained; otherwise Mesa plus the kernel's nouveau driver is the
  conservative default. Some GPUs need a separately selected vendor driver;
  see the hardware notes before installing one. Minarch does not guess generations.
* **OXWM:** run `oxwm --validate ~/.config/oxwm/config.lua` and inspect the startx
  output. The pinned Zig version has 66 configured bindings. One patch supplies
  XF86AudioMicMute and another merges duplicate mirrored screens; see upstream notes.
* **Session/lock:** inspect `journalctl --user -u minarch-lock.service` and
  `systemctl --user status minarch-session.target`. Confirm
  `systemctl --user show-environment` includes DISPLAY and XDG_SESSION_ID. The
  clipboard, hotplug, and Picom services stop with the session target when the
  lock process loses X. Test a full lock/unlock with Picom enabled.
* **st:** check `fc-match 'JetBrainsMono Nerd Font'`, UTF-8 locale (`locale`), and
  `infocmp st-256color` (supplied by Arch ncurses). Rebuild with `./install.sh`
  after changing `config/st/config.h` or its source patch.
* **Audio:** run `wpctl status`; inspect user PipeWire/WirePlumber units.
* **Networking:** keep your current stack; with NetworkManager use `nmcli`.
* **Microcode:** Minarch adds the appropriate CPU package but does not rewrite
  boot configuration. Verify your existing boot setup loads it; inspect
  `journalctl -k -b | grep -i microcode`.

Useful audit commands:

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

Deliberate omissions include Bluetooth, printing/discovery, automounting,
notifications, portals, privilege agents, keyrings, a firewall manager, sshd,
wallpaper processes, indexing, night mode, tuning daemons, and
unmeasured kernel/sysctl tweaks. Pre-existing user software is reported and
retained, so Minarch does not claim to remove background services you installed.
