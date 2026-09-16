# Upstream verification (2026-09-16)

## OXWM

Inspected [current source and Lua template](https://github.com/tonybanters/oxwm/tree/fc4ada9ac4ee8e34ace203290a2b14d10e4671cc)
and the actual AUR recipe (`24d89c879ab09e3ca506082b4bc9b624b5456718`). The
[AUR oxwm-git package](https://aur.archlinux.org/packages/oxwm-git) builds the
current Zig implementation with Zig 0.16. The obsolete Cargo recipe still inside
upstream `resources/PKGBUILD` is not used. Both the recipe and source are pinned
in Minarch's manifest. `oxwm --validate <path>` and `zig build test` exist.

Every Lua function used by Minarch exists in `src/config/lua.zig`; actual parser
tests verify all 65 bindings, actions, directions, tag indices and uniqueness.
The built-in keysym table omitted `XF86AudioMicMute`; the one-line patch in
`config/oxwm-patches` adds the standard X11 keysym `0x1008ffb2`. This is the only
local OXWM source change. Native focus/move-stack actions carry a ±1 argument;
master resizing scales its integer by 1/1000. The current embedded Lua lacks
io.popen, so sysfs battery discovery is done once by the X session, with its
actual battery name passed to Lua. There is no external quit IPC; a confirmed
menu uses the dedicated native quit binding. See KEYBINDS for exact semantics.

## Arch / AUR / terminal

Arch sync metadata confirms all names in `install/packages`. Current external
package records:

* [openai-codex in extra](https://archlinux.org/packages/extra/x86_64/openai-codex/):
  0.154.0-1 at inspection; preferred over the still-existing AUR binary package.
* [xfe](https://aur.archlinux.org/packages/xfe): 2.1.11-1, not stale xfe-arch;
  reviewed recipe commit `4599382c246a71d21708a5aeb5c73d0b821e8fab`.
* [st release](https://dl.suckless.org/st/st-0.9.3.tar.gz): 0.9.3,
  SHA-256 `9ed9feabcded713d4ded38c8cebf36a3b08f0042ef7934a0e2b2409da56e649b`.
  Its [upstream configuration](https://git.suckless.org/st/file/config.def.h.html)
  already provides selection and clipboard shortcuts. No patches are needed.
* Official packages provide slock, xsecurelock, xss-lock, clipmenu, feh, and
  firefox-ublock-origin. `fox` and `intltool` required by Xfe are official packages.

Arch is rolling. These verification versions document the review; the official
manifest deliberately follows current supported repository packages rather than
pinning unsupported partial-upgrade versions. The installer records resolved
versions locally after installation.

## Codex

The [current official Codex CLI guide](https://learn.chatgpt.com/docs/codex/cli)
was fetched using the OpenAI Docs skill. It supports Linux and describes a
standalone installer as well as npm/Homebrew alternatives. Minarch uses Arch's
maintained `openai-codex` package instead of curl-pipe-shell or an unnecessary
Node runtime. `codex --version` returned `codex-cli 0.154.0` in the implementation
environment. Authentication stays an explicit first-run browser/sign-in step.

## Firefox

Validated keys against the **current Firefox administrator reference**, to which
the old policy-templates site now redirects readers:

* [FirefoxHome](https://firefox-admin-docs.mozilla.org/reference/policies/firefoxhome/):
  `SponsoredTopSites`, `Stories`, `SponsoredStories` are Boolean properties.
* [FirefoxSuggest](https://firefox-admin-docs.mozilla.org/reference/policies/firefoxsuggest/):
  `SponsoredSuggestions` is Boolean.
* [AIControls](https://firefox-admin-docs.mozilla.org/reference/policies/aicontrols/):
  `Default` is an object with `Value: "blocked"` and `Locked: true`.

The policy is also checked against the installed Firefox policy schema during
implementation. System-wide policy goes to `/etc/firefox/policies/policies.json`;
see [Mozilla's policy placement documentation](https://mozilla.github.io/policy-templates/).
Arch's `firefox-ublock-origin` package provides extension maintenance.

## Clipboard, lock, input and audio

* [clipmenu](https://github.com/cdown/clipmenu): inspected actual Arch 6.2.0
  scripts. Uses clipnotify/X selection events; text history only. `CM_SELECTIONS`
  is clipboard-only, ownership is not forced (so images aren't overwritten),
  `CM_MAX_CLIPS=100`, and dmenu is the launcher.
* [XSecureLock integration](https://github.com/google/xsecurelock#automatic-locking):
  requires xss-lock's `-l` readiness handoff for suspend. The Arch xss-lock man
  page and example user unit require explicit `--session ${XDG_SESSION_ID}` when
  launched by the user service manager. slock is smaller, but XSecureLock directly
  supports this protocol. Only blank locking is used; no saver framework.
* [Xorg InputClass](https://www.x.org/releases/current/doc/man/man5/xorg.conf.5.xhtml)
  supports MatchTag; the [actual udev backend](https://github.com/mirror/xserver/blob/master/config/udev.c)
  reads `ID_INPUT.tags`. A small classification rule excludes pointing sticks
  instead of treating every pointer as a mouse.
* The current installed `wpctl --help`/`wpctl set-volume --help` and WirePlumber
  command syntax support default sink/source identifiers, relative percentages,
  `set-mute ... toggle` and a volume limit. No audio GUI or Bluetooth tools.

ArchWiki GPU pages were access-protected in the browsing environment. Minarch
therefore does not claim verified generation-specific NVIDIA mapping. It uses
normal modesetting and preserves an installed vendor userspace; the fallback is
the in-kernel nouveau driver/Mesa. This is explicitly documented as a hardware
compatibility check for the installed workstation, not a universal performance
claim. No unsupported hardware-specific heuristics are embedded.

## Power authorization

The [actual systemd logind policy](https://github.com/systemd/systemd/blob/main/src/login/org.freedesktop.login1.policy)
authorizes poweroff/reboot/suspend for the active local user through polkit.
The [systemd Arch guidance](https://wiki.archlinux.org/title/Systemd#Power_management)
identifies polkit as necessary for unprivileged power management. Minarch therefore
includes the backend package, which is D-Bus activated; it installs no graphical
agent, custom allow-all rules, or passwordless sudoers entries. This is a concrete
core workflow dependency, not optional desktop infrastructure added speculatively.
