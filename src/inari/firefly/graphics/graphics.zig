const std = @import("std");
const Allocator = std.mem.Allocator;

pub const api = @import("../api/api.zig");
pub const utils = api.utils;

pub const TextureAsset = @import("TextureAsset.zig");
pub const SpriteAsset = @import("SpriteAsset.zig");
pub const SpriteSetAsset = @import("SpriteSetAsset.zig");
pub const ShaderAsset = @import("ShaderAsset.zig");
pub const Layer = @import("view/Layer.zig");
pub const View = @import("view/View.zig");

var initialized = false;

pub fn init(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    defer initialized = true;
    if (initialized) return;

    try api.init(component_allocator, entity_allocator, allocator);
    try TextureAsset.init();
    try SpriteSetAsset.init();
    try SpriteAsset.init();
    try ShaderAsset.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    TextureAsset.deinit();
    SpriteSetAsset.deinit();
    SpriteAsset.deinit();
    ShaderAsset.deinit();
    api.deinit();
}

test {
    std.testing.refAllDecls(@This());
}
