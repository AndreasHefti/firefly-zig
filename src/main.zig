const std = @import("std");
pub const firefly = @import("inari/firefly/firefly.zig");

pub fn main(init: std.process.Init) !void {
    // var gpa = std.heap.DebugAllocator(.{}).init;
    // const allocator = gpa.allocator();
    // defer _ = gpa.deinit();

    // const init_context = firefly.api.InitContext{
    //     .allocator = init.gpa,
    //     .entity_allocator = init.gpa,
    //     .component_allocator = init.gpa,
    // };

    try @import("examples/HelloFirefly.zig").run(init);
    try @import("examples/HelloIntro.zig").run(init);
    try @import("examples/HelloSpriteFlip.zig").run(init);
    try @import("examples/HelloSprite.zig").run(init);
    try @import("examples/HelloWindow.zig").run(init);
    try @import("examples/HelloMultiViewport.zig").run(init);
    try @import("examples/HelloBehavior.zig").run(init);
    try @import("examples/HelloShader.zig").run(init);
    try @import("examples/HelloSpriteAnimation.zig").run(init);
    try @import("examples/SpriteMultiply.zig").run(init);
    try @import("examples/HelloViewport.zig").run(init);
    try @import("examples/HelloShape.zig").run(init);
    try @import("examples/RenderSpeedRaw.zig").run(init);
    try @import("examples/EasingExample.zig").run(init);
    try @import("examples/HelloBezier.zig").run(init);
    try @import("examples/RenderSpeed.zig").run(init);
    try @import("examples/HelloTileGrid.zig").run(init);
    try @import("examples/HelloGravity.zig").run(init);
    try @import("examples/InputExample1.zig").run(init);
    try @import("examples/StateExample2.zig").run(init);
    try @import("examples/HelloContact.zig").run(init);
    try @import("examples/HelloCamera.zig").run(init);
    try @import("examples/HelloTileSet.zig").run(init);
    try @import("examples/HelloTileMap.zig").run(init);
    try @import("examples/HelloRoom.zig").run(init);
    try @import("examples/HelloPlayer.zig").run(init);
    try @import("examples/HelloPlatformer.zig").run(init);

    try @import("examples/HelloTiledTileSet.zig").run(init);
    try @import("examples/HelloTiledRoom.zig").run(init);
}
