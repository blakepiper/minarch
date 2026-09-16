// Appended to upstream tests/lua_config_tests.zig by validate-oxwm.sh.
// Exercises the real parser, which otherwise silently ignores unknown keysyms.
test "Minarch parses every binding including microphone mute" {
    var cfg = Config.init(testing.allocator);
    defer cfg.deinit();
    try testing.expect(lua.init(&cfg));
    defer lua.deinit();
    try testing.expect(lua.loadFile("minarch-config/config.lua"));
    try testing.expectEqual(@as(usize, 65), cfg.keybinds.items.len);
    const Expected = struct { key: u64, mask: u32, action: lua.config_mod.Action };
    const expected = [_]Expected{
        .{ .key = 0xff0d, .mask = 64, .action = .spawn_terminal },
        .{ .key = 'f', .mask = 64, .action = .spawn },
        .{ .key = 0x20, .mask = 64, .action = .spawn },
        .{ .key = 'b', .mask = 64, .action = .spawn },
        .{ .key = 'q', .mask = 65, .action = .quit },
        .{ .key = 0x1008ffb2, .mask = 0, .action = .spawn },
        .{ .key = 0xff51, .mask = 64, .action = .focus_next },
        .{ .key = 0xff53, .mask = 64, .action = .focus_next },
        .{ .key = 0xff51, .mask = 65, .action = .move_next },
        .{ .key = 0xff53, .mask = 65, .action = .move_next },
        .{ .key = 0xff51, .mask = 68, .action = .focus_monitor },
        .{ .key = 0xff53, .mask = 69, .action = .send_to_monitor },
    };
    for (expected) |want| {
        var found = false;
        for (cfg.keybinds.items) |binding| {
            if (binding.keys[0].keysym == want.key and binding.keys[0].mod_mask == want.mask) {
                try testing.expectEqual(want.action, binding.action);
                if (want.key == 0xff51 and (want.mask == 64 or want.mask == 65 or want.mask == 68)) {
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
            if (binding.keys[0].mod_mask == 64 and binding.action == .view_tag) view = true;
            if (binding.keys[0].mod_mask == 65 and binding.action == .move_to_tag) move = true;
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
