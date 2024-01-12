const std = @import("std");

test {
    std.testing.refAllDecls(@import("utils/utils.zig"));
}
