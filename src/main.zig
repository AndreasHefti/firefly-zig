const std = @import("std");
const inari = @import("inari/inari.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // try @import("examples/HelloSprite.zig").run(allocator);
    // try @import("examples/SpriteMultiply.zig").run(allocator);
    // try @import("examples/HelloViewport.zig").run(allocator);
    // try @import("examples/HelloShape.zig").run(allocator);
    try @import("examples/RenderSpeedRaw.zig").run(allocator);
    try @import("examples/RenderSpeed.zig").run(allocator);
    try @import("examples/HelloTileGrid.zig").run(allocator);
}

test "API Tests" {
    std.testing.refAllDecls(@import("inari/libtest.zig"));
}
