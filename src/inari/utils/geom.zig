const std = @import("std");

pub const Orientation = enum { NONE, NORTH, EAST, SOUTH, WEST };

test "empty" {
    std.debug.print("comptime fmt: []const u8", .{});
}
