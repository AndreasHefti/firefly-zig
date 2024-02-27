const std = @import("std");

test {
    std.testing.refAllDecls(@import("utils/testing.zig"));
    std.testing.refAllDecls(@import("firefly/testing.zig"));
}

// not working
// test "boolean vec operations" {
//     const BoolVec = @Vector(4, bool);
//     var v1: BoolVec = BoolVec{ true, true, false, false };
//     var v2: BoolVec = BoolVec{ true, false, true, false };
//     var v3 = v1 and v2;
//     std.testing.expect(v3[0]);
//     std.testing.expect(!v3[1]);
//     std.testing.expect(!v3[2]);
//     std.testing.expect(!v3[3]);
// }
