const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const ArrayList = std.ArrayList;

pub const bitset = @import("bitset.zig");
pub const dynarray = @import("dynarray.zig");
pub const geom = @import("geom.zig");
pub const aspect = @import("aspect.zig");
pub const event = @import("event.zig");

pub const String = []const u8;
pub const EMPTY_STRING: String = "";
pub const NO_NAME: String = EMPTY_STRING;
pub const Index = usize;
pub const UNDEF_INDEX = std.math.maxInt(Index);

pub const CInt = i32;
pub const Float = f32;
pub const Byte = u8;

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

test "StringBuffer" {
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    sb.append("Test12");
    sb.append("Test34");
    sb.print("Test{s}", .{"56"});

    var str = sb.toString();
    try std.testing.expectEqualStrings("Test12Test34Test56", str);
}

test "repl test" {
    var v = getReadwrite();
    v[0] = 0;
}

var v1: geom.Vector2f = geom.Vector2f{ 0, 0 };
pub fn getReadonly() *const geom.Vector2f {
    return &v1;
}

pub fn getReadwrite() *geom.Vector2f {
    return &v1;
}

test {
    std.testing.refAllDecls(@This());
}
