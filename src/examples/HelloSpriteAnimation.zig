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
const IndexFrameList = firefly.physics.IndexFrameList;
const IndexFrameIntegration = firefly.physics.IndexFrameIntegration;
const BlendMode = firefly.api.BlendMode;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Sprite Animation", init);
}

fn init() void {
    Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/atlas1616.png",
        .is_mipmap = false,
    });

    const sid1 = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 16, 0, 16, 16 },
    }).id;
    const sid2 = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 16, 0, 16, 16 },
    }).flipX().id;
    const sid3 = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 16, 0, 16, 16 },
    }).flipY().flipX().id;
    const sid4 = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 16, 0, 16, 16 },
    }).flipY().id;

    var animation: IndexFrameList = IndexFrameList.new();

    _ = animation.withFrame(sid1, 1000);
    _ = animation.withFrame(sid2, 1000);
    _ = animation.withFrame(sid3, 1000);
    _ = animation.withFrame(sid4, 1000);

    _ = Entity.Component.new(.{ .name = "TestEntity" })
        .withComponent(ETransform{
        .position = .{ 100, 100 },
        .scale = .{ 2, 2 },
    })
        .withComponent(ESprite{ .template_id = sid1 })
        .withComponent(EAnimation{})
        .withAnimation(
        .{ .duration = animation._duration, .looping = true, .active_on_init = true },
        IndexFrameIntegration{
            .timeline = animation,
            .property_ref = ESprite.Property.FrameId,
        },
    )
        .entity().activate();

    _ = Entity.Component.new(.{ .name = "TestEntity1" })
        .withComponent(ETransform{
        .position = .{ 100, 200 },
        .scale = .{ 2, 2 },
    })
        .withComponent(ESprite{ .template_id = sid1 })
        .entity().activate();
    _ = Entity.Component.new(.{ .name = "TestEntity2" })
        .withComponent(ETransform{
        .position = .{ 150, 200 },
        .scale = .{ 2, 2 },
    })
        .withComponent(ESprite{ .template_id = sid2 })
        .entity().activate();
    _ = Entity.Component.new(.{ .name = "TestEntity3" })
        .withComponent(ETransform{
        .position = .{ 200, 200 },
        .scale = .{ 2, 2 },
    })
        .withComponent(ESprite{ .template_id = sid3 })
        .entity().activate();
    _ = Entity.Component.new(.{ .name = "TestEntity4" })
        .withComponent(ETransform{
        .position = .{ 250, 200 },
        .scale = .{ 2, 2 },
    })
        .withComponent(ESprite{ .template_id = sid4 })
        .entity().activate();
}
