const std = @import("std");
const inari = @import("../inari/inari.zig");
const firefly = inari.firefly;
const utils = inari.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EMultiplier = firefly.api.EMultiplier;
const Allocator = std.mem.Allocator;
const Vector2f = utils.Vector2f;

pub fn run(allocator: Allocator) !void {
    try firefly.init(
        allocator,
        allocator,
        allocator,
        firefly.api.InitMode.DEVELOPMENT,
    );
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Sprite", init);
}

fn init() void {
    Texture.newAnd(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    var sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    _ = Entity.newAnd(.{ .name = "TestEntity" })
        .with(ETransform{ .position = .{ 100, 100 }, .scale = .{ 1.2, 1.2 }, .pivot = .{ 16, 16 }, .rotation = 45 })
        .with(ESprite{ .template_id = sprite_id })
        .with(EMultiplier{ .positions = firefly.api.allocVec2FArray([_]Vector2f{
        .{ 50, 50 },
        .{ 200, 50 },
        .{ 50, 150 },
        .{ 200, 150 },
    }) })
        .activate();
}