const std = @import("std");
const firefly = @import("../firefly.zig");

const DynArray = firefly.utils.DynArray;
const Component = firefly.api.Component;
const AspectGroup = firefly.utils.AspectGroup;
const String = firefly.utils.String;
const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(AssetComponent);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////////////////
//// Public API
//////////////////////////////////////////////////////////////////////////

pub const AssetAspectGroup = AspectGroup(struct {
    pub const name = "AssetComponent";
});
pub const AssetKind = AssetAspectGroup.Kind;
pub const AssetAspect = AssetAspectGroup.Aspect;

pub const AssetComponent = struct {
    pub usingnamespace Component.Trait(AssetComponent, .{
        .name = "AssetComponent",
        .processing = false,
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

        var resource: DynArray(T) = undefined;

        pub fn init() void {
            resource = DynArray(T).new(firefly.api.COMPONENT_ALLOC) catch unreachable;
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

        pub fn load(self: *T) void {
            loadResourceByName(self.name);
        }

        pub fn resourceLoadByName(name: String) bool {
            if (AssetComponent.byName(name)) |a|
                return a.isActive();
            return false;
        }

        pub fn loadResourceByName(name: String) void {
            AssetComponent.activateByName(name, true);
        }

        pub fn loadResourceById(id: Index) void {
            AssetComponent.activateById(id, true);
        }

        pub fn disposeResourceByName(name: String) void {
            AssetComponent.activateByName(name, false);
        }

        pub fn disposeResourceById(id: Index) void {
            AssetComponent.activateById(id, false);
        }

        pub fn resourceByAssetId(id: Index) ?*T {
            var asset = AssetComponent.byId(id);
            if (!isOfType(asset))
                return null;

            if (!asset.isActive())
                loadResourceById(id);

            return resourceById(asset.resource_id);
        }

        pub fn resourceById(id: Index) ?*T {
            return Asset(T).resource.get(id);
        }

        pub fn resourceByName(asset_name: String) ?*T {
            if (AssetComponent.byName(asset_name)) |asset|
                return Asset(T).resource.get(asset.resource_id);
            return null;
        }
    };
}

// pub fn Asset(comptime T: type) type {
//     const has_init = @hasDecl(T, "assetTypeInit");
//     const has_deinit = @hasDecl(T, "assetTypeDeinit");

//     comptime {
//         if (@typeInfo(T) != .Struct)
//             @compileError("Expects asset type is a struct.");
//         if (!@hasDecl(T, "ASSET_TYPE_NAME"))
//             @compileError("Expects asset type to have field ASSET_TYPE_NAME: String that defines a unique name of the asset type.");
//         if (!@hasDecl(T, "aspect"))
//             @compileError("Expects asset type to have field aspect: *const ASPECT_GROUP_TYPE.Aspect, that defines the asset type aspect");
//         if (!@hasDecl(T, "doLoad"))
//             @compileError("Expects asset type to have fn doLoad(asset: *Asset(T)) void, that loads the asset");
//         if (!@hasDecl(T, "doUnload"))
//             @compileError("Expects asset type to have fn doUnload(asset: *Asset(T)) void, that unloads the asset");
//     }

//     return struct {
//         const Self = @This();

//         pub usingnamespace Component.Trait(Self, .{
//             .name = "Asset:" ++ T.ASSET_TYPE_NAME,
//             .processing = false,
//         });

//         var resources: DynArray(T) = undefined;

//         // struct fields
//         id: Index = UNDEF_INDEX,
//         name: ?String = null,

//         resource_id: Index = UNDEF_INDEX,
//         parent_asset_id: ?Index = null,

//         pub fn componentTypeInit() !void {
//             if (Self.isInitialized())
//                 return;

//             AssetAspectGroup.applyAspect(T, T.ASSET_TYPE_NAME);
//             Self.resources = DynArray(T).new(firefly.api.COMPONENT_ALLOC) catch unreachable;
//             if (has_init)
//                 T.assetTypeInit();
//         }

//         pub fn componentTypeDeinit() void {
//             if (!Self.isInitialized())
//                 return;

//             if (has_deinit)
//                 T.assetTypeDeinit();

//             Self.resources.deinit();
//             T.aspect = undefined;
//         }

//         pub fn getAssetType(_: *Self) *const AssetAspect {
//             return T.aspect;
//         }

//         pub fn activation(self: *Self, active: bool) void {
//             if (self.getResource()) |r| {
//                 if (active) {
//                     T.doLoad(self, r);
//                 } else {
//                     T.doUnload(self, r);
//                 }
//             }
//         }

//         pub fn loadByName(name: String) void {
//             if (Self.byName(name)) |self| self.load();
//         }

//         pub fn loadById(id: Index) void {
//             Self.byId(id).load();
//         }

//         pub fn unloadByName(name: String) void {
//             if (Self.byName(name)) |self| self.unload();
//         }

//         pub fn unloadById(id: Index) void {
//             Self.byId(id).unload();
//         }

//         pub fn load(self: *Self) void {
//             if (self.isActive())
//                 return;

//             Self.activateById(self.id, true);
//         }

//         pub fn unload(self: *Self) void {
//             if (!self.isActive())
//                 return;

//             Self.activateById(self.id, false);
//         }

//         pub fn getResource(self: *Self) ?*T {
//             return T.getResourceById(self.resource_id);
//         }

//         pub fn format(
//             self: Self,
//             comptime _: []const u8,
//             _: std.fmt.FormatOptions,
//             writer: anytype,
//         ) !void {
//             try writer.print("Asset({s})[{d}|{?s}| resource_id={d}, parent_asset_id={?d} ]", .{
//                 T.ASSET_TYPE_NAME,
//                 self.id,
//                 self.name,
//                 self.resource_id,
//                 self.parent_asset_id,
//             });
//         }
//     };
// }
