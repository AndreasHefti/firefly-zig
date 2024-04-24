const std = @import("std");

test {
    std.testing.refAllDecls(@import("utils/testing.zig"));
}
