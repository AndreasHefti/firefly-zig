const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const Sprite = firefly.graphics.Sprite;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Sprite Flip", init);
}

fn init() void {
    _ = Texture.Component.new(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
    });

    _ = Entity.newActive(.{}, .{
        ETransform{
            .position = .{ 50, 50 },
            .scale = .{ 4, 4 },
        },
        ESprite{ .sprite_id = Sprite.Component.new(.{
            .texture_name = "TestTexture",
            .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
        }) },
    });

    _ = Entity.newActive(.{}, .{
        ETransform{
            .position = .{ 300, 50 },
            .scale = .{ 4, 4 },
        },
        ESprite{ .sprite_id = Sprite.Component.new(.{
            .texture_name = "TestTexture",
            .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
            .flip_x = true,
        }) },
        firefly.graphics.EText{ .text = "       flip x", .size = 20 },
    });

    _ = Entity.newActive(.{}, .{
        ETransform{
            .position = .{ 50, 200 },
            .scale = .{ 4, 4 },
        },
        ESprite{ .sprite_id = Sprite.Component.new(.{
            .texture_name = "TestTexture",
            .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
            .flip_y = true,
        }) },
        firefly.graphics.EText{ .text = "       flip y", .size = 20 },
    });

    _ = Entity.newActive(.{}, .{
        ETransform{
            .position = .{ 300, 200 },
            .scale = .{ 4, 4 },
        },
        ESprite{ .sprite_id = Sprite.Component.new(.{
            .texture_name = "TestTexture",
            .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
            .flip_x = true,
            .flip_y = true,
        }) },
        firefly.graphics.EText{ .text = "       flip xy", .size = 20 },
    });
}
