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

    firefly.Engine.showFPS(.{ 0, 0 });
    firefly.Engine.start(600, 400, 60, "Hello Intro", init);
}

pub fn init() void {
    api.window.setExitKey(.KEY_NULL);

    var intro_scene = graphics.Scene.Component.newAndGet(.{
        .init_function = sceneInit,
        .delete_after_run = true,
        .callback = sceneEnd,
        .update_action = sceneRun,
    });
    intro_scene.run();
}

fn sceneInit(_: *api.CallContext) void {
    _ = graphics.Texture.Component.new(.{
        .name = "IntroTexture",
        .resource = "resources/inari.png",
        .is_mipmap = false,
    });

    const sprite_id = graphics.Sprite.Component.new(.{
        .texture_name = "IntroTexture",
        .texture_bounds = .{ 0, 0, 390, 50 },
    });

    const screen = api.window.getWindowData();

    const eid = api.Entity.Component.new(.{ .name = "IntroSprite" });
    graphics.ETransform.add(eid, .{
        .position = .{
            @as(Float, @floatFromInt(screen.width)) / 2 - 390 / 2,
            @as(Float, @floatFromInt(screen.height)) / 2 - 50 / 2,
        },
        .scale = .{ 1, 1 },
        .pivot = .{ 0, 0 },
        .rotation = 0,
    });
    graphics.ESprite.Component.new(eid, .{
        .sprite_id = sprite_id,
        .tint_color = .{ 255, 255, 255, 0 },
    });
    physics.EAnimations.add(eid, .{
        .duration = 3000,
        .active_on_init = true,
        .reset_on_finish = false,
    }, physics.EasedColorIntegrator{
        .start_value = .{ 255, 255, 255, 0 },
        .end_value = .{ 255, 255, 255, 255 },
        .easing = utils.Easing.Linear,
        .property_ref = graphics.ESprite.Property.TintColor,
    });
    api.Entity.Activation.activate(eid);
}

fn sceneRun(ctx: *api.CallContext) void {
    if (graphics.ESprite.Component.byName("IntroSprite")) |sprite| {
        //std.debug.print("**** alpha: {d}\n", .{sprite.tint_color.?[3]});
        if (sprite.tint_color.?[3] >= 254)
            ctx.result = api.ActionResult.Success
        else
            ctx.result = api.ActionResult.Running;
    } else ctx.result = api.ActionResult.Failure;
}

fn sceneEnd(_: *api.CallContext) void {
    std.debug.print("**************** Intro end!", .{});
    firefly.Engine.registerQuitKey(firefly.api.KeyboardKey.KEY_SPACE);
}
