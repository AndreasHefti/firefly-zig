const std = @import("std");
const inari = @import("../../../inari.zig");
const rl = @cImport(@cInclude("raylib.h"));

const utils = inari.utils;
const api = inari.firefly.api;

const IInputAPI = api.IInputAPI;
const InputDevice = api.InputDevice;
const InputActionType = api.InputActionType;
const InputButtonType = api.InputButtonType;
const GamepadAction = api.GamepadAction;
const GamepadAxis = api.GamepadAxis;
const MouseAction = api.MouseAction;
const DynIndexArray = utils.DynIndexArray;
const CInt = utils.CInt;
const Vector2f = utils.Vector2f;
const PosF = utils.PosF;
const Float = utils.Float;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const String = utils.String;

var singleton: ?IInputAPI() = null;
pub fn createInputAPI() !IInputAPI() {
    if (singleton == null)
        singleton = IInputAPI().init(RaylibInputAPI.initImpl);

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

    var keyboard_code_mapping: DynIndexArray = undefined;
    var gamepad_1_code_mapping: DynIndexArray = undefined;
    var gamepad_2_code_mapping: DynIndexArray = undefined;
    var mouse_code_mapping: DynIndexArray = undefined;

    fn initImpl(interface: *IInputAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        keyboard_code_mapping = DynIndexArray.init(api.ALLOC, 10);
        gamepad_1_code_mapping = DynIndexArray.init(api.ALLOC, 10);
        gamepad_2_code_mapping = DynIndexArray.init(api.ALLOC, 10);
        mouse_code_mapping = DynIndexArray.init(api.ALLOC, 10);

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
    }

    // check the button type for specified action. Button type must have been mapped on one or many devices
    fn checkButton(button: InputButtonType, action: InputActionType, input: ?InputDevice) bool {
        if (input) |in| {
            return switch (in) {
                InputDevice.KEYBOARD => checkKeyboard(button, action),
                InputDevice.GAME_PAD_1 => checkPad1(button, action),
                InputDevice.GAME_PAD_2 => checkPad2(button, action),
                InputDevice.MOUSE => checkMouse(button, action),
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
    fn setKeyButtonMapping(keycode: usize, button: InputButtonType) void {
        defer keyboard_on = true;
        keyboard_code_mapping.set(@intFromEnum(button), keycode);
    }

    // GAMEPAD
    // Check if a gamepad is available
    fn isGamepadAvailable(device: InputDevice) bool {
        return rl.IsGamepadAvailable(@intFromEnum(device));
    }
    // Get gamepad internal name id
    fn getGamepadName(device: InputDevice) String {
        const name: [*c]const u8 = rl.GetGamepadName(@intFromEnum(device));
        var _name: String = std.mem.sliceTo(name, 0);
        return _name;
    }
    fn getGamepadAxisMovement(device: InputDevice, axis: GamepadAxis) Float {
        return rl.GetGamepadAxisMovement(@intFromEnum(device), @intFromEnum(axis));
    }
    // gamepad mappings
    fn setGamepad1Mapping(device: InputDevice) void {
        gamepad_1_code = @intFromEnum(device);
    }
    fn setGamepad2Mapping(device: InputDevice) void {
        gamepad_2_code = @intFromEnum(device);
    }
    fn setGamepadButtonMapping(device: InputDevice, action: GamepadAction, button: InputButtonType) void {
        switch (device) {
            InputDevice.GAME_PAD_1 => {
                defer gamepad_1_on = true;
                gamepad_1_code_mapping.set(
                    @intFromEnum(button),
                    @intFromEnum(action),
                );
            },
            InputDevice.GAME_PAD_2 => {
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

    fn setMouseButtonMapping(action: MouseAction, button: InputButtonType) void {
        defer mouse_on = true;
        mouse_code_mapping.set(
            @intFromEnum(button),
            @intFromEnum(action),
        );
    }

    inline fn checkKeyboard(button: InputButtonType, action: InputActionType) bool {
        var code: CInt = @intCast(keyboard_code_mapping.get(@intFromEnum(button)));
        if (code != UNDEF_INDEX) {
            return switch (action) {
                InputActionType.ON => rl.IsKeyDown(code),
                InputActionType.OFF => rl.IsKeyUp(code),
                InputActionType.TYPED => rl.IsKeyPressed(code),
                InputActionType.RELEASED => rl.IsKeyReleased(code),
            };
        }
    }

    inline fn checkPad1(button: InputButtonType, action: InputActionType) bool {
        var code: CInt = @intCast(gamepad_1_code_mapping.get(@intFromEnum(button)));
        if (code != UNDEF_INDEX) {
            return switch (action) {
                InputActionType.ON => rl.IsGamepadButtonDown(gamepad_1_code, code),
                InputActionType.OFF => rl.IsGamepadButtonUp(gamepad_1_code, code),
                InputActionType.TYPED => rl.IsGamepadButtonPressed(gamepad_1_code, code),
                InputActionType.RELEASED => rl.IsGamepadButtonReleased(gamepad_1_code, code),
            };
        }
    }

    inline fn checkPad2(button: InputButtonType, action: InputActionType) bool {
        var code: CInt = @intCast(gamepad_2_code_mapping.get(@intFromEnum(button)));
        if (code != UNDEF_INDEX) {
            return switch (action) {
                InputActionType.ON => rl.IsGamepadButtonDown(gamepad_2_code, code),
                InputActionType.OFF => rl.IsGamepadButtonUp(gamepad_2_code, code),
                InputActionType.TYPED => rl.IsGamepadButtonPressed(gamepad_2_code, code),
                InputActionType.RELEASED => rl.IsGamepadButtonReleased(gamepad_2_code, code),
            };
        }
    }

    inline fn checkMouse(button: InputButtonType, action: InputActionType) bool {
        var code: CInt = @intCast(mouse_code_mapping.get(@intFromEnum(button)));
        if (code != UNDEF_INDEX) {
            return switch (action) {
                InputActionType.ON => rl.IsMouseButtonDown(code),
                InputActionType.OFF => rl.IsMouseButtonUp(code),
                InputActionType.TYPED => rl.IsMouseButtonPressed(code),
                InputActionType.RELEASED => rl.IsMouseButtonReleased(code),
            };
        }
    }
};
