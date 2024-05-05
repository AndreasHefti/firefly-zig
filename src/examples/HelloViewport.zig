const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const EView = firefly.graphics.EView;
const ESprite = firefly.graphics.ESprite;
const Allocator = std.mem.Allocator;
const View = firefly.graphics.View;
const BlendMode = firefly.api.BlendMode;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello View", loadWithView);
}

fn loadWithView() void {
    const viewId = View.new(.{
        .name = "TestView",
        .order = 1,

        // transform is used when rendering the texture to the screen (or another texture)
        .position = .{ 10, 10 },
        .pivot = .{ 0, 0 },
        .scale = .{ 1, 1 },
        .rotation = 0,

        // render_data that is used when rendering the texture to the screen (or another texture)
        .tint_color = .{ 255, 255, 255, 150 },
        .blend_mode = BlendMode.ALPHA,

        // projection is used when rendering to the texture.
        // Can be seen as the camera of the texture
        .projection = .{
            .clear_color = .{ 30, 30, 30, 255 },
            .plain = .{ -10, -10, 200, 200 },
            .pivot = .{ 0, 0 },
            .zoom = 2,
            .rotation = 0,
        },
    });
    View.activateById(viewId, true);

    const sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
        .flip_x = true,
        .flip_y = true,
    });

    Texture.newAnd(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    _ = Entity.newAnd(.{ .name = "TestEntity" })
        .with(ETransform{})
        .with(EView{ .view_id = viewId })
        .with(ESprite{ .template_id = sprite_id })
        .activate();
}
