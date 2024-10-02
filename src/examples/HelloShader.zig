const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const graphics = firefly.graphics;

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

    firefly.Engine.start(600, 400, 60, "Hello Shader", example);
}

fn example() void {
    const shader = graphics.Shader.Component.newGet(.{
        .fragment_shader_resource = "resources/fragBloom.glsl",
        .vertex_shader_resource = "resources/vertBloom.glsl",
    });
    firefly.api.Asset.Activation.activate(shader.id);

    const view_id = graphics.View.Component.newActive(.{
        .name = "View",
        .position = .{ 0, 0 },
        .scale = .{ 1, 1 },
        .projection = .{
            .width = 600,
            .height = 400,
            .zoom = 1,
        },
        .shader_binding = graphics.Shader.Component.byId(shader.id)._binding.?.id,
    });

    Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    _ = firefly.api.Entity.build(.{ .name = "Player" })
        .withComponent(graphics.ETransform{
        .position = .{ 32, 32 },
        .pivot = .{ 0, 0 },
        .scale = .{ 2, 2 },
    })
        .withComponent(graphics.EView{
        .view_id = view_id,
    })
        .withComponent(graphics.ESprite{ .template_id = sprite_id })
        .activate();
}
