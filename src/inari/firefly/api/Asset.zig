const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const DynArray = utils.DynArray;
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

        pub fn isInitialized() bool {
            return Asset(T).isInitialized();
        }

        pub fn new(data: T) Index {
            return newAnd(data).id;
        }

        pub fn newAnd(data: T) *Asset(T) {
            return Asset(T).newAnd(.{
                .name = data.name,
                .resource_id = Asset(T).resources.add(data),
            });
        }

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
        pub fn getResourceByAssetId(asset_id: Index) ?*T {
            var asset = Asset(T).byId(asset_id);
            if (!asset.isActive()) {
                loadById(asset_id);
            }
            return getResourceById(asset.resource_id);
        }
        pub fn getResourceById(resource_id: usize) ?*T {
            return Asset(T).resources.get(resource_id);
        }
        pub fn getResourceByName(asset_name: String) ?*T {
            return Asset(T).resources.get(Asset(T).byName(asset_name).resource_id);
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

        has_init = trait.hasDecls(T, .{"assetTypeInit"});
        has_deinit = trait.hasDecls(T, .{"assetTypeDeinit"});
    }

    return struct {
        const Self = @This();

        pub usingnamespace Component.Trait(Self, .{ .name = "Asset:" ++ T.ASSET_TYPE_NAME });

        var resources: DynArray(T) = undefined;

        // struct fields
        id: Index = UNDEF_INDEX,
        name: ?String = null,

        resource_id: Index = UNDEF_INDEX,
        parent_asset_id: Index = UNDEF_INDEX,

        pub fn componentTypeInit() !void {
            if (Self.isInitialized())
                return;

            AssetAspectGroup.applyAspect(T, T.ASSET_TYPE_NAME);
            Self.resources = DynArray(T).new(api.COMPONENT_ALLOC) catch unreachable;
            if (has_init)
                T.assetTypeInit();
        }

        pub fn componentTypeDeinit() void {
            if (!Self.isInitialized())
                return;

            if (has_deinit)
                T.assetTypeDeinit();

            Self.resources.deinit();
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
            return T.getResourceById(self.resource_id);
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
