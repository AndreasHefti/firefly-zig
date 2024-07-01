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

    firefly.Engine.start(600, 400, 60, "Test Sprite and Shape Projection", init);
}

fn init() void {
    const view = firefly.graphics.View.new(.{
        .name = "View1",
        .position = .{ 0, 0 },
        .projection = .{
            .width = 600,
            .height = 400,
            .zoom = 1,
        },
    }).activate();

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
        .position = .{ 64, 64 },
        .scale = .{ 0, 0 },
        .pivot = .{ 16, 16 },
    })
        .withComponent(firefly.graphics.EView{ .view_id = view.id })
        .withComponent(ESprite{ .template_id = sprite_id })
        .entity().activate();
}
