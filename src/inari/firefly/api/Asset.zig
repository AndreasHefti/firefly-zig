const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;

const Component = api.Component;
const AspectGroup = utils.AspectGroup;
const Aspect = utils.Aspect;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

var initialized = false;
pub var ASSET_TYPE_ASPECT_GROUP: *AspectGroup = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    ASSET_TYPE_ASPECT_GROUP = try AspectGroup.new("ASSET_TYPE_ASPECT_GROUP");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    AspectGroup.dispose("ASSET_TYPE_ASPECT_GROUP");
    ASSET_TYPE_ASPECT_GROUP = undefined;
}

pub fn AssetTrait(comptime T: type, comptime type_name: String) type {
    return struct {
        pub const ASSET_TYPE_NAME = type_name;
        pub var asset_type: *Aspect = undefined;
        pub fn loadByName(name: String) void {
            Asset(T).loadByName(name);
        }
        pub fn loadById(id: Index) void {
            Asset(T).loadById(id);
        }
        pub fn unloadByName(name: String) void {
            Asset(T).unloadByName(name);
        }
        pub fn unloadById(id: Index) void {
            Asset(T).unloadById(id);
        }
        pub fn disposeByName(name: String) void {
            Asset(T).disposeByName(name);
        }
    };
}

pub fn Asset(comptime T: type) type {
    return struct {
        const Self = @This();
        var type_init = false;

        pub usingnamespace Component.API.ComponentTrait(@This(), .{ .name = "Asset:" ++ T.ASSET_TYPE_NAME });

        // struct fields
        id: Index = UNDEF_INDEX,
        name: String = utils.NO_NAME,

        resource_id: Index = UNDEF_INDEX,
        parent_asset_id: Index = UNDEF_INDEX,

        pub fn init() !void {
            defer type_init = true;
            if (type_init)
                return;

            T.asset_type = ASSET_TYPE_ASPECT_GROUP.getAspect(T.ASSET_TYPE_NAME);
            T.init();
        }

        pub fn deinit() void {
            defer type_init = false;
            if (!type_init)
                return;

            T.deinit();
            T.asset_type = undefined;
        }

        pub fn getAssetType(_: *Self) *Aspect {
            return T.asset_type;
        }

        pub fn activation(self: *Self, active: bool) void {
            if (active) {
                T._load(self);
            } else {
                T._unload(self);
            }
        }

        pub fn loadByName(name: String) void {
            if (Self.byName(name)) |self| self.load();
        }

        pub fn loadById(id: Index) void {
            Self.byId(id).load();
        }

        pub fn unloadByName(name: String) void {
            if (Self.byName(name)) |self| self.unload();
        }

        pub fn unloadById(id: Index) void {
            Self.byId(id).unload();
        }

        pub fn load(self: *Self) void {
            if (self.isActive())
                return;

            Self.activateById(self.id, true);
        }

        pub fn unload(self: *Self) void {
            if (!self.isActive())
                return;

            Self.activateById(self.id, false);
        }

        pub fn getResource(self: *Self) *T {
            return T._getResource(self.resource_id);
        }

        pub fn format(
            self: Self,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("Asset({s})[{d}|{s}| resource_id={d}, parent_asset_id={d} ]", .{
                T.ASSET_TYPE_NAME,
                self.id,
                self.name,
                self.resource_id,
                self.parent_asset_id,
            });
        }
    };
}
