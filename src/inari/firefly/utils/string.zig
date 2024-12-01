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

//////////////////////////////////////////////////////////////
//// Name Pool used for none constant Strings not living
//// in zigs data mem. These can be de-allocated by call
//// or will be freed all on package deinit
//////////////////////////////////////////////////////////////

pub const NamePool = struct {
    var names: std.BufSet = undefined;
    var c_names: std.ArrayList([:0]const u8) = undefined;

    var _ally: std.mem.Allocator = undefined;

    pub fn init(allocator: std.mem.Allocator) void {
        _ally = allocator;
        names = std.BufSet.init(allocator);
        c_names = std.ArrayList([:0]const u8).init(allocator);
    }

    pub fn deinit() void {
        names.deinit();

        freeCNames();
        c_names.deinit();
    }

    pub fn alloc(name: ?String) ?String {
        if (name) |n| {
            if (names.contains(n))
                return names.hash_map.getKey(n);

            names.insert(n) catch unreachable;
            //std.debug.print("************ NamePool names add: {s}\n", .{n});
            return names.hash_map.getKey(n);
        }
        return null;
    }

    pub fn format(comptime fmt: String, args: anytype) String {
        const formatted = std.fmt.allocPrint(_ally, fmt, args) catch unreachable;
        defer _ally.free(formatted);
        return alloc(formatted).?;
    }

    pub fn getCName(name: ?String) ?CString {
        if (name) |n| {
            const _n = _ally.dupeZ(u8, n) catch unreachable;
            c_names.append(_n) catch unreachable;
            //std.debug.print("************ NamePool c_names add: {s}\n", .{_n});
            return @ptrCast(_n);
        }
        return null;
    }

    pub fn _getCName(name: String) CString {
        const _n = _ally.dupeZ(u8, name) catch unreachable;
        c_names.append(_n) catch unreachable;
        return @ptrCast(_n);
    }

    pub fn freeCNames() void {
        for (c_names.items) |item|
            _ally.free(item);
        c_names.clearRetainingCapacity();
    }

    pub fn indexToString(index: ?utils.Index) ?String {
        if (index) |i| {
            const str = std.fmt.allocPrint(_ally, "{d}", i) catch return null;
            defer _ally.free(str);
            names.insert(str) catch unreachable;
            return names.hash_dict.getKey(str);
        }
        return null;
    }

    pub fn free(name: String) void {
        names.remove(name);
    }
};

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

pub const PropertyIterator = struct {
    delegate: std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar),

    pub fn new(s: String) PropertyIterator {
        return PropertyIterator{ .delegate = std.mem.splitScalar(u8, s, '|') };
    }

    pub inline fn next(self: *PropertyIterator) ?String {
        return self.delegate.next();
    }

    pub inline fn nextAspect(self: *PropertyIterator, comptime aspect_group: anytype) ?aspect_group.Aspect {
        if (self.delegate.next()) |s|
            return aspect_group.getAspectIfExists(s);
        return null;
    }

    pub inline fn nextName(self: *PropertyIterator) ?String {
        if (self.delegate.next()) |s|
            return NamePool.alloc(utils.parseName(s));
        return null;
    }

    pub inline fn nextBoolean(self: *PropertyIterator) bool {
        return utils.parseBoolean(self.delegate.next());
    }

    pub inline fn nextFloat(self: *PropertyIterator) ?utils.Float {
        return utils.parseFloat(self.delegate.next());
    }

    pub inline fn nextIndex(self: *PropertyIterator) ?utils.Index {
        return utils.parseUsize(self.delegate.next());
    }

    pub inline fn nextPosF(self: *PropertyIterator) ?utils.PosF {
        return utils.parsePosF(self.delegate.next());
    }

    pub inline fn nextRectF(self: *PropertyIterator) ?utils.RectF {
        return utils.parseRectF(self.delegate.next());
    }

    pub inline fn nextColor(self: *PropertyIterator) ?utils.Color {
        return utils.parseColor(self.delegate.next());
    }

    pub inline fn nextOrientation(self: *PropertyIterator) ?utils.Orientation {
        if (next(self)) |n|
            return utils.Orientation.byName(n);
        return null;
    }
};

pub const AttributeIterator = struct {
    delegate: std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar),

    pub const Result = struct {
        name: String,
        value: String,
    };

    pub fn new(s: String) AttributeIterator {
        return .{ .delegate = std.mem.splitScalar(u8, s, '|') };
    }

    pub inline fn next(self: *AttributeIterator) ?Result {
        if (self.delegate.next()) |attr_str| {
            var it = std.mem.splitScalar(u8, attr_str, '=');
            return .{
                .name = NamePool.alloc(it.next()).?,
                .value = NamePool.alloc(it.next()).?,
            };
        }
        return null;
    }
};
