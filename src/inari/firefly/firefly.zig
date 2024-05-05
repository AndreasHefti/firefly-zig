const std = @import("std");
const Allocator = std.mem.Allocator;

//////////////////////////////////////////////////////////////
//// Public declarations
//////////////////////////////////////////////////////////////

// packages
pub const api = @import("api/api.zig");
pub const control = @import("control/control.zig");
pub const graphics = @import("graphics/graphics.zig");
pub const physics = @import("physics/physics.zig");
pub const utils = @import("utils/utils.zig");
pub const Engine = @import("Engine.zig");

var initialized = false;

pub fn initTesting() !void {
    defer initialized = true;
    if (initialized)
        return;

    try init(std.testing.allocator);
}

pub fn initDebug(allocator: Allocator) !void {
    defer initialized = true;
    if (initialized)
        return;

    try init(allocator, allocator, allocator, api.InitMode.DEVELOPMENT);
}

pub fn init(init_c: api.InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    try api.init(init_c);
    try control.init(init_c);
    try graphics.init(init_c);
    try physics.init(init_c);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    physics.deinit();
    graphics.deinit();
    control.deinit();
    api.deinit();
}
