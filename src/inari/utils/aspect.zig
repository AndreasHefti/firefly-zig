const std = @import("std");
const utils = @import("utils.zig");
const String = utils.String;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

/// The integer type used to represent a Kind
const MaskInt = u128;
/// Maximal number of aspects possible for one aspect group
const MaxIndex = 128;
/// The integer type used to shift a bit mask
const ShiftInt = std.math.Log2Int(MaskInt);
// aspect namespace variables and state

var ASPECT_GROUPS: ArrayList(AspectGroup) = undefined;
var ALLOCATOR: Allocator = undefined;
var initialized = false;

pub fn isInitialized() bool {
    return initialized;
}

fn checkInitialized() void {
    if (!initialized)
        @panic("aspect module not initialized");
}

pub fn init(_allocator: Allocator) !void {
    defer initialized = true;
    if (!initialized) {
        ALLOCATOR = _allocator;
        ASPECT_GROUPS = try ArrayList(AspectGroup).initCapacity(ALLOCATOR, 10);
        errdefer deinit();
    }
}

pub fn deinit() void {
    defer initialized = false;
    if (initialized) {
        ASPECT_GROUPS.deinit();
        ASPECT_GROUPS = undefined;
        ALLOCATOR = undefined;
    }
}

pub fn print(string_buffer: *utils.StringBuffer) void {
    if (!initialized) {
        string_buffer.append("Aspects: [ NOT initialized ]\n");
        return;
    }

    string_buffer.append("Aspects:");
    if (ASPECT_GROUPS.items.len == 0) {
        string_buffer.append("EMPTY");
    } else {
        var gi: usize = 0;
        for (ASPECT_GROUPS.items) |item| {
            string_buffer.print("\n  Group[{s}|{}]:", .{ item.name, gi });
            for (0..item._size) |i| {
                string_buffer.print("\n    Aspect[{s}|{d}]", .{ item.aspects[i].name, item.aspects[i].index });
            }
            gi += 1;
        }
    }
    _ = string_buffer.append("\n");
}

pub const Aspect = struct {
    group: *AspectGroup,
    name: String,
    index: u8,

    pub fn getAspect(groupName: []const u8, aspectName: []const u8) !*Aspect {
        const group = try findOrCreateAspectGroup(groupName);
        return group.getAspect(aspectName);
    }

    pub fn sameGroup(self: *Aspect, other: *const Aspect) bool {
        return std.mem.eql(u8, self.group.name, other.group.name);
    }

    pub fn isOfGroup(self: *Aspect, group: *const AspectGroup) bool {
        return std.mem.eql(u8, self.group.name, group.name);
    }

    pub fn format(
        self: Aspect,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Aspect[{s}|{s}|{d}]",
            .{ self.group.name, self.name, self.index },
        );
    }
};

pub const AspectGroup = struct {
    /// The name of the aspect group
    name: String,
    /// The aspects of the aspect group. NOTE: max MaxIndex aspects per group possible
    aspects: [MaxIndex]Aspect,
    /// the actual size of the group (and pointer for next aspect insertion).
    /// NOTE: This value is shall only be modified internally. Do not modify this value from outside.
    _size: u8 = 0,

    pub fn new(name: String) !*AspectGroup {
        checkInitialized();
        var new_group = AspectGroup{
            .name = name,
            .aspects = [_]Aspect{undefined} ** MaxIndex,
        };
        try ASPECT_GROUPS.append(new_group);
        return &ASPECT_GROUPS.items[ASPECT_GROUPS.items.len - 1];
    }

    pub fn get(name: String) !*AspectGroup {
        checkInitialized();

        for (ASPECT_GROUPS.items) |*group| {
            if (std.mem.eql(u8, name, group.name)) {
                return group;
            }
        }

        @panic("No Aspect Group Found");
    }

    pub fn dispose(name: String) void {
        if (!initialized)
            return;

        var index: ?usize = null;
        for (ASPECT_GROUPS.items, 0..) |*group, i| {
            if (std.mem.eql(u8, name, group.name)) {
                index = i;
                break;
            }
        }
        if (index) |i| {
            _ = ASPECT_GROUPS.swapRemove(i);
        }
    }

    pub fn getAspect(self: *AspectGroup, name: String) *Aspect {
        //std.debug.print("\n************* group {s} aspect size {d}\n", .{ self.name, self._size });
        // check if aspect with name already exists
        for (0..self._size) |i| {
            if (std.mem.eql(u8, self.aspects[i].name, name)) {
                return &self.aspects[i];
            }
        }

        // if not exists already, create new one
        self.aspects[self._size].group = self;
        self.aspects[self._size].name = name;
        self.aspects[self._size].index = self._size;

        defer self._size += 1;
        return &self.aspects[self._size];
    }
};

pub const Kind = struct {
    /// Reference to the aspect group this kind belongs to
    group: *AspectGroup,
    /// The bitmask to store indices of owned aspects of this kind
    _mask: MaskInt = 0,

    pub fn ofGroup(g: *AspectGroup) Kind {
        return Kind{
            .group = g,
        };
    }

    pub fn of(aspect: anytype) Kind {
        return Kind{
            .group = aspect.group,
            ._mask = 0 | maskBit(aspect.index),
        };
    }

    pub fn with(self: Kind, aspect: *Aspect) Kind {
        if (self.group != aspect.group)
            return self;

        var kind = self;
        kind._mask |= maskBit(aspect.index);
        return kind;
    }

    pub fn hasAspect(self: *Kind, aspect: *Aspect) bool {
        if (self.group != aspect.group)
            return false;

        return self._mask & maskBit(aspect.index) > 0;
    }

    pub fn unionKind(self: *Kind, other: *const Kind) Kind {
        if (self.group != other.group)
            return copy(self);

        return Kind{
            .group = self.group,
            ._mask = self._mask | other._mask,
        };
    }

    pub fn intersectionKind(self: *Kind, other: *const Kind) Kind {
        if (self.group != other.group)
            return copy(self);

        return Kind{
            .group = self.group,
            ._mask = self._mask & other._mask,
        };
    }

    pub fn copy(self: Kind) Kind {
        return Kind{
            .group = self.group,
            ._mask = self._mask,
        };
    }

    pub fn isKindOf(self: *Kind, other: *const Kind) bool {
        return other._mask & self._mask == self._mask;
    }

    pub fn isOfKind(self: *Kind, other: *const Kind) bool {
        return self._mask & other._mask == other._mask;
    }

    pub fn isExactKindOf(self: *Kind, other: *const Kind) bool {
        return other._mask == self._mask;
    }

    pub fn isNotKindOf(self: *Kind, other: *const Kind) bool {
        return other._mask & self._mask == 0;
    }

    pub fn format(
        self: Kind,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Kind[ group: {s}, aspects: ", .{self.group.name});
        for (0..self.group._size) |i| {
            if (self._mask & maskBit(self.group.aspects[i].index) > 0) {
                try writer.print("{s} ", .{self.group.aspects[i].name});
            }
        }
        try writer.writeAll("]");
    }

    fn maskBit(index: u8) MaskInt {
        return @as(MaskInt, 1) << @as(ShiftInt, @truncate(index));
    }
};

fn findOrCreateAspectGroup(name: []const u8) !*AspectGroup {
    for (0..ASPECT_GROUPS.items.len) |i| {
        var pg = &ASPECT_GROUPS.items[i];
        if (std.mem.eql(u8, pg.name, name)) {
            return pg;
        }
    }
    return AspectGroup.newAspectGroup(name);
}
