const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const Sprite = firefly.graphics.Sprite;
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
    _ = Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = Sprite.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    _ = Entity.newActive(.{ .name = "TestEntity" }, .{
        ETransform{ .position = .{ 100, 100 } },
        ESprite{ .sprite_id = sprite_id },
    });

    firefly.api.input.setKeyMapping(.KEY_UP, .UP);
    firefly.api.input.setKeyMapping(.KEY_DOWN, .DOWN);
    firefly.api.input.setKeyMapping(.KEY_LEFT, .LEFT);
    firefly.api.input.setKeyMapping(.KEY_RIGHT, .RIGHT);

    firefly.api.input.setGamepad1Mapping(.GAME_PAD_1);
    firefly.api.input.setGamepadButtonMapping(.GAME_PAD_1, .GAMEPAD_BUTTON_LEFT_FACE_UP, .UP);
    firefly.api.input.setGamepadButtonMapping(.GAME_PAD_1, .GAMEPAD_BUTTON_LEFT_FACE_DOWN, .DOWN);
    firefly.api.input.setGamepadButtonMapping(.GAME_PAD_1, .GAMEPAD_BUTTON_LEFT_FACE_LEFT, .LEFT);
    firefly.api.input.setGamepadButtonMapping(.GAME_PAD_1, .GAMEPAD_BUTTON_LEFT_FACE_RIGHT, .RIGHT);

    firefly.api.input.setGamepadAxisButtonMapping(.GAME_PAD_1, .GAMEPAD_AXIS_LEFT_Y, -0.5, .UP);
    firefly.api.input.setGamepadAxisButtonMapping(.GAME_PAD_1, .GAMEPAD_AXIS_LEFT_Y, 0.5, .DOWN);
    firefly.api.input.setGamepadAxisButtonMapping(.GAME_PAD_1, .GAMEPAD_AXIS_LEFT_X, -0.5, .LEFT);
    firefly.api.input.setGamepadAxisButtonMapping(.GAME_PAD_1, .GAMEPAD_AXIS_LEFT_X, 0.5, .RIGHT);

    firefly.api.subscribeUpdate(update);
}

fn update(_: UpdateEvent) void {
    if (Entity.Naming.byName("TestEntity")) |entity| {
        if (firefly.api.input.checkButtonPressed(InputButtonType.UP))
            ETransform.Component.byId(entity.id).position[1] -= 1;
        if (firefly.api.input.checkButtonPressed(InputButtonType.DOWN))
            ETransform.Component.byId(entity.id).position[1] += 1;
        if (firefly.api.input.checkButtonPressed(InputButtonType.LEFT))
            ETransform.Component.byId(entity.id).position[0] -= 1;
        if (firefly.api.input.checkButtonPressed(InputButtonType.RIGHT))
            ETransform.Component.byId(entity.id).position[0] += 1;
    }
}
