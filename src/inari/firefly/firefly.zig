const std = @import("std");
//const inari = @import("../../inari.zig");
//const utils = inari.utils;

const Allocator = std.mem.Allocator;

// TODO make modules
pub const api = @import("api/api.zig");
pub const graphics = @import("graphics/graphics.zig");
pub const physics = @import("physics/physics.zig");

//pub var RENDER_API: rendering_api.RenderAPI() = undefined;
var initialized = false;

pub fn initTesting() !void {
    defer initialized = true;
    if (initialized)
        return;

    try init(std.testing.allocator, std.testing.allocator, std.testing.allocator, api.InitMode.TESTING);
}

pub fn initDebug(allocator: Allocator) !void {
    defer initialized = true;
    if (initialized)
        return;

    try init(allocator, allocator, allocator, api.InitMode.DEVELOPMENT);
}

pub fn init(
    component_allocator: Allocator,
    entity_allocator: Allocator,
    allocator: Allocator,
    initMode: api.InitMode,
) !void {
    defer initialized = true;
    if (initialized)
        return;

    try api.init(component_allocator, entity_allocator, allocator, initMode);
    try graphics.init(initMode);
    try physics.init(initMode);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    physics.deinit();
    graphics.deinit();
    api.deinit();
}
