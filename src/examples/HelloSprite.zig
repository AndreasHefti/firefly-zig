const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EAnimation = firefly.physics.EAnimation;
const AnimationSystem = firefly.physics.AnimationSystem;
const EasedValueIntegration = firefly.physics.EasedValueIntegration;
const Allocator = std.mem.Allocator;
const Easing = utils.Easing;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Sprite", _Example_One_Entity_No_Views);
}

fn _Example_One_Entity_No_Views() void {
    Texture.new(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    const sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    }).id;

    _ = Entity.new(.{ .name = "TestEntity" })
        .withComponent(ETransform{
        .position = .{ 64, 164 },
        .scale = .{ 4, 4 },
        .pivot = .{ 16, 16 },
        .rotation = 180,
    })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EAnimation{})
        .withAnimation(
        .{ .duration = 1000, .looping = true, .inverse_on_loop = true, .active_on_init = true },
        EasedValueIntegration{
            .start_value = 164.0,
            .end_value = 264.0,
            .easing = Easing.Linear,
            .property_ref = ETransform.Property.XPos,
        },
    )
        .withAnimation(
        .{ .duration = 2000, .looping = true, .inverse_on_loop = true, .active_on_init = true },
        EasedValueIntegration{
            .start_value = 0.0,
            .end_value = 180.0,
            .easing = Easing.Linear,
            .property_ref = ETransform.Property.Rotation,
        },
    ).entity().activate();

    AnimationSystem.setLoopCallbackById(1, loopCallback1);
}

fn loopCallback1(count: usize) void {
    std.log.info("Loop: {any}", .{count});
}
