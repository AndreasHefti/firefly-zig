const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

const StringBuffer = utils.StringBuffer;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    var string_buffer = StringBuffer.init(firefly.api.ALLOC);
    defer string_buffer.deinit();

    firefly.api.Component.print(&string_buffer);
    std.debug.print("{s}", .{string_buffer.toString()});
}
