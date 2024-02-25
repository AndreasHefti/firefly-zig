const std = @import("std");
pub const inari = @import("inari/inari.zig");

pub fn main() !void {
    const start_time = std.time.milliTimestamp();

    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }

    try inari.firefly.init(allocator, allocator, allocator, inari.firefly.api.InitMode.TESTING);
    defer inari.firefly.deinit();

    //try dynarray.testArrayList(allocator);

    const end_time = std.time.milliTimestamp();
    try stdout.print("took: {}\n", .{end_time - start_time});
}

test {
    std.testing.refAllDecls(@import("inari/libtest.zig"));
}
