const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const assert = std.debug.assert;

var initialized = false;

pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////
