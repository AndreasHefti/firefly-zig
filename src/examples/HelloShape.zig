const std = @import("std");
const inari = @import("../inari/inari.zig");
const firefly = inari.firefly;
const utils = inari.utils;

const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const EShape = firefly.graphics.EShape;
const ShapeType = firefly.api.ShapeType;
const Allocator = std.mem.Allocator;
const Easing = utils.Easing;
const Float = utils.Float;
const String = utils.String;
const Vector2f = utils.Vector2f;

const System = firefly.api.System;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const ESprite = firefly.graphics.ESprite;
const EMultiplier = firefly.api.EMultiplier;
const DefaultRenderer = firefly.graphics.DefaultRenderer;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Shape", example);
}

fn example() void {
    // change rendering order
    firefly.graphics.reorderRenderer(&[2]String{ DefaultRenderer.SHAPE, DefaultRenderer.SPRITE });

    _ = Entity.newAnd(.{ .name = "TestEntity4" })
        .with(ETransform{ .position = .{ 100, 100 } })
        .with(EShape{
        .shape_type = ShapeType.CIRCLE,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 50 }),
        .color = .{ 150, 150, 150, 100 },
    })
        .activate();

    _ = Entity.newAnd(.{ .name = "TestEntity1" })
        .with(ETransform{ .position = .{ 0, 0 }, .pivot = .{ 100, 100 }, .scale = .{ 0.5, 0.5 }, .rotation = 45 })
        .with(EShape{
        .shape_type = ShapeType.RECTANGLE,
        .fill = false,
        .thickness = 5,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 200, 200 }),
        .color = .{ 255, 0, 0, 255 },
    })
        .activate();

    _ = Entity.newAnd(.{ .name = "TestEntity2" })
        .with(ETransform{ .position = .{ 0, 0 }, .pivot = .{ 100, 100 }, .scale = .{ 0.25, 0.25 }, .rotation = 45 })
        .with(EShape{
        .shape_type = ShapeType.RECTANGLE,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 200, 200 }),
        .color = .{ 255, 0, 0, 100 },
    })
        .activate();

    _ = Entity.newAnd(.{ .name = "TestEntity3" })
        .with(ETransform{ .position = .{ 0, 0 }, .pivot = .{ 100, 100 }, .scale = .{ 0.1, 0.1 }, .rotation = 45 })
        .with(EShape{
        .shape_type = ShapeType.RECTANGLE,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 200, 200 }),
        .color = .{ 255, 0, 0, 255 },
        .color1 = .{ 0, 255, 0, 255 },
        .color2 = .{ 0, 0, 255, 255 },
        .color3 = .{ 255, 255, 255, 0 },
    })
        .activate();

    _ = Entity.newAnd(.{ .name = "TestEntity5" })
        .with(ETransform{ .position = .{ 0, 0 } })
        .with(EMultiplier{ .positions = firefly.api.allocVec2FArray([_]Vector2f{
        .{ 400, 310 },
        .{ 410, 310 },
        .{ 420, 310 },
        .{ 430, 315 },
        .{ 400, 315 },
        .{ 415, 310 },
    }) })
        .with(EShape{
        .shape_type = ShapeType.CIRCLE,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 10 }),
        .color = .{ 150, 150, 150, 100 },
    })
        .activate();

    Texture.newAnd(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    var sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    _ = Entity.newAnd(.{ .name = "TestEntitySprite" })
        .with(ETransform{ .position = .{ 64, 164 }, .scale = .{ 4, 4 }, .pivot = .{ 16, 16 }, .rotation = 180 })
        .with(ESprite{ .template_id = sprite_id })
        .activate();
}
