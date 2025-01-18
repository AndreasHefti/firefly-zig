const std = @import("std");
pub const firefly = @import("inari/firefly/firefly.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const init_context = firefly.api.InitContext{
        .allocator = allocator,
        .entity_allocator = allocator,
        .component_allocator = allocator,
    };

    try @import("examples/HelloFirefly.zig").run(init_context);
    // try @import("examples/HelloIntro.zig").run(init_context);
    // try @import("examples/HelloSpriteFlip.zig").run(init_context);
    // try @import("examples/HelloSprite.zig").run(init_context);
    // try @import("examples/HelloWindow.zig").run(init_context);
    // try @import("examples/HelloMultiViewport.zig").run(init_context);
    // try @import("examples/HelloBehavior.zig").run(init_context);
    // try @import("examples/HelloShader.zig").run(init_context);
    // try @import("examples/HelloSpriteAnimation.zig").run(init_context);
    // try @import("examples/SpriteMultiply.zig").run(init_context);
    // try @import("examples/HelloViewport.zig").run(init_context);
    // try @import("examples/HelloShape.zig").run(init_context);
    // try @import("examples/RenderSpeedRaw.zig").run(init_context);
    // try @import("examples/EasingExample.zig").run(init_context);
    // try @import("examples/HelloBezier.zig").run(init_context);
    // try @import("examples/RenderSpeed.zig").run(init_context);
    // try @import("examples/HelloTileGrid.zig").run(init_context);
    // try @import("examples/HelloGravity.zig").run(init_context);
    // try @import("examples/InputExample1.zig").run(init_context);
    // try @import("examples/StateExample2.zig").run(init_context);
    // try @import("examples/HelloContact.zig").run(init_context);
    // try @import("examples/HelloCamera.zig").run(init_context);
    // try @import("examples/HelloTileSet.zig").run(init_context);
    // try @import("examples/HelloTileMap.zig").run(init_context);
    // try @import("examples/HelloRoom.zig").run(init_context);
    // try @import("examples/HelloPlayer.zig").run(init_context);
    // try @import("examples/HelloPlatformer.zig").run(init_context);

    // try @import("examples/HelloTiledTileSet.zig").run(init_context);
    // try @import("examples/HelloTiledRoom.zig").run(init_context);
}
