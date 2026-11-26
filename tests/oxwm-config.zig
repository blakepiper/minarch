// Appended to upstream tests/lua_config_tests.zig by validate-oxwm.sh.
// Exercises the real parser, which otherwise silently ignores unknown keysyms.
test "Minarch parses every binding including microphone mute" {
    var cfg = Config.init(testing.allocator);
    defer cfg.deinit();
    try testing.expect(lua.init(&cfg));
    defer lua.deinit();
    try testing.expect(lua.loadFile("minarch-config/config.lua"));
    try testing.expectEqual(@as(usize, 67), cfg.keybinds.items.len);
    const alt = 1 << 3;
    const shift = 1 << 0;
    const control = 1 << 2;
    const Expected = struct { key: u64, mask: u32, action: lua.config_mod.Action };
    const expected = [_]Expected{
        .{ .key = 0xff0d, .mask = alt, .action = .spawn_terminal },
        .{ .key = 'f', .mask = alt, .action = .spawn },
        .{ .key = 0x20, .mask = alt, .action = .spawn },
        .{ .key = 'b', .mask = alt, .action = .spawn },
        .{ .key = 's', .mask = alt, .action = .spawn },
        .{ .key = 'q', .mask = alt | shift, .action = .quit },
        .{ .key = 0x1008ffb2, .mask = 0, .action = .spawn },
        .{ .key = 0xff51, .mask = alt, .action = .focus_next },
        .{ .key = 0xff53, .mask = alt, .action = .focus_next },
        .{ .key = 0xff51, .mask = alt | shift, .action = .move_next },
        .{ .key = 0xff53, .mask = alt | shift, .action = .move_next },
        .{ .key = 0xff51, .mask = alt | control, .action = .focus_monitor },
        .{ .key = 0xff53, .mask = alt | control | shift, .action = .send_to_monitor },
    };
    for (expected) |want| {
        var found = false;
        for (cfg.keybinds.items) |binding| {
            if (binding.keys[0].keysym == want.key and binding.keys[0].mod_mask == want.mask) {
                try testing.expectEqual(want.action, binding.action);
                if (want.key == 0xff51 and (want.mask == alt or want.mask == (alt | shift) or want.mask == (alt | control))) {
                    try testing.expectEqual(@as(i32, -1), binding.int_arg);
                }
                found = true;
            }
        }
        try testing.expect(found);
    }
    for (0..9) |index| {
        var view = false;
        var move = false;
        for (cfg.keybinds.items) |binding| {
            if (binding.keys[0].keysym != '1' + index) continue;
            try testing.expectEqual(@as(i32, @intCast(index)), binding.int_arg);
            if (binding.keys[0].mod_mask == alt and binding.action == .view_tag) view = true;
            if (binding.keys[0].mod_mask == (alt | shift) and binding.action == .move_to_tag) move = true;
        }
        try testing.expect(view and move);
    }
    // No duplicate bindings can shadow requested actions.
    for (cfg.keybinds.items, 0..) |a, i| {
        for (cfg.keybinds.items[i + 1 ..]) |b| {
            try testing.expect(a.keys[0].keysym != b.keys[0].keysym or a.keys[0].mod_mask != b.keys[0].mod_mask);
        }
    }
}
