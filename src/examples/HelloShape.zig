const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

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
const Engine = firefly.Engine;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Shape", example);
}

fn example() void {
    // change rendering order
    Engine.reorderSystems(&[_]String{
        Engine.CoreSystems.VIEW_RENDERER,
        Engine.CoreSystems.TILE_RENDERER,
        Engine.CoreSystems.SHAPE_RENDERER,
        Engine.CoreSystems.TEXT_RENDERER,
        Engine.CoreSystems.SPRITE_RENDERER,
    });

    _ = Entity.new(.{ .name = "TestEntity4" })
        .withComponent(ETransform{ .position = .{ 100, 100 } })
        .withComponent(EShape{
        .shape_type = ShapeType.CIRCLE,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 50 }),
        .color = .{ 150, 150, 150, 100 },
    })
        .activate();

    _ = Entity.new(.{ .name = "TestEntity1" })
        .withComponent(ETransform{
        .position = .{ 0, 0 },
        .pivot = .{ 100, 100 },
        .scale = .{ 0.5, 0.5 },
        .rotation = 45,
    })
        .withComponent(EShape{
        .shape_type = ShapeType.RECTANGLE,
        .fill = false,
        .thickness = 5,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 200, 200 }),
        .color = .{ 255, 0, 0, 255 },
    })
        .activate();

    _ = Entity.new(.{ .name = "TestEntity2" })
        .withComponent(ETransform{
        .position = .{ 0, 0 },
        .pivot = .{ 100, 100 },
        .scale = .{ 0.25, 0.25 },
        .rotation = 45,
    })
        .withComponent(EShape{
        .shape_type = ShapeType.RECTANGLE,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 200, 200 }),
        .color = .{ 255, 0, 0, 100 },
    })
        .activate();

    _ = Entity.new(.{ .name = "TestEntity3" })
        .withComponent(ETransform{
        .position = .{ 0, 0 },
        .pivot = .{ 100, 100 },
        .scale = .{ 0.1, 0.1 },
        .rotation = 45,
    })
        .withComponent(EShape{
        .shape_type = ShapeType.RECTANGLE,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 200, 200 }),
        .color = .{ 255, 0, 0, 255 },
        .color1 = .{ 0, 255, 0, 255 },
        .color2 = .{ 0, 0, 255, 255 },
        .color3 = .{ 255, 255, 255, 0 },
    })
        .activate();

    _ = Entity.new(.{ .name = "TestEntity5" })
        .withComponent(ETransform{ .position = .{ 0, 0 } })
        .withComponent(EMultiplier{ .positions = firefly.api.allocVec2FArray([_]Vector2f{
        .{ 400, 310 },
        .{ 410, 310 },
        .{ 420, 310 },
        .{ 430, 315 },
        .{ 400, 315 },
        .{ 415, 310 },
    }) })
        .withComponent(EShape{
        .shape_type = ShapeType.CIRCLE,
        .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 10 }),
        .color = .{ 150, 150, 150, 100 },
    })
        .activate();

    Texture.new(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    const sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    }).id;

    _ = Entity.new(.{ .name = "TestEntitySprite" })
        .withComponent(ETransform{
        .position = .{ 64, 164 },
        .scale = .{ 4, 4 },
        .pivot = .{ 16, 16 },
        .rotation = 180,
    })
        .withComponent(ESprite{ .template_id = sprite_id })
        .activate();
}
