const std = @import("std");
const aspect = @import("aspect.zig");
const string = @import("string.zig");
const dynarray = @import("dynarray.zig");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const ArrayList = std.ArrayList;

const StringHashMap = std.StringHashMap;

//////////////////////////////////////////////////////////////
//// inari utils public API
//////////////////////////////////////////////////////////////

pub const Index = usize;
pub const CInt = c_int;
pub const CUInt = c_uint;
pub const Float = f32;
pub const Byte = u8;

pub const IntBitMask = usize;

pub const String = string.String;
pub const CString = string.CString;
pub const String0 = string.String0;
pub const StringBuffer = string.StringBuffer;
pub const StringPropertyIterator = string.StringPropertyIterator;
pub const StringAttributeIterator = string.StringAttributeIterator;
pub const StringAttributeMap = string.StringAttributeMap;
pub const StringListIterator = string.StringListIterator;
pub const stringEquals = string.stringEquals;
pub const stringStartsWith = string.stringStartsWith;

pub const AspectGroup = aspect.AspectGroup;

pub const DynArrayError = dynarray.DynArrayError;
pub const DynArray = dynarray.DynArray;
pub const DynIndexArray = dynarray.DynIndexArray;
pub const DynIndexMap = dynarray.DynIndexMap;

pub usingnamespace @import("geom.zig");
pub usingnamespace @import("event.zig");
pub usingnamespace @import("bitset.zig");

pub const EMPTY_STRING: String = "";
pub const UNDEF_INDEX: Index = std.math.maxInt(Index);
pub const IndexFormatter = struct {
    index: Index,

    pub fn format(
        self: IndexFormatter,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (self.index == UNDEF_INDEX) {
            try writer.print("-", .{});
        } else {
            try writer.print("{d}", .{self.index});
        }
    }
};

pub inline fn usize_i32(v: usize) i32 {
    return @as(i32, @intCast(v));
}

pub inline fn i32_usize(v: i32) usize {
    if (v < 0) return 0;
    return @as(usize, @intCast(v));
}

pub inline fn i64_usize(v: i64) usize {
    if (v < 0) return 0;
    return @as(usize, @intCast(v));
}

pub inline fn usize_i64(v: usize) i64 {
    return @as(i64, @intCast(v));
}

pub inline fn usize_f32(v: usize) f32 {
    return @as(f32, @floatFromInt(v));
}

pub inline fn f32_usize(v: f32) usize {
    if (v < 0) return 0;
    return @as(usize, @intFromFloat(v));
}

pub inline fn cint_usize(v: c_int) usize {
    if (v < 0) return 0;
    return @as(usize, @intCast(v));
}

pub inline fn cint_float(v: c_int) Float {
    return @as(Float, @floatFromInt(v));
}

pub inline fn usize_cint(v: usize) c_int {
    return @as(c_int, @intCast(v));
}

pub inline fn f32_cint(v: f32) c_int {
    return @as(c_int, @intCast(f32_usize(v)));
}

pub inline fn maskBit(index: usize) usize {
    return @as(usize, 1) << @as(std.math.Log2Int(usize), @truncate(index));
}

pub inline fn setBit(index: usize, mask: IntBitMask) usize {
    return mask | maskBit(index);
}

pub fn setBits(bits: anytype) usize {
    var res: usize = 0;
    inline for (bits) |b| {
        res |= maskBit(b);
    }
    return res;
}

pub fn resetBit(index: usize, mask: IntBitMask) usize {
    return mask & ~maskBit(index);
}

pub inline fn digit(num: usize, position: u8) u8 {
    return std.fmt.digitToChar(
        @as(u8, @intCast(@mod(num / std.math.pow(usize, 10, position), 10))),
        std.fmt.Case.lower,
    );
}

pub inline fn parseBoolean(value: ?String) bool {
    if (value) |v| {
        if (v.len == 0)
            return false;
        return v[0] != '0' or stringEquals("true", v) or stringEquals("TRUE", v);
    }
    return false;
}

pub inline fn parseFloat(value: ?String) Float {
    if (value) |v| {
        if (v.len == 0) return 0;
        return std.fmt.parseFloat(Float, v) catch 0;
    }
    return 0;
}

pub inline fn parseName(value: ?String) ?String {
    if (value) |v| {
        if (v.len == 0) return null;
        if (std.mem.eql(u8, v, "-")) return null;
        return v;
    }
    return null;
}

pub fn getNullPointer(comptime T: type) *const ?T {
    const t: ?T = null;
    return &t;
}

pub fn enumByName(comptime E: type, name: ?String) ?E {
    if (name) |n| {
        const e = std.enums.values(E);
        for (0..e.len) |i| {
            if (stringEquals(@tagName(e[i]), n))
                return @enumFromInt(i);
        }
    }
    return null;
}
