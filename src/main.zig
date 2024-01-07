const std = @import("std");
const dynarray = @import("inari/utils/dynarray.zig");

pub fn main() !void {
    const start_time = std.time.milliTimestamp();

    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    try dynarray.testArrayList(allocator);

    const end_time = std.time.milliTimestamp();
    try stdout.print("took: {}\n", .{end_time - start_time});
}
