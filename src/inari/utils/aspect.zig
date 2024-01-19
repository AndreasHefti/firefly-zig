const std = @import("std");
const utils = @import("utils.zig");
const String = utils.String;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;

const AspectError = error{
    NotInitialized,
    AspectGroupMismatch,
    NoAspectGroupFound,
};

/// The integer type used to represent a Kind
const MaskInt = u128;
/// Maximal number of aspects possible for one aspect group
const MaxIndex = 128;
/// The integer type used to shift a bit mask
const ShiftInt = std.math.Log2Int(MaskInt);
// aspect namespace variables and state
var INIT = false;
var ASPECT_GROUPS: ArrayList(AspectGroup) = undefined;
var ALLOCATOR: Allocator = undefined;

pub fn aspectInit(_allocator: Allocator) !void {
    defer INIT = true;
    if (!INIT) {
        ALLOCATOR = _allocator;
        ASPECT_GROUPS = try ArrayList(AspectGroup).initCapacity(ALLOCATOR, 10);
        errdefer aspectDeinit();
    }
}

pub fn aspectDeinit() void {
    defer INIT = false;
    if (INIT) {
        ASPECT_GROUPS.deinit();
        ASPECT_GROUPS = undefined;
        ALLOCATOR = undefined;
    }
}

pub const Aspect = struct {
    group: *AspectGroup,
    name: String,
    index: u8,
};

pub const AspectGroup = struct {
    /// The name of the aspect group
    name: String,
    /// The aspects of the aspect group. NOTE: max MaxIndex aspects per group possible
    aspects: [MaxIndex]Aspect,
    /// the actual size of the group (and pointer for next aspect insertion).
    /// NOTE: This value is shall only be modified internally. Do not modify this value from outside.
    _size: u8 = 0,

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

    pub fn of(aspect: *Aspect) Kind {
        return Kind{
            .group = aspect.group,
            ._mask = 0 | maskBit(aspect.index),
        };
    }

    pub fn with(self: Kind, aspect: *Aspect) Kind {
        if (self.group != aspect.group) {
            return self;
        }
        var kind = self;
        kind._mask |= maskBit(aspect.index);
        return kind;
    }

    pub fn unionKind(self: Kind, other: Kind) Kind {
        if (self.group != other.group) {
            return copy(self);
        }
        return Kind{
            .group = self.group,
            ._mask = self._mask | other._mask,
        };
    }

    pub fn intersectionKind(self: Kind, other: Kind) Kind {
        if (self.group != other.group) {
            return copy(self);
        }
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

    pub fn isKindOf(self: *Kind, other: *Kind) bool {
        return other._mask & self._mask == self._mask;
    }

    pub fn isOfKind(self: *Kind, other: *Kind) bool {
        return self._mask & other._mask == other._mask;
    }

    pub fn isExactKindOf(self: *Kind, other: *Kind) bool {
        return other._mask == self._mask;
    }

    pub fn isNotKindOf(self: *Kind, other: *Kind) bool {
        return other._mask & self._mask == 0;
    }

    fn maskBit(index: u8) MaskInt {
        return @as(MaskInt, 1) << @as(ShiftInt, @truncate(index));
    }
};

pub fn newAspectGroup(name: String) !*AspectGroup {
    try checkInitialized();

    var new_group = AspectGroup{
        .name = name,
        .aspects = [_]Aspect{undefined} ** MaxIndex,
    };
    try ASPECT_GROUPS.append(new_group);
    return &ASPECT_GROUPS.items[ASPECT_GROUPS.items.len - 1];
}

pub fn getAspectGroup(name: String) !*AspectGroup {
    try checkInitialized();

    for (ASPECT_GROUPS.items) |*group| {
        if (std.mem.eql(u8, name, group.name)) {
            return group;
        }
    }

    return AspectError.NoAspectGroupFound;
}

pub fn getAspect(groupName: []const u8, aspectName: []const u8) !*Aspect {
    const group = try findOrCreateAspectGroup(groupName);
    return group.getAspect(aspectName);
}

fn findOrCreateAspectGroup(name: []const u8) !*AspectGroup {
    for (0..ASPECT_GROUPS.items.len) |i| {
        var pg = &ASPECT_GROUPS.items[i];
        if (std.mem.eql(u8, pg.name, name)) {
            return pg;
        }
    }
    return newAspectGroup(name);
}

fn checkInitialized() !void {
    if (!INIT) {
        return AspectError.NotInitialized;
    }
}

pub fn print(writer: std.fs.File.Writer) !void {
    if (!INIT) {
        _ = try writer.write("Aspects: [ NOT INITIALIZED ]\n");
        return;
    }

    _ = try writer.write("Aspects:");
    if (ASPECT_GROUPS.items.len == 0) {
        _ = try writer.write("EMPTY");
    } else {
        for (ASPECT_GROUPS.items) |item| {
            try writer.print("\n  Group[{s}|{}]: ", .{ item.name, item._size });
            for (0..item._size) |i| {
                try writer.print("\n    Aspect[{s}|{d}]", .{ item.aspects[i].name, item.aspects[i].index });
            }
        }
    }
    _ = try writer.write("\n");
}

test "initialize" {
    try aspectInit(std.testing.allocator);
    defer aspectDeinit();

    var groupPtr = try newAspectGroup("TestGroup");
    try std.testing.expectEqualStrings("TestGroup", groupPtr.name);
    try std.testing.expect(groupPtr._size == 0);

    var aspect1Ptr = groupPtr.getAspect("aspect1");
    try std.testing.expect(groupPtr._size == 1);
    try std.testing.expect(aspect1Ptr.group == groupPtr);
    try std.testing.expect(aspect1Ptr.index == 0);
    try std.testing.expectEqualStrings("aspect1", aspect1Ptr.name);

    var aspect2Ptr = groupPtr.getAspect("aspect2");
    try std.testing.expect(groupPtr._size == 2);
    try std.testing.expect(aspect2Ptr.group == groupPtr);
    try std.testing.expect(aspect2Ptr.index == 1);
    try std.testing.expectEqualStrings("aspect2", aspect2Ptr.name);
}

test "kind" {
    try aspectInit(std.testing.allocator);
    defer aspectDeinit();

    var groupPtr = try newAspectGroup("TestGroup");
    var aspect1Ptr = groupPtr.getAspect("aspect1");
    var aspect2Ptr = groupPtr.getAspect("aspect2");
    var aspect3Ptr = groupPtr.getAspect("aspect3");
    var aspect4Ptr = groupPtr.getAspect("aspect4");

    var kind1 = Kind.of(aspect1Ptr).with(aspect2Ptr).with(aspect3Ptr);
    var kind2 = Kind.of(aspect2Ptr).with(aspect3Ptr);
    var kind3 = Kind.of(aspect4Ptr);

    try std.testing.expect(kind2.isKindOf(&kind1));
    try std.testing.expect(!kind1.isKindOf(&kind2));
    try std.testing.expect(kind1.isOfKind(&kind2));
    try std.testing.expect(!kind1.isExactKindOf(&kind2));
    try std.testing.expect(!kind3.isExactKindOf(&kind2));
    try std.testing.expect(!kind3.isExactKindOf(&kind1));
}
