const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;

const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.Component.registerComponent(AssetComponent);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////////////////
//// Public API
//////////////////////////////////////////////////////////////////////////

pub const AssetAspectGroup = utils.AspectGroup(struct {
    pub const name = "AssetComponent";
});
pub const AssetKind = AssetAspectGroup.Kind;
pub const AssetAspect = AssetAspectGroup.Aspect;

pub const AssetComponent = struct {
    pub usingnamespace api.Component.Trait(AssetComponent, .{
        .name = "AssetComponent",
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    asset_type: AssetAspect,

    resource_id: Index,

    _activate: *const fn (*AssetComponent, bool) void,
    _dispose: ?*const fn (Index) void = null,

    pub fn activation(self: *AssetComponent, active: bool) void {
        self._activate(self, active);
    }

    pub fn destruct(self: *AssetComponent) void {
        if (self._dispose) |df| df(self.resource_id);
    }
};

pub fn Asset(comptime T: type) type {
    const has_construct: bool = @hasDecl(T, "construct");
    const has_destruct = @hasDecl(T, "destruct");

    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects asset type is a struct.");
        if (!@hasDecl(T, "loadResource"))
            @compileError("Expects asset type to have function 'loadResource(*AssetComponent): void'");
        if (!@hasDecl(T, "disposeResource"))
            @compileError("Expects asset type to have field 'disposeResource(*AssetComponent): void'");
        if (!@hasField(T, "name"))
            @compileError("Expects asset type to have field 'name: String'");
        if (!@hasDecl(T, "ASSET_TYPE_NAME"))
            @compileError("Expects asset type to have var 'ASSET_TYPE_NAME: String'");
    }

    return struct {
        const Self = @This();

        var resource: utils.DynArray(T) = undefined;

        pub fn init() void {
            resource = utils.DynArray(T).new(firefly.api.COMPONENT_ALLOC);
        }

        pub fn deinit() void {
            resource.deinit();
        }

        fn new(asset_type: T) Index {
            const res_id = resource.add(asset_type);
            var res = resource.get(res_id).?;
            if (has_construct)
                res.construct();

            _ = AssetComponent.new(.{
                .name = asset_type.name,
                .asset_type = AssetAspectGroup.getAspect(T.ASSET_TYPE_NAME).*,
                .resource_id = res_id,
                ._activate = activate,
                ._dispose = dispose,
            });

            return res_id;
        }

        fn activate(asset_component: *AssetComponent, active: bool) void {
            if (active) {
                T.loadResource(asset_component);
            } else {
                T.disposeResource(asset_component);
            }
        }

        fn dispose(id: Index) void {
            if (has_destruct)
                if (resource.get(id)) |res| res.destruct();
            resource.delete(id);
        }
    };
}

pub fn AssetTrait(comptime T: type, comptime type_name: String) type {
    return struct {
        pub const ASSET_TYPE_NAME = type_name;

        pub fn isOfType(asset: *AssetComponent) bool {
            return firefly.utils.stringEquals(asset.asset_type.name, ASSET_TYPE_NAME);
        }

        pub fn new(asset_type: T) *T {
            return Asset(T).resource.get(Asset(T).new(asset_type)).?;
        }

        pub fn existsByName(name: String) bool {
            return AssetComponent.existsName(name);
        }

        pub fn load(self: *T) void {
            loadByName(self.name);
        }

        pub fn isLoadedById(id: Index) bool {
            if (!AssetComponent.exists(id))
                return false;

            return AssetComponent.byId(id).isActive();
        }

        pub fn isLoadedByName(name: String) bool {
            if (AssetComponent.byName(name)) |a|
                return a.isActive();
            return false;
        }

        pub fn loadByName(name: String) void {
            AssetComponent.activateByName(name, true);
        }

        pub fn loadById(id: Index) void {
            AssetComponent.activateById(id, true);
        }

        pub fn disposeByName(name: String) void {
            AssetComponent.activateByName(name, false);
        }

        pub fn disposeById(id: Index) void {
            AssetComponent.activateById(id, false);
        }

        pub fn resourceByAssetId(id: Index) ?*T {
            var asset = AssetComponent.byId(id);
            if (!isOfType(asset))
                return null;

            if (!asset.isActive())
                loadById(id);

            return resourceById(asset.resource_id);
        }

        pub fn resourceById(id: Index) ?*T {
            return Asset(T).resource.get(id);
        }

        pub fn resourceByName(asset_name: String) ?*T {
            const asset = AssetComponent.byName(asset_name) orelse return null;
            return Asset(T).resource.get(asset.resource_id);
        }
    };
}
