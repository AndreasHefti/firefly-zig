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
pub const ETransform = @import("view/ETransform.zig");

var initialized = false;
var api_init = false;

pub fn initTesting() !void {
    try api.initTesting();
    try init(api.InitMode.TESTING);
    api_init = true;
}

pub fn init(_: api.InitMode) !void {
    defer initialized = true;
    if (initialized)
        return;

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
    if (api_init) {
        api.deinit();
        api_init = false;
    }
}

test {
    std.testing.refAllDecls(@This());
}
