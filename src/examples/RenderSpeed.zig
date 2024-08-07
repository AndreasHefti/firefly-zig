const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EMultiplier = firefly.api.EMultiplier;
const Allocator = std.mem.Allocator;
const Vector2f = utils.Vector2f;
const Float = utils.Float;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Render Speed", init);
}

fn init() void {
    firefly.api.rendering.setRenderBatch(1, 181920);

    Texture.new(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    const sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    }).id;

    var pos = firefly.api.ALLOC.alloc(Vector2f, 100000) catch unreachable;
    var rndx = std.rand.DefaultPrng.init(32);
    const rx = rndx.random();
    for (0..100000) |i| {
        pos[i][0] = rx.float(Float) * 600;
        pos[i][1] = rx.float(Float) * 400;
    }

    _ = Entity.new(.{ .name = "TestEntity" })
        .withComponent(ETransform{ .position = .{ 0, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMultiplier{ .positions = pos })
        .activate();
}
