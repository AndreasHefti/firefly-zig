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

    api.Component.registerComponent(Asset);
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
    pub const name = "Asset";
});
pub const AssetKind = AssetAspectGroup.Kind;
pub const AssetAspect = AssetAspectGroup.Aspect;

pub const Asset = struct {
    pub usingnamespace api.Component.Trait(Asset, .{
        .name = "Asset",
        .subtypes = true,
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    asset_type: AssetAspect,

    pub usingnamespace AssetLoadTrait(Asset);
};

pub fn AssetTrait(comptime T: type, comptime type_name: String) type {
    return struct {
        pub usingnamespace firefly.api.SubTypeTrait(api.Asset, T);

        pub const ASSET_TYPE_NAME = type_name;

        pub fn isOfType(asset: *Asset) bool {
            return firefly.utils.stringEquals(asset.asset_type.name, ASSET_TYPE_NAME);
        }

        pub fn new(subtype: T) *T {
            return @This().newSubType(
                Asset{
                    .name = subtype.name,
                    .asset_type = AssetAspectGroup.getAspect(ASSET_TYPE_NAME),
                },
                subtype,
            );
        }

        pub usingnamespace AssetLoadTrait(T);
    };
}

fn AssetLoadTrait(comptime T: type) type {
    return struct {
        pub fn load(self: *T) void {
            Asset.activateById(self.id, true);
        }

        pub fn close(self: *T) void {
            Asset.activateById(self.id, false);
        }
    };
}
