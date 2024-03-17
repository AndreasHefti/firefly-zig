const std = @import("std");
const inari = @import("../inari/inari.zig");
const firefly = inari.firefly;
const Allocator = std.mem.Allocator;

pub fn run(allocator: Allocator) !void {
    try firefly.init(
        allocator,
        allocator,
        allocator,
        firefly.api.InitMode.DEVELOPMENT,
    );
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Zig", null);
}
