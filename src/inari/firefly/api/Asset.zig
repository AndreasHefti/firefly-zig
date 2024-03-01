const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;

const Allocator = std.mem.Allocator;
const Component = api.Component;
const ComponentListener = Component.ComponentListener;
const ComponentEvent = Component.ComponentEvent;
const AspectGroup = utils.AspectGroup;
const Aspect = utils.Aspect;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const Asset = @This();

pub usingnamespace Component.API.Adapter(@This(), .{ .name = "Asset" });

// type aspects
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

    AspectGroup.dispose(@This().COMPONENT_TYPE_NAME);
    ASSET_TYPE_ASPECT_GROUP = undefined;
}

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

// pub fn getResourceForIndex(asset: *Asset, asset_type: anytype, comptime T: type, index: usize) ?*T {
//     if (asset.resource_id == UNDEF_INDEX)
//         return null;
//     return asset_type.getResourceForIndex(asset.resource_id, index);
// }

// pub fn getResourceForName(asset: *Asset, asset_type: anytype, comptime T: type, name: String) ?*T {
//     if (asset.resource_id == UNDEF_INDEX)
//         return null;
//     return asset_type.getResourceForName(asset.resource_id, name);
// }

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
