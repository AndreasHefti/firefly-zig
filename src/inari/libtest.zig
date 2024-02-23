const std = @import("std");

test {
    std.testing.refAllDecls(@import("utils/testing.zig"));
    std.testing.refAllDecls(@import("firefly/testing.zig"));
}
