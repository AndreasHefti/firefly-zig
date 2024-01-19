const std = @import("std");

pub const bitset = @import("bitset.zig");
pub const dynarray = @import("dynarray.zig");
pub const geom = @import("geom.zig");
pub const aspect = @import("aspect.zig");
pub const event = @import("event.zig");

pub const String = []const u8;
pub const EMPTY_STRING: String = "";
pub const NO_NAME: String = EMPTY_STRING;

pub const CInt = i32;
pub const UNDEF_INDEX = std.math.maxInt(usize);
pub const Float = f32;
pub const Byte = u8;

test {
    std.testing.refAllDecls(@import("bitset.zig"));
    std.testing.refAllDecls(@import("dynarray.zig"));
    std.testing.refAllDecls(@import("geom.zig"));
    std.testing.refAllDecls(@import("event.zig"));
    std.testing.refAllDecls(@import("aspect.zig"));
}
