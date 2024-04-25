const std = @import("std");
const inari = @import("inari/inari.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const init_context = inari.firefly.api.InitContext{
        .allocator = allocator,
        .entity_allocator = allocator,
        .component_allocator = allocator,
        .run_on_low_level_api = inari.firefly.api.RUN_ON.RAYLIB,
    };

    try @import("examples/HelloFirefly.zig").run(init_context);

    try @import("examples/HelloSprite.zig").run(init_context);
    try @import("examples/SpriteMultiply.zig").run(init_context);
    try @import("examples/HelloViewport.zig").run(init_context);
    try @import("examples/HelloShape.zig").run(init_context);
    // try @import("examples/RenderSpeedRaw.zig").run(init_context);
    // try @import("examples/EasingExample.zig").run(init_context);
    // try @import("examples/RenderSpeed.zig").run(init_context);
    // try @import("examples/HelloTileGrid.zig").run(init_context);
    // try @import("examples/HelloGravity.zig").run(init_context);
    // try @import("examples/InputExample1.zig").run(init_context);
    // try @import("examples/StateExample2.zig").run(init_context);
}

test "API Tests" {
    std.testing.refAllDecls(@import("inari/libtest.zig"));
}
