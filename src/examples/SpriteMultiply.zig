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

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Sprite", init);
}

fn init() void {
    _ = Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    _ = Entity.newActive(.{ .name = "TestEntity" }, .{
        ETransform{ .position = .{ 100, 100 }, .scale = .{ 1.2, 1.2 }, .pivot = .{ 16, 16 }, .rotation = 45 },
        ESprite{ .template_id = sprite_id },
        EMultiplier{ .positions = firefly.api.allocVec2FArray([_]Vector2f{
            .{ 50, 50 },
            .{ 200, 50 },
            .{ 50, 150 },
            .{ 200, 150 },
        }) },
    });
}
