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
const Index = utils.Index;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello View", loadWithView);
}

fn loadWithView() void {
    const viewId = View.Component.new(.{
        .name = "TestView",

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
            .position = .{ -10, -10 },
            .width = 200,
            .height = 200,
            .pivot = .{ 0, 0 },
            .zoom = 2,
            .rotation = 0,
        },
    });

    View.Control.add(viewId, view_control, null, true);
    View.Activation.activate(viewId);

    const sprite_id = SpriteTemplate.Component.newGet(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    })
        .flipX()
        .flipY()
        .id;

    Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    Entity.build(.{ .name = "TestEntity" })
        .withComponent(ETransform{})
        .withComponent(EView{ .view_id = viewId })
        .withComponent(ESprite{ .template_id = sprite_id })
        .activate();
}

fn view_control(ctx: *firefly.api.CallContext) void {
    var view = View.Component.byId(ctx.caller_id);
    view.projection.position[0] -= 0.1;
    view.projection.position[1] -= 0.1;
    view.position[0] += 1;
    view.position[1] += 0.6;
}
