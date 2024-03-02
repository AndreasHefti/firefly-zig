const std = @import("std");
const inari = @import("inari/inari.zig");
const firefly = inari.firefly;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try firefly.init(
        allocator,
        allocator,
        allocator,
        firefly.api.InitMode.DEVELOPMENT,
    );
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Zig");
}

test {
    std.testing.refAllDecls(@import("inari/libtest.zig"));
}
