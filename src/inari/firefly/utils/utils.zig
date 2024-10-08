const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const ArrayList = std.ArrayList;
const aspect = @import("aspect.zig");
const StringHashMap = std.StringHashMap;

//////////////////////////////////////////////////////////////
//// inari utils public API
//////////////////////////////////////////////////////////////

pub usingnamespace @import("geom.zig");
pub usingnamespace @import("event.zig");
pub usingnamespace @import("dynarray.zig");
pub usingnamespace @import("bitset.zig");

pub const String = []const u8;
pub const CString = [*c]const u8;
pub const Index = usize;
pub const CInt = c_int;
pub const CUInt = c_uint;
pub const Float = f32;
pub const Byte = u8;

pub const EMPTY_STRING: String = "";
//pub const NO_NAME: String = EMPTY_STRING;
pub const UNDEF_INDEX = std.math.maxInt(Index);

pub const Test = struct { array: []Index = &[_]Index{ 1, 2, 3 } };

pub fn stringEquals(s1: String, s2: String) bool {
    return std.mem.eql(u8, s1, s2);
}

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

pub const AspectGroup = aspect.AspectGroup;

pub const StringBuffer = struct {
    buffer: std.ArrayList(u8),

    pub fn init(allocator: Allocator) StringBuffer {
        return StringBuffer{
            .buffer = ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *StringBuffer) void {
        clear(self);
        self.buffer.deinit();
    }

    pub fn clear(self: *StringBuffer) void {
        self.buffer.clearAndFree();
    }

    pub fn append(self: *StringBuffer, s: String) void {
        self.buffer.writer().writeAll(s) catch |e| {
            std.log.err("Failed to write to string buffer .{any}", .{e});
        };
    }

    pub fn print(self: *StringBuffer, comptime s: String, args: anytype) void {
        self.buffer.writer().print(s, args) catch |e| {
            std.log.err("Failed to write to string buffer .{any}", .{e});
        };
    }

    pub fn toString(self: StringBuffer) String {
        return self.buffer.items[0..];
    }
};

pub fn getNullPointer(comptime T: type) *const ?T {
    const t: ?T = null;
    return &t;
}

pub inline fn panic(allocator: Allocator, comptime template: String, args: anytype) void {
    const msg = std.fmt.allocPrint(allocator, template, args) catch unreachable;
    defer allocator.free(msg);
    @panic(msg);
}
