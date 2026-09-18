# Package review

Reviewed 2026-09-18 against the installed workstation and pinned AUR recipes. Every direct
package below supplies a requested function. None is selected merely because a
previous desktop used it. See `install/packages` and `install/packages-aur`.
Dependencies installed by pacman can include shared libraries for multiple
graphical platforms; their presence is not a configured desktop or running daemon.

| Purpose | Direct official packages | Rationale / persistent activity |
| --- | --- | --- |
| X server/session | xorg-server, xorg-xinit, xf86-input-libinput, xorg-xauth | Xorg, startx and input; no display manager |
| X configuration/inspection | xorg-xset, xorg-xsetroot, xorg-setxkbmap, xorg-xkbcomp, xorg-xrandr, xorg-xprop, xorg-xdpyinfo | Keyboard remapping, display setup, DPMS, and inspection; xdpyinfo is also used by startx |
| URL/MIME opening | xdg-utils | Browser authentication links and MIME defaults without a DE |
| Browser | firefox, firefox-ublock-origin | Only full GUI browser; normal acceleration; packaged extension updates |
| Launcher/media | dmenu, mpv, feh | Immediate command search; on-demand playback/image viewing |
| Project workflow | git, openssh, neovim, tmux, fastfetch, lazygit | Requested editor, sessions, compact system display, Git tools and SSH client; sshd never enabled |
| CLI tools | ripgrep, fd, fzf, curl, jq, bat, eza, btop, less, man-db, unzip, bash-completion | Explicitly requested tools; no background services |
| Builds/checks | base-devel, shellcheck, libx11, libxft, libxext, fontconfig | AUR/st compilation and repo checks; gcc/make/patch come from base-devel |
| Editor bootstrap | tree-sitter-cli, tar, gzip | Locked Treesitter parser generation and Mason extraction; no blanket language runtimes |
| Codex | openai-codex | Maintained official Arch binary package; no AUR/npm/Node requirement |
| Screenshots | maim, slop, xclip | Region capture, selection, exact PNG X clipboard ownership |
| Clipboard | clipmenu | dmenu text history; its small clipnotify/xsel/xdotool dependencies serve X selections; event-driven watcher |
| Lock/suspend | xsecurelock, xss-lock | Secure X locker with logind readiness handoff; no idle animation or screenshot background |
| Compositor | picom | Window transparency with an opaque YouTube exception; stopped during XSecureLock |
| Power authorization | polkit | Required logind backend for normal-user suspend/reboot/poweroff; D-Bus activated, no GUI agent or custom rules |
| Audio | pipewire, wireplumber, pipewire-pulse | Reliable normal application audio; only intentional audio user services |
| Media keys | playerctl | On-demand MPRIS transport commands |
| Fonts | ttf-jetbrains-mono-nerd, noto-fonts, noto-fonts-emoji | Requested coding font, basic multilingual/emoji coverage |
| Audit | mesa-utils, pciutils, psmisc | glxinfo, lspci and pstree; on demand |

`xdotool` is a transitive clipmenu dependency. Minarch only uses it for the
confirmed native OXWM quit binding; no geometric window automation is present.
`mesa-utils` can pull Mesa libraries for its diagnostics; no unrelated GPU kernel
driver is installed. The installer does not control optional package dependencies.

## Hardware-conditional packages

* `intel-ucode` or `amd-ucode`: selected by CPU vendor; neither rewrites Minarch's
  boot config because Minarch has none. Existing boot integration must load it.
* `mesa`: selected for Intel/AMD display controllers; also for NVIDIA when no
  existing `nvidia-utils` is installed. NVIDIA's conservative default is the
  in-kernel nouveau driver with Mesa. Current proprietary drivers differ by GPU
  support; Minarch does not guess legacy generations or overwrite an existing
  driver choice. If nouveau cannot support your GPU, install the current
  appropriate Arch driver separately before starting X. No forced DDX or
  xf86-video-intel is installed.
* `brightnessctl`: selected only when sysfs exposes a backlight. The binding
  skips absent interfaces; a minimum of 1 avoids accidentally turning the panel
  fully dark.
* `intel-media-driver`, `libva-utils`: selected for the documented Whiskey Lake
  UHD 620 PCI ID `8086:3ea0`; other Intel generations need their own VA-API
  driver choice.

## Reviewed AUR and local builds

| Package | Source | Why |
| --- | --- | --- |
| oxwm-git | Reviewed AUR recipe + pinned upstream source | Required WM; built with Zig 0.16, not the obsolete Cargo recipe still present inside upstream resources |
| xfe | Maintained AUR xfe 2.1.11 | Explicit file-manager requirement; FOX toolkit rather than a DE |
| blesh-git | Reviewed AUR recipe + pinned ble.sh and contrib commits | Interactive Bash highlighting, autosuggestions and history search |
| st-minarch | Local PKGBUILD, upstream st 0.9.3 tarball with SHA-256 | Font/palette, 5000-line scrollback, mouse support and clickable URLs |

Two OXWM patches are applied: registering the standard XF86AudioMicMute keysym
and collapsing duplicate Xinerama rectangles from mirrored monitors before
creating bars. All actions remain upstream actions.
The AUR recipe is fetched at its recorded commit, and oxwm's Git source is pinned
before makepkg runs. The package-build cache records recipe/source/config identity
and installed version to make reruns cheap and resume partial failures. Temporary
build directories are cleaned. No makepkg command runs as root. No AUR helper is
required, so there is no yay bootstrap or extra Go toolchain solely for it. An
existing yay installation is left alone.

AUR build dependencies (such as Zig, FOX, intltool and X libraries) are resolved
by makepkg/pacman. They do not start services. Package inspection may show Lua,
Python, Wayland protocol libraries, or other transitive libraries; none causes a
Wayland session or a blanket programming-language tooling install. Mason handles
Lua language server and editor-specific formatters using the imported config.

`ncurses` supplies st/st-256color terminfo. The local st package does not run
upstream's unscoped `tic` install command or overwrite ncurses-owned terminfo.

## Deliberate exclusions

No Bluetooth packages; no printer/discovery/modem stack; no DE,
secondary bar, GUI privilege agent, portal, keyring, automounter, notification
server, extra browser/AI agent, firewall manager, shell framework, terminal
framework, nightly color helper, or daemon-based tuning tool. Nothing installs
or enables a competing network manager. Existing packages are never automatically
removed simply because they are outside this list.
