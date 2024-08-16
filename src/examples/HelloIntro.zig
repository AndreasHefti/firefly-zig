const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const physics = firefly.physics;

const Float = utils.Float;
const Index = utils.Index;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Intro", init);
}

pub fn init() void {
    var intro_scene = graphics.Scene.new(.{
        .init_function = sceneInit,
        .delete_after_run = true,
        .callback = sceneEnd,
        .update_action = sceneRun,
    });
    //intro_scene.activate();
    intro_scene.run();
}

fn sceneInit(_: Index, _: ?Index) void {
    graphics.Texture.new(.{
        .name = "IntroTexture",
        .resource = "resources/inari.png",
        .is_mipmap = false,
    }).load();

    const screen = api.window.getWindowData();

    _ = api.Entity.new(.{ .name = "IntroSprite" })
        .withComponent(graphics.ETransform{
        .position = .{
            @as(Float, @floatFromInt(screen.width)) / 2 - 390 / 2,
            @as(Float, @floatFromInt(screen.height)) / 2 - 50 / 2,
        },
        .scale = .{ 1, 1 },
        .pivot = .{ 0, 0 },
        .rotation = 0,
    })
        .withComponent(graphics.ESprite{
        .template_id = graphics.SpriteTemplate.new(.{
            .texture_name = "IntroTexture",
            .texture_bounds = .{ 0, 0, 390, 50 },
        }).id,
        .tint_color = .{ 255, 255, 255, 0 },
    })
        .withComponent(physics.EAnimation{})
        .withAnimation(
        .{ .duration = 3000, .active_on_init = true },
        physics.EasedColorIntegration{
            .start_value = .{ 255, 255, 255, 0 },
            .end_value = .{ 255, 255, 255, 255 },
            .easing = utils.Easing.Linear,
            .property_ref = graphics.ESprite.Property.TintColor,
        },
    ).activate();
}

fn sceneRun(_: Index) api.ActionResult {
    if (graphics.ESprite.byName("IntroSprite")) |sprite| {
        if (sprite.tint_color.?[3] >= 254)
            return api.ActionResult.Success
        else
            return api.ActionResult.Running;
    }

    return api.ActionResult.Failed;
}

fn sceneEnd(_: Index, _: api.ActionResult) void {
    firefly.Engine.registerQuitKey(firefly.api.KeyboardKey.KEY_SPACE);
}
