const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;

const Float = utils.Float;
const Index = utils.Index;
const WindowFlag = firefly.api.WindowFlag;

const width: usize = 800;
const height: usize = 600;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.startWindow(.{
        .width = width,
        .height = height,
        .fps = 60,
        .title = "Hello Window",
        .flags = &[_]WindowFlag{WindowFlag.FLAG_WINDOW_RESIZABLE},
    }, init, null);
}

fn init() void {
    const view_id = graphics.View.Component.newActive(.{
        .name = "TestView",
        .position = .{ 0, 0 },
        .projection = .{
            .width = utils.usize_f32(width),
            .height = utils.usize_f32(height),
        },
    });

    graphics.WindowScalingAdaption.init("TestView", width, height);

    _ = api.Entity.newActive(.{ .name = "Border" }, .{
        graphics.ETransform{ .position = .{ 0, 0 } },
        graphics.EView{ .view_id = view_id },
        graphics.EShape{
            .color = .{ 255, 0, 0, 255 },
            .shape_type = .RECTANGLE,
            .fill = false,
            .thickness = 4,
            .vertices = api.allocFloatArray([_]Float{ 0, 0, utils.usize_f32(width), utils.usize_f32(height) }),
        },
    });

    _ = graphics.Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = graphics.SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    _ = api.Entity.newActive(.{ .name = "TestEntity" }, .{
        graphics.ETransform{
            .position = .{ 200, 200 },
            .scale = .{ 4, 4 },
        },
        graphics.EView{ .view_id = view_id },
        graphics.ESprite{ .template_id = sprite_id },
    });
}