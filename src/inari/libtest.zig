const std = @import("std");

test {
    std.testing.refAllDecls(@import("firefly/utils/testing.zig"));
}
