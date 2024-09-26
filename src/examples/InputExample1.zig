const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
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
const KeyboardKey = firefly.api.KeyboardKey;
const GamepadAction = firefly.api.GamepadAction;
const InputDevice = firefly.api.InputDevice;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Input Example", init);
}

fn init() void {
    Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    }).id;

    _ = Entity.Component.new(.{ .name = "TestEntity" })
        .withComponent(ETransform{ .position = .{ 100, 100 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .activate();

    firefly.api.input.setKeyMapping(KeyboardKey.KEY_UP, InputButtonType.UP);
    firefly.api.input.setKeyMapping(KeyboardKey.KEY_DOWN, InputButtonType.DOWN);
    firefly.api.input.setKeyMapping(KeyboardKey.KEY_LEFT, InputButtonType.LEFT);
    firefly.api.input.setKeyMapping(KeyboardKey.KEY_RIGHT, InputButtonType.RIGHT);

    firefly.api.input.setGamepadButtonMapping(InputDevice.GAME_PAD_1, GamepadAction.GAMEPAD_BUTTON_LEFT_FACE_UP, InputButtonType.UP);
    firefly.api.input.setGamepadButtonMapping(InputDevice.GAME_PAD_1, GamepadAction.GAMEPAD_BUTTON_LEFT_FACE_DOWN, InputButtonType.DOWN);
    firefly.api.input.setGamepadButtonMapping(InputDevice.GAME_PAD_1, GamepadAction.GAMEPAD_BUTTON_LEFT_FACE_LEFT, InputButtonType.LEFT);
    firefly.api.input.setGamepadButtonMapping(InputDevice.GAME_PAD_1, GamepadAction.GAMEPAD_BUTTON_LEFT_FACE_RIGHT, InputButtonType.RIGHT);

    firefly.api.subscribeUpdate(update);
}

fn update(_: UpdateEvent) void {
    if (Entity.Naming.byName("TestEntity")) |entity| {
        if (firefly.api.input.checkButtonPressed(InputButtonType.UP))
            ETransform.byId(entity.id).?.position[1] -= 1;
        if (firefly.api.input.checkButtonPressed(InputButtonType.DOWN))
            ETransform.byId(entity.id).?.position[1] += 1;
        if (firefly.api.input.checkButtonPressed(InputButtonType.LEFT))
            ETransform.byId(entity.id).?.position[0] -= 1;
        if (firefly.api.input.checkButtonPressed(InputButtonType.RIGHT))
            ETransform.byId(entity.id).?.position[0] += 1;
    }
}
