const std = @import("std");
pub const bitset = @import("bitset.zig");
pub const dynarray = @import("dynarray.zig");
pub const geom = @import("geom.zig");

pub const String = []u8;
pub const EMPTY_STRING: String = "";
pub const NO_NAME: String = EMPTY_STRING;

pub const Int = i32;
pub const UNDEF_INT = std.math.minInt(i32);
pub const Float = f32;
pub const Byte = u8;

test {
    std.testing.refAllDecls(@import("bitset.zig"));
    std.testing.refAllDecls(@import("dynarray.zig"));
    std.testing.refAllDecls(@import("geom.zig"));
}
