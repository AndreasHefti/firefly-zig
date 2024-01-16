const std = @import("std");

pub const FFAPIError = error{
    GenericError,
    GraphicsInitError,
    GraphicsError,
};

pub const ActionType = enum {
    CREATED,
    ACTIVATED,
    DEACTIVATED,
    DISPOSED,
};

test {
    std.testing.refAllDecls(@import("system.zig"));
}
