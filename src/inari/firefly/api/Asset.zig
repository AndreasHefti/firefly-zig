const std = @import("std");
const Allocator = std.mem.Allocator;

const api = @import("api.zig");
const utils = api.utils;
const Component = api.Component;
const ComponentListener = Component.ComponentListener;
const ComponentEvent = Component.ComponentEvent;
const AspectGroup = utils.aspect.AspectGroup;
const aspect = utils.aspect;
const Aspect = aspect.Aspect;
const String = utils.String;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const Asset = @This();

// type aspects
var initialized = false;
pub var ASSET_TYPE_ASPECT_GROUP: *AspectGroup = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    ASSET_TYPE_ASPECT_GROUP = try aspect.newAspectGroup("ASSET_TYPE_ASPECT_GROUP");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    aspect.disposeAspectGroup(COMPONENT_NAME);
    ASSET_TYPE_ASPECT_GROUP = undefined;
}

// type fields
pub const NULL_VALUE = Asset{};
pub const COMPONENT_NAME = "Asset";
pub const pool = Component.ComponentPool(Asset);

// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Asset) *Asset = undefined;
pub var exists: *const fn (Index) bool = undefined;
pub var existsName: *const fn (String) bool = undefined;
pub var get: *const fn (Index) *Asset = undefined;
pub var byId: *const fn (Index) *const Asset = undefined;
pub var byName: *const fn (String) *const Asset = undefined;
pub var activateById: *const fn (Index, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (Index) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (ComponentListener) void = undefined;
pub var unsubscribe: *const fn (ComponentListener) void = undefined;

// struct fields
id: Index = UNDEF_INDEX,
asset_type: *Aspect = undefined,
name: String = utils.NO_NAME,

resource_id: Index = UNDEF_INDEX,
parent_asset_id: Index = UNDEF_INDEX,

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

pub fn format(
    self: Asset,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.print(
        "Asset[{d}|{any}|{s}| resource_id={d}, parent_asset_id={d} ]",
        self,
    );
}
