const std = @import("std");
const inari = @import("../inari/inari.zig");
const firefly = inari.firefly;
const utils = inari.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const Allocator = std.mem.Allocator;
const View = firefly.graphics.View;
const BlendMode = firefly.api.BlendMode;

pub fn run(allocator: Allocator) !void {
    try firefly.init(
        allocator,
        allocator,
        allocator,
        firefly.api.InitMode.DEVELOPMENT,
    );
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello View", loadWithView);
}

fn loadWithView() void {
    var viewId = View.new(.{
        .name = "TestView",
        .width = 200,
        .height = 200,
        .order = 1,
        // transform is used when rendering the texture to the screen (or another texture)
        .transform = .{
            .position = .{ 10, 10 },
            .pivot = .{ 0, 0 },
            .scale = .{ 1, 1 },
            .rotation = 0,
        },
        // render_data that is used when rendering the texture to the screen (or another texture)
        .render_data = .{
            .tint_color = .{ 255, 255, 255, 150 },
            .blend_mode = BlendMode.ALPHA,
        },
        // projection is used when rendering to the texture.
        // Can be seen as the camera of the texture
        .projection = .{
            .clear_color = .{ 30, 30, 30, 255 },
            .offset = .{ -10, -10 },
            .pivot = .{ 0, 0 },
            .zoom = 2,
            .rotation = 0,
        },
    });
    View.activateById(viewId, true);

    var sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .sprite_data = .{ .texture_bounds = utils.RectF{ 0, 0, 32, 32 } },
    });

    Texture.newAnd(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    _ = Entity.newAnd(.{ .name = "TestEntity" })
        .with(ETransform{ .view_id = viewId })
        .with(ESprite{ .template_id = sprite_id })
        .activate();
}
