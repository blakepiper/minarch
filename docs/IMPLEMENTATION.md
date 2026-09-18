# Minarch v1 initial implementation plan (2026-09-16)

This records the original baseline. The 2026-09-18 workstation sync added the
patched OXWM and st builds, Picom with lock integration, hotplug handling, and
other current settings documented in the README and validation record.

1. Verify current OXWM Lua APIs/validator, Arch/AUR packaging, Firefox policies,
   Codex installation, X11 clipboard/locking, and upstream st. Record revisions.
2. Keep the existing Neovim behavior, including the user-requested oxwm palette
   adaptation. No other editor redesign.
3. Separate official packages, pinned AUR recipes, hardware detection, safe file
   installation, system setup, and user setup. Preserve existing configs by
   default; explicit replacement backs up once per actual change.
4. Build stock st 0.9.3 with a local font/palette config. Use native OXWM actions,
   its own bar, Xorg modesetting/libinput, and manual startx from a Bash login.
5. Add screenshots, clipmenu, XSecureLock + xss-lock, control menu, exact three-pane
   dev workspace, MIME defaults, Firefox policies, and on-demand diagnostics.
6. Run shellcheck, shell syntax checks, isolated helper/installer/tmux tests,
   OXWM's real validator and upstream tests, and headless Neovim. Exercise X11
   in a nested server if available. Record hardware/session-only test limits.
7. Audit every direct package and enabled service, document use and omissions,
   search for stale runtime dependencies, and commit the complete implementation.

Decisions: Codex is now in Arch extra (`openai-codex`). Xfe and oxwm-git remain
AUR packages; direct pinned makepkg builds need no AUR helper. Use feh only as
an on-demand X11 image viewer. Network ownership is untouched. Manual startx
avoids shell-profile modifications and login loops. xss-lock is the deliberate
small extra process for locking on system suspend; no idle lock is configured.

Final dependency review: include the D-Bus-activated polkit backend because
logind's normal-user power menu requires it. No GUI authentication agent or
custom privilege rules. Xfe's reviewed source archive checksum was verified.
