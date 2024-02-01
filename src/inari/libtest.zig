const std = @import("std");

test {
    std.testing.refAllDecls(@import("utils"));
    std.testing.refAllDecls(@import("firefly/firefly.zig"));
}
