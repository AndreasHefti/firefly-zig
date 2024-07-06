const std = @import("std");
const firefly = @import("../../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;
const rl = @cImport(@cInclude("raylib.h"));

const CInt = firefly.utils.CInt;
const Vector2f = firefly.utils.Vector2f;
const PosF = firefly.utils.PosF;
const Float = firefly.utils.Float;
const String = firefly.utils.String;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

var singleton: ?api.IInputAPI() = null;
pub fn createInputAPI() !api.IInputAPI() {
    if (singleton == null)
        singleton = api.IInputAPI().init(RaylibInputAPI.initImpl);

    return singleton.?;
}

const RaylibInputAPI = struct {
    var initialized = false;

    var keyboard_on = false;
    var gamepad_1_on = false;
    var gamepad_2_on = false;
    var mouse_on = false;

    var gamepad_1_code: CInt = 0;
    var gamepad_2_code: CInt = 1;

    var keyboard_code_mapping: utils.DynIndexArray = undefined;
    var gamepad_1_code_mapping: utils.DynIndexArray = undefined;
    var gamepad_2_code_mapping: utils.DynIndexArray = undefined;
    var mouse_code_mapping: utils.DynIndexArray = undefined;

    fn initImpl(interface: *api.IInputAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        keyboard_code_mapping = utils.DynIndexArray.new(firefly.api.ALLOC, 10);
        gamepad_1_code_mapping = utils.DynIndexArray.new(firefly.api.ALLOC, 10);
        gamepad_2_code_mapping = utils.DynIndexArray.new(firefly.api.ALLOC, 10);
        mouse_code_mapping = utils.DynIndexArray.new(firefly.api.ALLOC, 10);

        interface.checkButton = checkButton;
        interface.clear_mappings = clear_mappings;
        interface.getKeyPressed = getKeyPressed;
        interface.getCharPressed = getCharPressed;
        interface.setKeyButtonMapping = setKeyButtonMapping;
        interface.isGamepadAvailable = isGamepadAvailable;
        interface.getGamepadName = getGamepadName;
        interface.getGamepadAxisMovement = getGamepadAxisMovement;
        interface.setGamepad1Mapping = setGamepad1Mapping;
        interface.setGamepad2Mapping = setGamepad2Mapping;
        interface.setGamepadButtonMapping = setGamepadButtonMapping;
        interface.getMousePosition = getMousePosition;
        interface.getMouseDelta = getMouseDelta;
        interface.setMouseButtonMapping = setMouseButtonMapping;

        interface.deinit = deinit;
    }

    fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        keyboard_on = false;
        gamepad_1_on = false;
        gamepad_2_on = false;
        mouse_on = false;

        keyboard_code_mapping.deinit();
        gamepad_1_code_mapping.deinit();
        gamepad_2_code_mapping.deinit();
        mouse_code_mapping.deinit();

        keyboard_code_mapping = undefined;
        gamepad_1_code_mapping = undefined;
        gamepad_2_code_mapping = undefined;
        mouse_code_mapping = undefined;

        singleton = null;
    }

    // check the button type for specified action. Button type must have been mapped on one or many devices
    fn checkButton(button: api.InputButtonType, action: api.InputActionType, input: ?api.InputDevice) bool {
        if (input) |in| {
            return switch (in) {
                .KEYBOARD => checkKeyboard(button, action),
                .GAME_PAD_1 => checkPad1(button, action),
                .GAME_PAD_2 => checkPad2(button, action),
                .MOUSE => checkMouse(button, action),
            };
        }

        if (keyboard_on and checkKeyboard(button, action)) return true;
        if (gamepad_1_on and checkPad1(button, action)) return true;
        if (gamepad_2_on and checkPad2(button, action)) return true;
        if (mouse_on and checkMouse(button, action)) return true;
        return false;
    }

    // clears all mappings
    fn clear_mappings() void {
        keyboard_on = false;
        gamepad_1_on = false;
        gamepad_2_on = false;
        mouse_on = false;

        keyboard_code_mapping.clear();
        gamepad_1_code_mapping.clear();
        gamepad_2_code_mapping.clear();
        mouse_code_mapping.clear();
    }

    // KEYBOARD
    // Get key pressed (keycode), call it multiple times for keys queued, returns 0 when the queue is empty
    fn getKeyPressed() CInt {
        return rl.GetKeyPressed();
    }
    // Get char pressed (unicode), call it multiple times for chars queued, returns 0 when the queue is empty
    fn getCharPressed() CInt {
        return rl.GetCharPressed();
    }
    // key mappings
    fn setKeyButtonMapping(keycode: usize, button: api.InputButtonType) void {
        defer keyboard_on = true;
        keyboard_code_mapping.set(@intFromEnum(button), keycode);
    }

    // GAMEPAD
    // Check if a gamepad is available
    fn isGamepadAvailable(device: api.InputDevice) bool {
        return rl.IsGamepadAvailable(@intFromEnum(device));
    }
    // Get gamepad internal name id
    fn getGamepadName(device: api.InputDevice) String {
        const name: [*c]const u8 = rl.GetGamepadName(@intFromEnum(device));
        const _name: String = std.mem.sliceTo(name, 0);
        return _name;
    }
    fn getGamepadAxisMovement(device: api.InputDevice, axis: api.GamepadAxis) Float {
        return rl.GetGamepadAxisMovement(@intFromEnum(device), @intFromEnum(axis));
    }
    // gamepad mappings
    fn setGamepad1Mapping(device: api.InputDevice) void {
        gamepad_1_code = @intFromEnum(device);
    }
    fn setGamepad2Mapping(device: api.InputDevice) void {
        gamepad_2_code = @intFromEnum(device);
    }
    fn setGamepadButtonMapping(device: api.InputDevice, action: api.GamepadAction, button: api.InputButtonType) void {
        switch (device) {
            .GAME_PAD_1 => {
                defer gamepad_1_on = true;
                gamepad_1_code_mapping.set(
                    @intFromEnum(button),
                    @intFromEnum(action),
                );
            },
            .GAME_PAD_2 => {
                defer gamepad_2_on = true;
                gamepad_2_code_mapping.set(
                    @intFromEnum(button),
                    @intFromEnum(action),
                );
            },
            else => {},
        }
    }

    // MOUSE
    fn getMousePosition() PosF {
        return @bitCast(rl.GetMousePosition());
    }
    fn getMouseDelta() Vector2f {
        return @bitCast(rl.GetMouseDelta());
    }

    fn setMouseButtonMapping(action: api.MouseAction, button: api.InputButtonType) void {
        defer mouse_on = true;
        mouse_code_mapping.set(
            @intFromEnum(button),
            @intFromEnum(action),
        );
    }

    inline fn checkKeyboard(button: api.InputButtonType, action: api.InputActionType) bool {
        const code: CInt = @intCast(keyboard_code_mapping.get(@intFromEnum(button)));
        if (code != UNDEF_INDEX) {
            return switch (action) {
                .ON => rl.IsKeyDown(code),
                .OFF => rl.IsKeyUp(code),
                .TYPED => rl.IsKeyPressed(code),
                .RELEASED => rl.IsKeyReleased(code),
            };
        }
    }

    inline fn checkPad1(button: api.InputButtonType, action: api.InputActionType) bool {
        const code: CInt = @intCast(gamepad_1_code_mapping.get(@intFromEnum(button)));
        if (code != UNDEF_INDEX) {
            return switch (action) {
                .ON => rl.IsGamepadButtonDown(gamepad_1_code, code),
                .OFF => rl.IsGamepadButtonUp(gamepad_1_code, code),
                .TYPED => rl.IsGamepadButtonPressed(gamepad_1_code, code),
                .RELEASED => rl.IsGamepadButtonReleased(gamepad_1_code, code),
            };
        }
    }

    inline fn checkPad2(button: api.InputButtonType, action: api.InputActionType) bool {
        const code: CInt = @intCast(gamepad_2_code_mapping.get(@intFromEnum(button)));
        if (code != UNDEF_INDEX) {
            return switch (action) {
                .ON => rl.IsGamepadButtonDown(gamepad_2_code, code),
                .OFF => rl.IsGamepadButtonUp(gamepad_2_code, code),
                .TYPED => rl.IsGamepadButtonPressed(gamepad_2_code, code),
                .RELEASED => rl.IsGamepadButtonReleased(gamepad_2_code, code),
            };
        }
    }

    inline fn checkMouse(button: api.InputButtonType, action: api.InputActionType) bool {
        const code: CInt = @intCast(mouse_code_mapping.get(@intFromEnum(button)));
        if (code != UNDEF_INDEX) {
            return switch (action) {
                .ON => rl.IsMouseButtonDown(code),
                .OFF => rl.IsMouseButtonUp(code),
                .TYPED => rl.IsMouseButtonPressed(code),
                .RELEASED => rl.IsMouseButtonReleased(code),
            };
        }
    }
};
