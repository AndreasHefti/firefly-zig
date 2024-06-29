const std = @import("std");
const utils = @import("utils.zig");
const String = utils.String;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Writer = std.io.Writer;
const StringBuffer = utils.StringBuffer;

/// The integer type used to represent a Kind
const MaskInt = u128;
/// Maximal number of aspects possible for one aspect group
const MaxIndex = 128;
/// The integer type used to shift a bit mask
const ShiftInt = std.math.Log2Int(MaskInt);

pub fn AspectGroup(comptime T: type) type {
    return struct {
        pub const Aspect = struct {
            const _group_ = Group;

            id: u8,
            name: String,
        };

        const Group = @This();
        const _name: String = if (@hasDecl(T, "name")) T.name else @typeName(T);
        var _aspect_count: u8 = 0;
        var _aspects: [MaxIndex]Aspect = [_]Aspect{undefined} ** MaxIndex;

        pub fn name() String {
            return _name;
        }

        pub fn size() u8 {
            return _aspect_count;
        }

        pub fn getAspectById(id: usize) Aspect {
            if (id < _aspect_count)
                return _aspects[id];

            @panic("Aspect id overflow");
        }

        pub fn getAspectIfExists(aspect_name: String) ?Aspect {
            var i: u8 = 0;
            while (i < _aspect_count) {
                if (utils.stringEquals(Group._aspects[i].name, aspect_name)) {
                    return Group._aspects[i];
                }
                i = i + 1;
            }
            return null;
        }

        pub fn getAspect(aspect_name: String) Aspect {
            var i: u8 = 0;
            while (i < _aspect_count) {
                if (utils.stringEquals(Group._aspects[i].name, aspect_name)) {
                    return Group._aspects[i];
                }
                i = i + 1;
            }
            // create new one
            if (_aspect_count >= 128)
                @panic("No more space for new aspects in AspectGroup");

            _aspects[_aspect_count] = .{ .id = _aspect_count, .name = aspect_name };
            _aspect_count = _aspect_count + 1;
            return _aspects[_aspect_count - 1];
        }

        pub fn applyAspect(t: anytype, aspect_name: String) void {
            t.aspect = getAspect(aspect_name);
        }

        pub fn newKind() Kind {
            return Kind{};
        }

        pub fn newKindOf(aspects: anytype) Kind {
            const args_type_info = @typeInfo(@TypeOf(aspects));
            if (args_type_info != .Struct) {
                @compileError("expected struct argument, found " ++ @typeName(@TypeOf(aspects)));
            }
            const fields_info = args_type_info.Struct.fields;

            var kind = Kind{};
            comptime var i = 0;
            inline while (i < fields_info.len) {
                if (getAspectFromAnytype(@field(aspects, fields_info[i].name))) |a| {
                    kind.with(a.id);
                }
                i = i + 1;
            }

            return kind;
        }

        pub fn newKindOfNames(aspects: []String) Kind {
            var kind = Kind{};
            for (0..aspects.len) |i| {
                var j: u8 = 0;
                while (j < Group._aspect_count) {
                    if (std.mem.eql(u8, aspects[i], Group._aspects[j].name)) {
                        kind.with(Group._aspects[j].id);
                    }
                    j = j + 1;
                }
            }
            return kind;
        }

        pub fn print(sb: *StringBuffer) void {
            sb.print("AspectGroup({?s})\n", .{_name});
            var i: u8 = 0;
            while (i < Group._aspect_count) {
                sb.print("  {d}:{s}\n", .{ Group._aspects[i].id, Group._aspects[i].name });
                i = i + 1;
            }
        }

        pub fn getAspectFromAnytype(aspect: anytype) ?Aspect {
            const at: type = @TypeOf(aspect);

            if (at == Aspect) {
                return aspect;
            } else if (at == *Aspect or at == *const Aspect) {
                return aspect.*;
            } else if (@hasDecl(aspect, "aspect")) {
                return getAspectFromAnytype(aspect.aspect);
            } else {
                return null;
            }
        }

        pub const Kind = struct {
            const _group_ = Group;
            /// The bitmask to store indices of owned aspects of this kind
            _mask: MaskInt = 0,

            pub fn of(aspects: anytype) Kind {
                var result: Kind = Kind{};
                inline for (aspects) |a| {
                    if (getAspectFromAnytype(a)) |_a| result = result.withAspect(_a);
                }

                return result;
            }

            pub fn fromStringList(aspect_names: ?String) ?Kind {
                if (aspect_names) |a_string| {
                    var result: Kind = Kind{};
                    var it = std.mem.split(u8, a_string, ",");
                    while (it.next()) |aspect_name|
                        result.addAspect(Group.getAspect(aspect_name));
                    return result;
                }
                return null;
            }

            pub fn clear(self: *Kind) void {
                self._mask = 0;
            }

            pub fn isPartOf(self: Kind, other: Kind) bool {
                return other._mask & self._mask == self._mask;
            }

            pub fn isNotPartOf(self: Kind, other: Kind) bool {
                return other._mask & self._mask == 0;
            }

            pub fn isEquals(self: Kind, other: Kind) bool {
                return other._mask == self._mask;
            }

            pub fn unionKind(self: Kind, other: Kind) Kind {
                if (self.group != other.group)
                    return copy(self);

                return Kind{
                    .group = self.group,
                    ._mask = self._mask | other._mask,
                };
            }

            pub fn intersectionKind(self: Kind, other: Kind) Kind {
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

            pub fn activateAspect(self: *Kind, aspect: Aspect, active: bool) void {
                if (active) {
                    self.with(aspect.id);
                } else {
                    self.without(aspect.id);
                }
            }

            pub fn removeAspect(self: *Kind, aspect: Aspect) void {
                self.without(aspect.id);
            }

            pub fn addAspect(self: *Kind, aspect: Aspect) void {
                self.with(aspect.id);
            }

            pub fn withAspect(self: Kind, aspect: anytype) Kind {
                var k = self;
                if (getAspectFromAnytype(aspect)) |a|
                    with(&k, a.id);

                return k;
            }

            pub fn hasAspect(self: Kind, aspect: anytype) bool {
                if (getAspectFromAnytype(aspect)) |a|
                    return self._mask & maskBit(a.id) != 0;

                return false;
            }

            pub fn hasAnyAspect(self: Kind, other: Kind) bool {
                return self._mask & other._mask > 0;
            }

            pub fn has(self: Kind, index: u8) bool {
                return self._mask & maskBit(index) != 0;
            }

            fn with(self: *Kind, index: u8) void {
                self._mask |= maskBit(index);
            }

            fn without(self: *Kind, index: u8) void {
                self._mask &= ~index;
            }

            fn maskBit(index: u8) MaskInt {
                return @as(MaskInt, 1) << @as(ShiftInt, @truncate(index));
            }

            pub fn format(
                self: Kind,
                comptime _: String,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                var k = self;
                try writer.print("Kind({?s})[", .{_name});
                var i: u8 = 0;
                while (i < Group._aspect_count) {
                    if (k.has(i)) {
                        try writer.print("{d}:{s} ", .{ Group._aspects[i].id, Group._aspects[i].name });
                    }
                    i = i + 1;
                }
                try writer.print("]", .{});
            }
        };
    };
}
