const std = @import("std");
const inari = @import("../inari/inari.zig");
const firefly = inari.firefly;
const utils = inari.utils;

const StringBuffer = utils.StringBuffer;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    var string_buffer = StringBuffer.init(firefly.api.ALLOC);
    defer string_buffer.deinit();

    firefly.api.Component.print(&string_buffer);
    std.debug.print("{s}", .{string_buffer.toString()});
}
