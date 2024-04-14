const std = @import("std");
const inari = @import("../inari/inari.zig");
const firefly = inari.firefly;
const utils = inari.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const InputButtonType = firefly.api.InputButtonType;
const InputActionType = firefly.api.InputActionType;
const Allocator = std.mem.Allocator;
const String = utils.String;
const Float = utils.Float;
const UpdateEvent = firefly.api.UpdateEvent;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Input Example", init);
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
        .with(ETransform{ .position = .{ 100, 100 } })
        .with(ESprite{ .template_id = sprite_id })
        .activate();

    firefly.api.input.setKeyButtonMapping(265, InputButtonType.UP);
    firefly.api.input.setKeyButtonMapping(264, InputButtonType.DOWN);
    firefly.api.input.setKeyButtonMapping(263, InputButtonType.LEFT);
    firefly.api.input.setKeyButtonMapping(262, InputButtonType.RIGHT);

    firefly.api.subscribeUpdate(update);
}

fn update(_: UpdateEvent) void {
    if (firefly.api.input.checkButton(InputButtonType.UP, InputActionType.ON, null)) {
        if (Entity.byName("TestEntity")) |entity| {
            ETransform.byId(entity.id).?.position[1] -= 1;
        }
    }
    if (firefly.api.input.checkButton(InputButtonType.DOWN, InputActionType.ON, null)) {
        if (Entity.byName("TestEntity")) |entity| {
            ETransform.byId(entity.id).?.position[1] += 1;
        }
    }
    if (firefly.api.input.checkButton(InputButtonType.LEFT, InputActionType.ON, null)) {
        if (Entity.byName("TestEntity")) |entity| {
            ETransform.byId(entity.id).?.position[0] -= 1;
        }
    }
    if (firefly.api.input.checkButton(InputButtonType.RIGHT, InputActionType.ON, null)) {
        if (Entity.byName("TestEntity")) |entity| {
            ETransform.byId(entity.id).?.position[0] += 1;
        }
    }
}
