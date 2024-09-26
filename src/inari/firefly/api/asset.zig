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

    api.Component.registerComponent(Asset, "Asset");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////////////////
//// Public API
//////////////////////////////////////////////////////////////////////////
pub const Asset = struct {
    pub const Component = api.Component.Mixin(Asset);
    pub const Naming = api.Component.NameMappingMixin(Asset);
    pub const Activation = api.Component.ActivationMixin(Asset);
    pub const Subscription = api.Component.SubscriptionMixin(Asset);
    pub const Subtypes = api.Component.SubTypingMixin(Asset);

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    asset_type: api.AssetAspect,

    pub fn load(self: *Asset) void {
        Activation.byId(self.id, true);
    }

    pub fn close(self: *Asset) void {
        Activation.byId(self.id, false);
    }
};

pub fn AssetMixin(comptime T: type, comptime type_name: String) type {
    return struct {
        pub usingnamespace firefly.api.SubTypeMixin(api.Asset, T);

        pub const ASSET_TYPE_NAME = type_name;

        pub fn isOfType(asset: *Asset) bool {
            return firefly.utils.stringEquals(asset.asset_type.name, ASSET_TYPE_NAME);
        }

        pub fn new(subtype: T) *T {
            return @This().newSubType(
                Asset{
                    .name = subtype.name,
                    .asset_type = api.AssetAspectGroup.getAspect(ASSET_TYPE_NAME),
                },
                subtype,
            );
        }

        pub fn load(self: *T) void {
            Asset.Activation.activate(self.id);
        }

        pub fn close(self: *T) void {
            Asset.Activation.deactivate(self.id);
        }
    };
}
