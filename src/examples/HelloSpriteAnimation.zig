const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const Sprite = firefly.graphics.Sprite;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const AnimationSystem = firefly.physics.AnimationSystem;
const Allocator = std.mem.Allocator;
const IndexFrameList = firefly.physics.IndexFrameList;
const IndexFrameIntegrator = firefly.physics.IndexFrameIntegrator;
const BlendMode = firefly.api.BlendMode;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Sprite Animation", init);
}

fn init() void {
    _ = Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/atlas1616.png",
        .is_mipmap = false,
    });

    const sid1 = Sprite.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 16, 0, 16, 16 },
    });
    const sid2 = Sprite.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 16, 0, 16, 16 },
        .flip_x = true,
    });
    const sid3 = Sprite.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 16, 0, 16, 16 },
        .flip_x = true,
        .flip_y = true,
    });
    const sid4 = Sprite.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 16, 0, 16, 16 },
        .flip_y = true,
    });

    const animation: IndexFrameList = IndexFrameList.new(firefly.api.POOL_ALLOC)
        .withFrame(sid1, 1000)
        .withFrame(sid2, 1000)
        .withFrame(sid3, 1000)
        .withFrame(sid4, 1000);

    _ = Entity.newActive(
        .{},
        .{
            ETransform{ .position = .{ 100, 100 }, .scale = .{ 2, 2 } },
            ESprite{ .sprite_id = sid1 },
            firefly.physics.EIndexFrameAnimation{
                .looping = true,
                .active_on_init = true,
                .timeline = animation,
                .property_ref = ESprite.Property.FrameId,
            },
        },
    );

    _ = Entity.newActive(.{ .name = "TestEntity1" }, .{
        ETransform{ .position = .{ 100, 200 }, .scale = .{ 2, 2 } },
        ESprite{ .sprite_id = sid1 },
    });

    _ = Entity.newActive(.{ .name = "TestEntity2" }, .{
        ETransform{ .position = .{ 150, 200 }, .scale = .{ 2, 2 } },
        ESprite{ .sprite_id = sid2 },
    });

    _ = Entity.newActive(.{ .name = "TestEntity3" }, .{
        ETransform{ .position = .{ 200, 200 }, .scale = .{ 2, 2 } },
        ESprite{ .sprite_id = sid3 },
    });

    _ = Entity.newActive(.{ .name = "TestEntity4" }, .{
        ETransform{ .position = .{ 250, 200 }, .scale = .{ 2, 2 } },
        ESprite{ .sprite_id = sid4 },
    });
}
