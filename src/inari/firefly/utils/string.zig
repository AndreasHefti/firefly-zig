const std = @import("std");
const utils = @import("utils.zig");
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

pub const String = []const u8;
pub const CString = [*c]const u8;

pub fn stringEquals(s1: String, s2: String) bool {
    return std.mem.eql(u8, s1, s2);
}

pub fn stringStartsWith(str: ?String, prefix: String) bool {
    if (str) |s|
        return std.mem.eql(u8, prefix, s[0..prefix.len]);

    return false;
}

pub const StringBuffer = struct {
    buffer: std.ArrayList(u8),

    pub fn init(allocator: Allocator) StringBuffer {
        return StringBuffer{
            .buffer = std.ArrayList(u8).init(allocator),
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

pub const StringPropertyIterator = struct {
    delegate: std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar),

    pub fn new(s: String) StringPropertyIterator {
        return StringPropertyIterator{ .delegate = std.mem.splitScalar(u8, s, '|') };
    }

    pub inline fn next(self: *StringPropertyIterator) ?String {
        return self.delegate.next();
    }

    pub inline fn nextAspect(self: *StringPropertyIterator, comptime aspect_group: anytype) ?aspect_group.Aspect {
        if (self.delegate.next()) |s|
            return aspect_group.getAspectIfExists(s);
        return null;
    }

    pub inline fn nextName(self: *StringPropertyIterator) ?String {
        if (self.delegate.next()) |s|
            return utils.parseName(s);
        return null;
    }

    pub inline fn nextBoolean(self: *StringPropertyIterator) bool {
        return utils.parseBoolean(self.delegate.next());
    }

    pub inline fn nextFloat(self: *StringPropertyIterator) ?utils.Float {
        return utils.parseFloat(self.delegate.next());
    }

    pub inline fn nextIndex(self: *StringPropertyIterator) ?utils.Index {
        return utils.parseUsize(self.delegate.next());
    }

    pub inline fn nextPosF(self: *StringPropertyIterator) ?utils.PosF {
        return utils.parsePosF(self.delegate.next());
    }

    pub inline fn nextRectF(self: *StringPropertyIterator) ?utils.RectF {
        return utils.parseRectF(self.delegate.next());
    }

    pub inline fn nextColor(self: *StringPropertyIterator) ?utils.Color {
        return utils.parseColor(self.delegate.next());
    }

    pub inline fn nextOrientation(self: *StringPropertyIterator) ?utils.Orientation {
        if (next(self)) |n|
            return utils.Orientation.byName(n);
        return null;
    }
};

pub const StringAttributeIterator = struct {
    delegate: std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar),

    pub const Result = struct {
        name: String,
        value: String,
    };

    pub fn new(s: String) StringAttributeIterator {
        return .{ .delegate = std.mem.splitScalar(u8, s, '|') };
    }

    pub inline fn next(self: *StringAttributeIterator) ?Result {
        if (self.delegate.next()) |attr_str| {
            var it = std.mem.splitScalar(u8, attr_str, '=');
            return .{
                .name = it.next().?,
                .value = it.next().?,
            };
        }
        return null;
    }
};

pub const StringAttributeMap = struct {
    map: std.StringArrayHashMap(String) = undefined,

    pub fn new(s: String, allocator: std.mem.Allocator) StringAttributeMap {
        var result = StringAttributeMap{ .map = std.StringArrayHashMap(String).init(allocator) };
        var it = StringAttributeIterator.new(s);
        while (it.next()) |r|
            result.map.put(r.name, r.value) catch unreachable;
        return result;
    }

    pub fn get(self: *StringAttributeMap, name: String) String {
        return self.map.get(name).?;
    }

    pub fn getOptinal(self: *StringAttributeMap, name: String) ?String {
        return self.map.get(name);
    }

    pub fn deinit(self: *StringAttributeMap) void {
        self.map.deinit();
    }
};

pub const StringListIterator = struct {
    delegate: std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar),

    pub fn new(s: String) StringListIterator {
        return .{ .delegate = std.mem.splitScalar(u8, s, '\n') };
    }

    pub inline fn next(self: *StringListIterator) ?String {
        return self.delegate.next();
    }
};
