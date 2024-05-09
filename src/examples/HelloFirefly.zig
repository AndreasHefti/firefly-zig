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
    string_buffer.print("\n\n", .{});
    firefly.api.ComponentAspectGroup.print(&string_buffer);
    string_buffer.print("\n", .{});
    firefly.api.EComponentAspectGroup.print(&string_buffer);
    string_buffer.print("\n", .{});
    firefly.api.AssetAspectGroup.print(&string_buffer);
    string_buffer.print("\n", .{});
    firefly.physics.MovementAspectGroup.print(&string_buffer);
    string_buffer.print("\n", .{});
    firefly.physics.ContactMaterialAspectGroup.print(&string_buffer);
    string_buffer.print("\n", .{});
    firefly.physics.ContactTypeAspectGroup.print(&string_buffer);
    string_buffer.print("\n\n", .{});

    std.debug.print("{s}", .{string_buffer.toString()});
}
