const std = @import("std");
const Allocator = std.mem.Allocator;

const api = @import("api.zig"); // TODO module
const utils = @import("utils");

const Component = api.Component;
const ComponentPool = api.Component.ComponentPool;
const AspectGroup = utils.aspect.AspectGroup;
const aspect = utils.aspect;
const Aspect = aspect.Aspect;
const String = utils.String;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;
const BindingIndex = api.BindingIndex;
const Asset = @This();

// type aspects
var initialized = false;
pub var ASSET_TYPE_ASPECT_GROUP: *AspectGroup = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    ASSET_TYPE_ASPECT_GROUP = try aspect.newAspectGroup(component_name);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    aspect.disposeAspectGroup(component_name);
    ASSET_TYPE_ASPECT_GROUP = undefined;
    pool.deinit();
}

// type fields
pub const null_value = Asset{};
pub const component_name = "Asset";
pub const pool = ComponentPool(Asset);

// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Asset) *Asset = undefined;
pub var byId: *const fn (usize) *Asset = undefined;
pub var byName: *const fn (String) ?*Asset = undefined;
pub var activateById: *const fn (usize, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (usize) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields
index: usize = UNDEF_INDEX,
asset_type: *Aspect = undefined,
name: String = NO_NAME,
resource_id: usize = UNDEF_INDEX,
parent_asset_id: usize = UNDEF_INDEX,

pub fn getResource(asset: *Asset, comptime asset_type: anytype) *const @TypeOf(asset_type.NULL_VALUE) {
    if (asset.resource_id == UNDEF_INDEX or !@hasDecl(asset_type, "getResource"))
        return &asset_type.NULL_VALUE;
    return asset_type.getResource(asset.resource_id);
}

pub fn getResourceForIndex(asset: *Asset, asset_type: anytype, comptime T: type, index: usize) ?*T {
    if (asset.resource_id == UNDEF_INDEX)
        return null;
    return asset_type.getResourceForIndex(asset.resource_id, index);
}

pub fn getResourceForName(asset: *Asset, asset_type: anytype, comptime T: type, name: String) ?*T {
    if (asset.resource_id == UNDEF_INDEX)
        return null;
    return asset_type.getResourceForName(asset.resource_id, name);
}
