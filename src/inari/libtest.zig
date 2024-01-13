const std = @import("std");

test {
    std.testing.refAllDecls(@import("utils/utils.zig"));
    std.testing.refAllDecls(@import("firefly/api/api.zig"));
}
