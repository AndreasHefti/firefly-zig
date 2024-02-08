const std = @import("std");
const assert = std.debug.assert;

const graphics = @import("graphics.zig");
const api = graphics.api;
const utils = graphics.utils;

const Aspect = utils.aspect.Aspect;
const Asset = api.Asset;
const DynArray = utils.dynarray.DynArray;
const StringBuffer = utils.StringBuffer;
const SpriteData = api.SpriteData;
const BindingIndex = api.BindingIndex;
const String = utils.String;
const Event = api.Component.Event;
const ActionType = api.Component.ActionType;
const TextureData = api.TextureData;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;
const CInt = utils.CInt;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;

var initialized = false;
var resources: DynArray(TextureData) = undefined;

pub var asset_type: *Aspect = undefined;
pub const NULL_VALUE = TextureData{};

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Texture");
    resources = try DynArray(TextureData).init(api.COMPONENT_ALLOC, NULL_VALUE);
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

pub const Texture = struct {
    asset_name: String = NO_NAME,
    resource_path: String,
    is_mipmap: bool = false,
    s_wrap: CInt = -1,
    t_wrap: CInt = -1,
    min_filter: CInt = -1,
    mag_filter: CInt = -1,
};

pub fn new(data: Texture) *Asset {
    if (!initialized) @panic("Firefly module not initialized");

    return Asset.new(Asset{
        .asset_type = asset_type,
        .name = data.asset_name,
        .resource_id = resources.add(
            TextureData{
                .resource = data.resource_path,
                .is_mipmap = data.is_mipmap,
                .s_wrap = data.s_wrap,
                .t_wrap = data.t_wrap,
                .min_filter = data.min_filter,
                .mag_filter = data.mag_filter,
            },
        ),
    });
}

pub fn resourceSize() usize {
    return resources.size();
}

pub fn getResource(res_id: Index) *const TextureData {
    return resources.get(res_id);
}

pub fn getResourceForIndex(res_id: Index, _: Index) *const TextureData {
    return resources.get(res_id);
}

pub fn getResourceForName(res_id: Index, _: String) *const TextureData {
    return resources.get(res_id);
}

fn listener(e: Event) void {
    var asset: *Asset = Asset.pool.get(e.c_id);
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
        return;

    var tex_data = resources.get(asset.resource_id);
    if (tex_data.binding != NO_BINDING)
        return; // already loaded

    api.RENDERING_API.loadTexture(tex_data) catch {
        std.log.err("Failed to load texture resource: {s}", .{tex_data.resource});
    };
}

fn unload(asset: *Asset) void {
    if (!initialized)
        return;

    if (asset.resource_id == UNDEF_INDEX)
        return;

    var tex_data: *TextureData = resources.get(asset.resource_id);
    if (tex_data.binding == NO_BINDING)
        return; // already disposed

    api.RENDERING_API.disposeTexture(tex_data) catch {
        std.log.err("Failed to dispose texture resource: {s}", .{tex_data.resource});
        return;
    };

    assert(tex_data.binding == NO_BINDING);
    assert(tex_data.width == -1);
    assert(tex_data.height == -1);
}

fn delete(asset: *Asset) void {
    Asset.activateById(asset.id, false);
    resources.reset(asset.resource_id);
}
