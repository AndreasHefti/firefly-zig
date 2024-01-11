const std = @import("std");

test {
    std.testing.refAllDecls(@import("utils/bitset.zig"));
    std.testing.refAllDecls(@import("utils/dynarray.zig"));
    std.testing.refAllDecls(@import("utils/geom.zig"));
    std.testing.refAllDecls(@import("utils/vector.zig"));
}
