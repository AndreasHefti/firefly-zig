const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const ArrayList = std.ArrayList;
const aspect = @import("aspect.zig");

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn isInitialized() bool {
    return initialized;
}

pub fn init(allocator: Allocator) !void {
    defer initialized = true;
    if (initialized)
        return;

    try aspect.init(allocator);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    aspect.deinit();
}

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
pub const CInt = i32;
pub const Float = f32;
pub const Byte = u8;

pub const EMPTY_STRING: String = "";
pub const NO_NAME: String = EMPTY_STRING;
pub const UNDEF_INDEX = std.math.maxInt(Index);

pub fn usize_i32(v: usize) i32 {
    return @as(i32, @intCast(v));
}

pub fn i32_usize(v: i32) usize {
    if (v < 0) return 0;
    return @as(usize, @intCast(v));
}

pub fn i64_usize(v: i64) usize {
    if (v < 0) return 0;
    return @as(usize, @intCast(v));
}

pub fn usize_i64(v: usize) i64 {
    return @as(i64, @intCast(v));
}

pub fn usize_f32(v: usize) f32 {
    return @as(f32, @floatFromInt(v));
}

pub fn f32_usize(v: f32) usize {
    return @as(usize, @intFromFloat(v));
}

pub fn cint_usize(v: c_int) usize {
    return @as(usize, @intCast(v));
}

pub fn usize_cint(v: usize) c_int {
    return @as(c_int, @intCast(v));
}

pub const Aspect = aspect.Aspect;
pub const AspectGroup = aspect.AspectGroup;
pub const Kind = aspect.Kind;

pub fn Condition(comptime T: type) type {
    return struct {
        const Self = @This();
        f: *const fn (T) bool,

        pub fn of(f: *const fn (T) bool) Self {
            return Self{
                .f = f,
            };
        }

        pub fn check(self: Self, t: T) bool {
            return self.f(t);
        }
    };
}

pub const StringBuffer = struct {
    buffer: std.ArrayList(u8),

    pub fn init(allocator: Allocator) StringBuffer {
        return StringBuffer{
            .buffer = ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: StringBuffer) void {
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

//////////////////////////////////////////////////////////////
//// module debug/testing api
//////////////////////////////////////////////////////////////

pub const debug = struct {
    pub const printAspects = aspect.print;
};
