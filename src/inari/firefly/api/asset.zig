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

    api.Component.register(Asset, "Asset");
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

    loaded: bool = false,
    load_error: ?api.IOErrors = null,

    pub fn createForSubType(SubType: anytype) *Asset {
        return api.Asset.Component.newForSubType(.{ .name = SubType.name });
    }

    pub fn load(self: *Asset) void {
        Activation.byId(self.id, true);
    }

    pub fn close(self: *Asset) void {
        Activation.byId(self.id, false);
    }

    pub fn assetLoaded(id: Index, state: bool) void {
        Asset.Component.byId(id).loaded = state;
        Asset.Component.byId(id).load_error = null;
    }

    pub fn assetLoadError(id: Index, err: api.IOErrors) void {
        Asset.Component.byId(id).loaded = false;
        Asset.Component.byId(id).load_error = err;
    }
};
