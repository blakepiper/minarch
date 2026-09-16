# Actual Minarch bindings

Super means Mod4; Alt means Mod1. The source of truth is `config/oxwm/config.lua`.
These are native OXWM actions except application/helper launches. No spatial
geometry is emulated. OXWM was inspected at `fc4ada9ac4ee8e34ace203290a2b14d10e4671cc`.

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
| Super+Shift+R | Native config hot reload |
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

The arrows express **order**, not geometric direction or monitor topology.
Stack operations skip windows according to OXWM's native visibility/floating
rules. The default is tiling. The inspected source cycles tiling, monocle,
floating, scrolling, grid, and dwindle; it does not currently expose the older
tabbed layout. Minarch does not emulate it. Scrolling is merely an optional
upstream layout in the cycle; the initial tiling layout has no animation. There
is no current Lua animation toggle, and no compositor is installed.

OXWM's internal `set_master_factor` argument is scaled by 1/1000, so Minarch uses
±50 for 5 percentage points. Parsed-binding tests cover all 65 bindings and
ensure no duplicate key/modifier combinations.

`dev` is a project command, not a global keybinding. Super+Shift+Enter is unbound.
There is no night-mode binding or helper. Existing Neovim keybindings and stock
tmux prefix bindings are unchanged.

Control-menu logout sends exactly `super+shift+q` with xdotool after confirmation:
this dispatches `oxwm.quit()` because the inspected upstream has no external quit
IPC. xdotool is already a clipmenu dependency. This narrow bridge does not move
windows, imitate directional operations, or kill unrelated processes. The nested
X test exercises the exact quit sequence.
