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

pub usingnamespace Component.API.ComponentTrait(@This(), .{ .name = "Asset" });

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
//loaded: bool = false,
parent_asset_id: Index = UNDEF_INDEX,

pub fn isLoadedById(id: Index) bool {
    return Asset.exists(id) and Asset.isActive(id);
}

pub fn isLoaded(self: *Asset) bool {
    return Asset.isActive(self.id);
}

pub fn loadById(id: Index) bool {
    if (Asset.exists(id)) {
        Asset.activateById(id, true);
        return true;
    }
    return false;
}

pub fn loadByName(name: String) bool {
    if (Asset.byName(name)) |asset| {
        return asset.load();
    }
    return false;
}

pub fn load(self: *Asset) bool {
    if (self.isLoaded())
        return true;
    Asset.activateById(self.id, true);
    return self.isLoaded();
}

pub fn unload(self: *Asset) void {
    Asset.activateById(self.id, false);
}

pub fn unloadById(id: Index) void {
    if (Asset.exists(id)) {
        Asset.activateById(id, false);
    }
}

pub fn unloadByName(name: String) void {
    if (Asset.byName(name)) |a| a.unload();
}

// pub fn getResource(asset: *Asset, comptime asset_type: anytype) *const @TypeOf(asset_type.VALUE_TYPE) {
//     if (asset.resource_id == UNDEF_INDEX or !@hasDecl(asset_type, "getResource"))
//         return &asset_type.NULL_VALUE;
//     return asset_type.getResource(asset.resource_id);
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
