-- Verified against tonybanters/oxwm fc4ada9ac4ee8e34ace203290a2b14d10e4671cc.
-- Lua actions are native OXWM operations; arrows mean stack/monitor order.
local mod = "Mod1"
oxwm.set_terminal("st")
oxwm.set_modkey(mod)
oxwm.set_tags({ "1", "2", "3", "4", "5", "6", "7", "8", "9" })
-- Dwindle gives new windows recursive Fibonacci-style splits instead of the
-- traditional master/stack arrangement.
oxwm.set_layout("dwindle")
-- OXWM stores the selected layout per workspace; initialize every workspace
-- explicitly so each tag starts in dwindle mode on every monitor.
for i = 1, 9 do
  oxwm.set_tag_layout(i, "dwindle")
end
oxwm.set_attach_method("bottom")

-- OXWM requires a color for custom status blocks. Use its default bar foreground.
local block_foreground = 0xbbbbbb
local blocks = {}
-- The X session detects the battery name once.
local battery = os.getenv("MINARCH_BATTERY")
if battery and battery:match("^[%w_%-]+$") then
  local probe = io.open("/sys/class/power_supply/" .. battery .. "/type", "r")
  if probe then
    local present = probe:read("*l") == "Battery"
    probe:close()
    if present then
      table.insert(blocks, oxwm.bar.block.battery({
        battery_name = battery,
        charging = "Bat +{}%",
        discharging = "Bat {}% {}",
        full = "Bat {}% full",
        interval = 30,
        color = block_foreground,
        underline = true,
        click = "blix-settings-apply power-menu",
      }))
    end
  end
end
table.insert(blocks, oxwm.bar.block.shell({
  format = "Vol {}",
  command = "oxwm-volume",
  interval = 0,
  refresh_property = "_MINARCH_VOLUME",
  color = block_foreground,
  underline = true,
  click = {
    command = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ {}%",
    slider = { label = "Volume", min = 0, max = 100 },
  },
}))
local brightness = os.getenv("MINARCH_BRIGHTNESS")
if brightness == "backlight" or brightness == "ddc" then
  table.insert(blocks, oxwm.bar.block.shell({
    format = "Bri {}",
    command = brightness == "ddc" and "minarch-monitor-brightness" or "oxwm-brightness",
    interval = 0,
    refresh_property = "_MINARCH_BRIGHTNESS",
    color = block_foreground,
    underline = true,
    click = {
      command = brightness == "ddc" and "minarch-monitor-brightness {}"
        or "brightnessctl --class=backlight --min-value=1 set {}%",
      slider = { label = "Brightness", min = 1, max = 100 },
    },
  }))
end
table.insert(blocks, oxwm.bar.block.datetime({
  format = "{}",
  date_format = "%a, %b %d - %H:%M",
  interval = 60,
  color = block_foreground,
  underline = true,
}))
oxwm.bar.set_blocks(blocks)

-- All OXWM bindings live in this file. OXWM reload/restart is intentionally
-- not bound to any key; edit this file and restart OXWM from a shell when
-- changing bindings.
oxwm.key.bind({ mod }, "Space", oxwm.spawn("rofi -show drun -show-icons -display-drun Apps -terminal st"))
oxwm.key.bind({ mod }, "D", oxwm.spawn("dmenu_run"))
oxwm.key.bind({ mod }, "F", oxwm.spawn("thunar"))
oxwm.key.bind({ mod }, "B", oxwm.spawn("firefox"))
oxwm.key.bind({ mod }, "S", oxwm.spawn("blix-settings"))
oxwm.key.bind({ mod }, "P", oxwm.client.toggle_floating())
oxwm.key.bind({ mod }, "C", oxwm.layout.set("tiling"))
oxwm.key.bind({ mod }, "R", oxwm.layout.set("dwindle"))
oxwm.key.bind({ mod, "Shift" }, "F", oxwm.client.toggle_fullscreen())
-- Previous numbered tag, not a most-recently-used tag toggle.
oxwm.key.bind({ mod }, "Tab", oxwm.tag.view_previous())
for i = 1, 9 do
  oxwm.key.bind({ mod }, tostring(i), oxwm.tag.view(i - 1))
  oxwm.key.bind({ mod, "Shift" }, tostring(i), oxwm.tag.move_to(i - 1))
end
for _, key in ipairs({ "Left", "Up" }) do
  oxwm.key.bind({ mod }, key, oxwm.client.focus_stack(-1))
  oxwm.key.bind({ mod, "Shift" }, key, oxwm.client.move_stack(-1))
  oxwm.key.bind({ mod, "Control" }, key, oxwm.monitor.focus(-1))
  oxwm.key.bind({ mod, "Control", "Shift" }, key, oxwm.monitor.tag(-1))
end
for _, key in ipairs({ "Right", "Down" }) do
  oxwm.key.bind({ mod }, key, oxwm.client.focus_stack(1))
  oxwm.key.bind({ mod, "Shift" }, key, oxwm.client.move_stack(1))
  oxwm.key.bind({ mod, "Control" }, key, oxwm.monitor.focus(1))
  oxwm.key.bind({ mod, "Control", "Shift" }, key, oxwm.monitor.tag(1))
end
oxwm.key.bind({ mod }, "minus", oxwm.set_master_factor(-50))
oxwm.key.bind({ mod }, "equal", oxwm.set_master_factor(50))
oxwm.key.bind({ mod, "Shift" }, "minus", oxwm.inc_num_master(-1))
oxwm.key.bind({ mod, "Shift" }, "equal", oxwm.inc_num_master(1))
oxwm.key.bind({ mod }, "N", oxwm.layout.cycle())
-- The control menu sends this native quit binding after confirmation. OXWM
-- currently has no external quit IPC. No window geometry is simulated.
oxwm.key.bind({ mod, "Shift" }, "Q", oxwm.quit())
oxwm.key.bind({ mod, "Shift" }, "S", oxwm.spawn("minarch-notify-failure 'Screenshot failed' screenshot-region"))
oxwm.key.bind({}, "Print", oxwm.spawn("minarch-notify-failure 'Screenshot failed' screenshot-region --full"))
oxwm.key.bind({ "Mod1" }, "Print", oxwm.spawn("minarch-notify-failure 'Screenshot failed' screenshot-region --window"))
oxwm.key.bind({ mod }, "V", oxwm.spawn("minarch-notify-failure 'Clipboard history unavailable' clipboard-history"))
oxwm.key.bind({ mod }, "L", oxwm.spawn("minarch-notify-failure 'Could not lock screen' minarch-lock"))
oxwm.key.bind({ mod, "Shift" }, "Space", oxwm.spawn("minarch-notify-failure 'Session action failed' control-menu"))
oxwm.key.bind({}, "XF86AudioRaiseVolume", oxwm.spawn("minarch-notify-failure 'Volume change failed' wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
oxwm.key.bind({}, "XF86AudioLowerVolume", oxwm.spawn("minarch-notify-failure 'Volume change failed' wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
oxwm.key.bind({}, "XF86AudioMute", oxwm.spawn("minarch-notify-failure 'Mute change failed' wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
oxwm.key.bind({}, "XF86AudioMicMute", oxwm.spawn("minarch-notify-failure 'Microphone mute change failed' wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
oxwm.key.bind({}, "XF86AudioPlay", oxwm.spawn("minarch-notify-failure 'Playback control failed' playerctl play-pause"))
oxwm.key.bind({}, "XF86AudioNext", oxwm.spawn("minarch-notify-failure 'Next track failed' playerctl next"))
oxwm.key.bind({}, "XF86AudioPrev", oxwm.spawn("minarch-notify-failure 'Previous track failed' playerctl previous"))
oxwm.key.bind({}, "XF86MonBrightnessUp", oxwm.spawn("minarch-notify-failure 'Brightness change failed' minarch-brightness up"))
oxwm.key.bind({}, "XF86MonBrightnessDown", oxwm.spawn("minarch-notify-failure 'Brightness change failed' minarch-brightness down"))

-- Core terminal/window bindings.
oxwm.key.bind({ mod }, "Return", oxwm.spawn_terminal())
oxwm.key.bind({ mod }, "Q", oxwm.client.kill())
