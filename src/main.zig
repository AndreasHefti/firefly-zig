const std = @import("std");
const utils = @import("utils");

pub fn main() !void {
    const start_time = std.time.milliTimestamp();

    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    //try dynarray.testArrayList(allocator);
    try utils.init(allocator);
    defer utils.deinit();

    const end_time = std.time.milliTimestamp();
    try stdout.print("took: {}\n", .{end_time - start_time});
}

test {
    std.testing.refAllDecls(@import("inari/libtest.zig"));
}
