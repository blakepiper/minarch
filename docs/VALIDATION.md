# Validation record

## 2026-09-18 repository sync

* `test/check.sh` passed shell syntax, shellcheck, 14 isolated workstation tests,
  and installed OXWM configuration validation.
* `test/validate-oxwm.sh` built the pinned source with both patches, ran its
  upstream and Minarch parser tests, and validated the 66-binding Lua config.
* `makepkg --cleanbuild --clean --noconfirm` built `st-minarch 0.9.3-3` from the
  upstream SHA-256-checked tarball plus the repo patch and config.
* The pinned `blesh-git` recipe and both source commits passed `makepkg
  --verifysource` and built version `0.4.0_devel4.r2350.d81fd54f-1`.
* `systemd-analyze --user verify` accepted the user target and services.
  Fastfetch loaded its new config. Xfe launched in an isolated Xvfb session
  with the sanitized dark theme config and retained its dark color keys.
* `test/x11.py` passed in an isolated Xvfb server extracted to a temporary
  directory. Real clipmenu and xclip preserved a PNG larger than 1 MiB while
  the private text probe was active; screenshots and OXWM layout/quit checks
  also passed.

No installer was run over the active workstation and no real lock/suspend was
triggered. After applying the new config, confirm Picom stops while locked and
resumes after unlocking, and verify the external device reconnect behavior.

## 2026-09-16 baseline

Implementation reviewed and tested on 2026-09-16. No full installation was run
over the existing desktop. Builds, configuration copies and nested displays
used temporary directories. No real lock, suspend, reboot, poweroff or package
installation was performed on the host.

### Passed

* `test/check.sh`: shellcheck and Bash syntax checks for installer/modules,
  helpers, session/Bash files, tests, and local st PKGBUILD. PKGBUILD metadata
  variables use makepkg's documented environment (shellcheck SC2034/SC2154
  excluded for that file only).
* 13 isolated tests: absent/same/different configuration, backup rerun behavior,
  dotfiles, dangling symlinks, complete user seeding, actual tmux pane geometry
  and project paths, reuse, same-basename session isolation, inside-tmux client
  switching, hardware package selection, screenshot exact-copy/cancel/error
  handling, menu confirmation/lock ordering, and startup sleep-inhibitor checks.
* `test/validate-oxwm.sh`: built pinned OXWM with Zig 0.16 and the one-line mic
  keysym patch. All 17 upstream + Minarch tests passed. The **actual parser**
  sees 65 unique bindings, including the mic key, all nine tag pairs and native
  stack/monitor directions. Its real `oxwm --validate` accepted the configuration.
* `test/x11.py`: real OXWM + st on an isolated Xvfb server. Full-screen, drag-region
  and focused-window captures saved the exact bytes retrieved from the X clipboard.
  Escape kept the clipboard and saved-image count unchanged. Real clipmenu
  restored selected text and preserved it on cancellation. Native OXWM hot reload
  and the exact control-menu quit bridge worked. No compositor was running.
* Local `st-minarch` PKGBUILD built successfully with makepkg as a normal user,
  producing `st-minarch-0.9.3-1-x86_64.pkg.tar.zst`. Archive inspection confirmed
  the binary, manual and license, without conflicting ncurses terminfo files.
* Neovim 0.12.5 starts headlessly with the imported LazyVim config and oxwm-like
  Seafoam palette. The initial fresh bootstrap was also checked with tree-sitter
  CLI present. Every restored plugin revision matched the original lockfile;
  intentionally injected Lua errors were rejected by the smoke test.
* The Blarchy tree was rechecked against current main
  `e295d5c4aa5f19bad15598262fc51df51711238d`; all files match except the explicitly
  requested palette customization and added `.minarch-source` metadata.
* Every official manifest package resolves in current Arch sync metadata. AUR
  recipe revisions, required official build dependencies, and upstream source
  pins were inspected. `makepkg --verifysource` also fetched Xfe 2.1.11 and
  verified its AUR-recorded SHA-256. Codex reports `codex-cli 0.154.0`.
* Firefox policy names, types and blocked enum value match both current Mozilla
  administrator documentation and the installed Firefox policy schema.
* `udevadm verify` accepts the mouse classification rule. systemd user unit
  syntax/dependencies validate when test executable paths point to extracted
  copies of the real X11 packages (the host does not have those tools installed
  under `/usr/bin`).

Real-X testing found and fixed two screenshot issues that mocked tests could
not reveal: maim needs explicit PNG format for an extensionless staging path,
and the forked clipboard owner must not retain the caller's output pipe.
Source/parser testing found the missing OXWM mic keysym and the embedded Lua
popen limitation. Session review added explicit logind session-ID forwarding
and a bounded check for the lock service's sleep inhibitor before launching OXWM.

### Installed-workstation smoke test

`test/smoke.sh` was run using an isolated seeded home and the real available or
locally built/extracted tools. It correctly reported three missing host tools:
`startx`, `xfe`, and a system `tree-sitter` command. All are supplied by the full
installer manifests. It did not claim that this host had undergone a full Minarch
installation; its exit status was 1. A separate real headless Neovim test with
the required parser CLI available passed. Live-session checks were skipped
because the installed smoke run intentionally had no DISPLAY.

Run `test/smoke.sh` again **after full installation**. It should pass on that
workstation, apart from explicitly reported checks requiring a live X session.
No tests are replaced with fake executable-presence claims.

### Still requires an installed physical workstation

* Full pacman/AUR install transaction on a fresh minimal Arch system.
* First startx from a real TTY, local logind session, user audio services, and
  correct cleanup of session units when X exits.
* XSecureLock password authentication, normal system/lid suspend, resume locking,
  and failure cases involving another application's keyboard/pointer grab.
* Actual GPU driver/renderer compatibility, acceleration, multi-monitor topology
  and hotplug. The default kernel/Mesa path is intentionally conservative.
* Touchpad/mouse/pointing-stick behavior, brightness permissions, volume/mic/media
  keys, and battery behavior on hardware with those interfaces.
* First-run Firefox policy/extension display, URL/MIME opening in the installed
  session, and manual Codex account authentication.

There are no claimed hardware idle RAM, CPU, boot-time, or power measurements.
Use `minarch-stats` and the protocol in PERFORMANCE.md for those measurements.
