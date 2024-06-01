const std = @import("std");
const firefly = @import("../firefly.zig");

//////////////////////////////////////////////////////////////
//// game room init
//////////////////////////////////////////////////////////////

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
