const std = @import("std");
pub const firefly = @import("../firefly.zig"); // TODO better way for import package?
pub const utils = @import("../../utils/utils.zig"); // TODO better way for import pack

pub const TextureAsset = @import("TextureAsset.zig");

var initialized = false;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    try TextureAsset.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    TextureAsset.deinit();
}

test {
    std.testing.refAllDecls(@import("TextureAsset.zig"));
}
