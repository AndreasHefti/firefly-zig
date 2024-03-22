const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const Component = api.Component;
const AspectGroup = utils.AspectGroup;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

var initialized = false;

pub const AssetAspectGroup = AspectGroup(struct {
    pub const name = "Asset";
});
pub const AssetKind = AssetAspectGroup.Kind;
pub const AssetAspect = AssetAspectGroup.Aspect;

pub fn AssetTrait(comptime T: type, comptime type_name: String) type {
    return struct {
        pub const ASSET_TYPE_NAME = type_name;
        pub var aspect: *const AssetAspect = undefined;
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
    comptime var has_init = false;
    comptime var has_deinit = false;

    comptime {
        if (!trait.is(.Struct)(T))
            @compileError("Expects asset type is a struct.");
        if (!trait.hasDecls(T, .{"ASSET_TYPE_NAME"}))
            @compileError("Expects asset type to have field ASSET_TYPE_NAME: String that defines a unique name of the asset type.");
        if (!trait.hasDecls(T, .{"aspect"}))
            @compileError("Expects asset type to have field aspect: *const ASPECT_GROUP_TYPE.Aspect, that defines the asset type aspect");
        if (!trait.hasDecls(T, .{"doLoad"}))
            @compileError("Expects asset type to have fn doLoad(asset: *Asset(T)) void, that loads the asset");
        if (!trait.hasDecls(T, .{"doUnload"}))
            @compileError("Expects asset type to have fn doUnload(asset: *Asset(T)) void, that unloads the asset");
        if (!trait.hasFn("getResource")(T))
            @compileError("Expects asset type to have fn getResource(asset_id: Index) ?*T, that gets the loaded asset resource");

        has_init = trait.hasDecls(T, .{"init"});
        has_deinit = trait.hasDecls(T, .{"deinit"});
    }

    return struct {
        const Self = @This();
        var type_init = false;

        pub usingnamespace Component.Trait(Self, .{ .name = "Asset:" ++ T.ASSET_TYPE_NAME });

        // struct fields
        id: Index = UNDEF_INDEX,
        name: ?String = null,

        resource_id: Index = UNDEF_INDEX,
        parent_asset_id: Index = UNDEF_INDEX,

        pub fn init() !void {
            defer type_init = true;
            if (type_init)
                return;

            AssetAspectGroup.applyAspect(T, T.ASSET_TYPE_NAME);
            if (has_init)
                T.init();
        }

        pub fn deinit() void {
            defer type_init = false;
            if (!type_init)
                return;

            if (has_deinit)
                T.deinit();
            T.aspect = undefined;
        }

        pub fn getAssetType(_: *Self) *const AssetAspect {
            return T.aspect;
        }

        pub fn activation(self: *Self, active: bool) void {
            if (active) {
                T.doLoad(self);
            } else {
                T.doUnload(self);
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

        pub fn getResource(self: *Self) ?*T {
            return T.getResource(self.resource_id);
        }

        pub fn format(
            self: Self,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("Asset({s})[{d}|{?s}| resource_id={d}, parent_asset_id={d} ]", .{
                T.ASSET_TYPE_NAME,
                self.id,
                self.name,
                self.resource_id,
                self.parent_asset_id,
            });
        }
    };
}
