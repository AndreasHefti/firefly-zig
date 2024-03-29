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

const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const ESprite = firefly.graphics.ESprite;

pub fn run(allocator: Allocator) !void {
    try firefly.init(
        allocator,
        allocator,
        allocator,
        firefly.api.InitMode.DEVELOPMENT,
    );
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Sprite", example);
}

fn example() void {
    var v: []Float = firefly.api.ALLOC.alloc(Float, 4) catch unreachable;
    v[0] = 0;
    v[1] = 0;
    v[2] = 200;
    v[3] = 200;
    _ = Entity.newAnd(.{ .name = "TestEntity" })
        .with(ETransform{ .position = .{ 0, 0 }, .pivot = .{ 100, 100 }, .scale = .{ 0.5, 0.5 }, .rotation = 45 })
        .with(EShape{
        .shape_type = ShapeType.RECTANGLE,
        .vertices = v,
        .color = .{ 255, 0, 0, 255 },
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
