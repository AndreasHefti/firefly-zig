const std = @import("std");
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const graphics = @import("graphics.zig");
const api = graphics.api;
const utils = graphics.utils;

const Aspect = utils.aspect.Aspect;
const Asset = api.Asset;
const DynArray = utils.dynarray.DynArray;
const StringBuffer = utils.StringBuffer;
const ShaderData = api.ShaderData;
const BindingIndex = api.BindingIndex;
const String = utils.String;
const Event = api.Component.Event;
const ActionType = api.Component.ActionType;
const TextureData = api.TextureData;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;

pub var asset_type: *Aspect = undefined;
pub const NULL_VALUE = ShaderData{};

var initialized = false;
var resources: DynArray(ShaderData) = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Shader");
    resources = try DynArray(ShaderData).init(api.COMPONENT_ALLOC, NULL_VALUE);
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

pub const Shader = struct {
    asset_name: String = NO_NAME,
    vertex_shader_resource: String = NO_NAME,
    fragment_shader_resource: String = NO_NAME,
    file_resource: bool = true,
};

pub fn new(data: Shader) *Asset {
    if (!initialized)
        @panic("Firefly module not initialized");

    return Asset.new(Asset{
        .asset_type = asset_type,
        .name = data.asset_name,
        .resource_id = resources.add(ShaderData{
            .vertex_shader_resource = data.vertex_shader_resource,
            .fragment_shader_resource = data.fragment_shader_resource,
            .file_resource = data.file_resource,
        }),
    });
}

pub fn resourceSize() usize {
    return resources.size();
}

pub fn getResource(res_id: Index) *const ShaderData {
    return resources.get(res_id);
}

pub fn getResourceForIndex(res_id: Index, _: Index) *const ShaderData {
    return resources.get(res_id);
}

pub fn getResourceForName(res_id: Index, _: String) *const ShaderData {
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

    var shaderData: *ShaderData = resources.get(asset.resource_id);
    if (shaderData.binding != NO_BINDING)
        return; // already loaded

    api.RENDERING_API.createShader(shaderData) catch {
        std.log.err("Failed to load shader: {any}", .{shaderData});
    };
}

fn unload(asset: *Asset) void {
    if (!initialized)
        return;

    var shaderData: *ShaderData = resources.get(asset.resource_id);
    api.RENDERING_API.disposeShader(shaderData) catch {
        std.log.err("Failed to dispose shader: {any}", .{shaderData});
    };
}

fn delete(asset: *Asset) void {
    Asset.activateById(asset.id, false);
    resources.reset(asset.resource_id);
}
