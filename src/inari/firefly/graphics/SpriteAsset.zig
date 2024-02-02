const std = @import("std");
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const graphics = @import("graphics.zig");
const api = graphics.api;
const utils = graphics.utils;

const Aspect = utils.aspect.Aspect;
const Asset = api.Asset;
const DynArray = utils.dynarray.DynArray;
const SpriteData = api.SpriteData;
const BindingIndex = api.BindingIndex;
const String = utils.String;
const Event = api.Component.Event;
const ActionType = api.Component.ActionType;
const TextureData = api.TextureData;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;

pub var asset_type: *Aspect = undefined;
pub const NULL_VALUE = SpriteData{};

var initialized = false;
var resources: DynArray(SpriteData) = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Sprite");
    resources = DynArray(SpriteData).init(api.COMPONENT_ALLOC, NULL_VALUE);
    Asset.subscribe(listener);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    Asset.unsubscribe(listener);
    asset_type = undefined;
    resources.deinit();
    resources = undefined;
}

pub const Sprite = struct {
    name: String = NO_NAME,
    texture_asset_id: usize,
    texture_bounds: RectF,
    flip_x: bool = false,
    flip_y: bool = false,
};

pub fn new(data: Sprite) *Asset {
    if (!initialized)
        @panic("Firefly module not initialized");

    if (data.texture_asset_id != UNDEF_INDEX and Asset.pool.exists(data.texture_asset_id))
        @panic("Sprite has invalid TextureAsset reference id");

    var spriteData = SpriteData{
        .texture_bounds = data.texture_bounds,
    };
    if (data.flip_x)
        spriteData.flip_x();
    if (data.flip_y)
        spriteData.flip_y();

    return Asset.new(Asset{
        .asset_type = asset_type,
        .name = data.asset_name,
        .resource_id = resources.add(spriteData),
        .parent_asset_id = data.texture_asset_id,
    });
}

pub fn getResource(res_index: usize) *const SpriteData {
    return resources.get(res_index);
}

pub fn getResourceForIndex(res_index: usize, _: usize) *const SpriteData {
    return resources.get(res_index);
}

pub fn getResourceForName(res_index: usize, _: String) *const SpriteData {
    return resources.get(res_index);
}

fn listener(e: Event) void {
    var asset: *Asset = Asset.pool.byId(e.c_index);
    if (asset_type.index != asset.asset_type.index)
        return;

    switch (e.event_type) {
        ActionType.Activated => load(asset),
        ActionType.Deactivated => unload(asset),
        ActionType.Disposing => delete(asset),
        else => {},
    }
}

fn load(asset: *Asset) void {
    if (!initialized)
        @panic("Firefly module not initialized");

    var spriteData: *SpriteData = resources.get(asset.resource_id);
    if (spriteData.texture_binding != NO_BINDING) return; // already loaded

    // check if texture asset is loaded, if not try to load
    const texData: *const TextureData = Asset.byId(asset.parent_asset_id).getResource(TextureData);
    if (texData.binding == NO_BINDING) {
        Asset.activateById(asset.parent_asset_id, true);
        if (texData.binding == NO_BINDING) {
            std.log.err("Failed to load/activate dependent TextureAsset: {any}", .{Asset.byId(asset.parent_asset_id)});
            return;
        }
    }

    spriteData.texture_binding = texData.binding;
}

fn unload(asset: *Asset) void {
    if (!initialized)
        @panic("Firefly module not initialized");

    var spriteData: *SpriteData = resources.get(asset.resource_id);
    spriteData.texture_binding = NO_BINDING;
}

fn delete(asset: *Asset) void {
    Asset.activateById(asset.index, false);
    resources.reset(asset.resource_id);
}
