const std = @import("std");
const Allocator = std.mem.Allocator;

const api = @import("../api/api.zig");
const utils = @import("utils");

pub const TextureAsset = @import("TextureAsset.zig");

var initialized = false;

pub fn init(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    defer initialized = true;
    if (initialized) return;

    try api.init(component_allocator, entity_allocator, allocator);
    try TextureAsset.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    TextureAsset.deinit();
    api.deinit();
}

test {
    std.testing.refAllDecls(@import("TextureAsset.zig"));
}
