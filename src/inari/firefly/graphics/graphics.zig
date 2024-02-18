const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Aspect = utils.aspect.Aspect;
const Asset = api.Asset;
const DynArray = utils.dynarray.DynArray;
const StringBuffer = utils.StringBuffer;
const ShaderData = api.ShaderData;
const BindingId = api.BindingId;
const String = utils.String;
const ComponentEvent = api.Component.ComponentEvent;
const ActionType = api.Component.ActionType;
const TextureData = api.TextureData;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;
const CInt = utils.CInt;

//////////////////////////////////////////////////////////////
//// global
//////////////////////////////////////////////////////////////

pub const api = @import("../api/api.zig");
pub const utils = api.utils;
pub const sprite = @import("sprite.zig");
pub const view = @import("view.zig");

var initialized = false;
var api_init = false;

var textures: DynArray(TextureData) = undefined;
var shader: DynArray(ShaderData) = undefined;

pub fn initTesting() !void {
    try api.initTesting();
    try init(api.InitMode.TESTING);
    api_init = true;
}

pub fn init(_: api.InitMode) !void {
    defer initialized = true;
    if (initialized)
        return;

    // init Assets
    try TextureAsset.init();
    try ShaderAsset.init();

    // init sub packages
    try view.init();
    try sprite.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit sprite package
    sprite.deinit();
    view.deinit();
    // deinit Assets
    ShaderAsset.deinit();
    TextureAsset.deinit();

    // deinit api if it was initialized by this package
    if (api_init) {
        api.deinit();
        api_init = false;
    }
}

//////////////////////////////////////////////////////////////
//// ShaderAsset
//////////////////////////////////////////////////////////////

pub const ShaderAsset = struct {
    pub var asset_type: *Aspect = undefined;
    pub const NULL_VALUE = ShaderData{};

    pub const Shader = struct {
        asset_name: String = NO_NAME,
        vertex_shader_resource: String = NO_NAME,
        fragment_shader_resource: String = NO_NAME,
        file_resource: bool = true,
    };

    fn init() !void {
        asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Shader");
        shader = try DynArray(ShaderData).init(api.COMPONENT_ALLOC, NULL_VALUE);
        Asset.subscribe(listener);
    }

    fn deinit() void {
        Asset.unsubscribe(listener);
        asset_type = undefined;
        shader.deinit();
        shader = undefined;
    }

    pub fn new(data: Shader) *Asset {
        if (!initialized)
            @panic("Firefly module not initialized");

        return Asset.new(Asset{
            .asset_type = asset_type,
            .name = data.asset_name,
            .resource_id = shader.add(ShaderData{
                .vertex_shader_resource = data.vertex_shader_resource,
                .fragment_shader_resource = data.fragment_shader_resource,
                .file_resource = data.file_resource,
            }),
        });
    }

    pub fn resourceSize() usize {
        return shader.size();
    }

    pub fn getResource(res_id: Index) *const ShaderData {
        return shader.get(res_id);
    }

    pub fn getResourceForIndex(res_id: Index, _: Index) *const ShaderData {
        return shader.get(res_id);
    }

    pub fn getResourceForName(res_id: Index, _: String) *const ShaderData {
        return shader.get(res_id);
    }

    fn listener(e: ComponentEvent) void {
        var asset: *Asset = Asset.pool.get(e.c_id);
        if (asset_type.index != asset.asset_type.index)
            return;

        switch (e.event_type) {
            ActionType.ACTIVATED => load(asset),
            ActionType.DEACTIVATING => unload(asset),
            ActionType.DISPOSING => delete(asset),
            else => {},
        }
    }

    fn load(asset: *Asset) void {
        if (!initialized)
            return;

        var shaderData: *ShaderData = shader.get(asset.resource_id);
        if (shaderData.binding != NO_BINDING)
            return; // already loaded

        api.RENDERING_API.createShader(shaderData);
    }

    fn unload(asset: *Asset) void {
        if (!initialized)
            return;

        var shaderData: *ShaderData = shader.get(asset.resource_id);
        api.RENDERING_API.disposeShader(shaderData);
    }

    fn delete(asset: *Asset) void {
        Asset.activateById(asset.id, false);
        shader.reset(asset.resource_id);
    }
};

//////////////////////////////////////////////////////////////
//// TextureAsset
//////////////////////////////////////////////////////////////

pub const TextureAsset = struct {
    pub var asset_type: *Aspect = undefined;
    pub const NULL_VALUE = TextureData{};

    pub const Texture = struct {
        asset_name: String = NO_NAME,
        resource_path: String,
        is_mipmap: bool = false,
        s_wrap: CInt = -1,
        t_wrap: CInt = -1,
        min_filter: CInt = -1,
        mag_filter: CInt = -1,
    };

    fn init() !void {
        asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Texture");
        textures = try DynArray(TextureData).init(api.COMPONENT_ALLOC, NULL_VALUE);
        Asset.subscribe(listener);
    }

    fn deinit() void {
        Asset.unsubscribe(listener);
        asset_type = undefined;
        textures.deinit();
        textures = undefined;
    }

    pub fn new(data: Texture) *Asset {
        if (!initialized) @panic("Firefly module not initialized");

        return Asset.new(Asset{
            .asset_type = asset_type,
            .name = data.asset_name,
            .resource_id = textures.add(
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
        return textures.size();
    }

    pub fn getResource(res_id: Index) *const TextureData {
        return textures.get(res_id);
    }

    pub fn getResourceForIndex(res_id: Index, _: Index) *const TextureData {
        return textures.get(res_id);
    }

    pub fn getResourceForName(res_id: Index, _: String) *const TextureData {
        return textures.get(res_id);
    }

    fn listener(e: ComponentEvent) void {
        var asset: *Asset = Asset.pool.get(e.c_id);
        if (asset_type.index != asset.asset_type.index)
            return;

        switch (e.event_type) {
            ActionType.ACTIVATED => load(asset),
            ActionType.DEACTIVATING => unload(asset),
            ActionType.DISPOSING => delete(asset),
            else => {},
        }
    }

    fn load(asset: *Asset) void {
        if (!initialized)
            return;

        var tex_data = textures.get(asset.resource_id);
        if (tex_data.binding != NO_BINDING)
            return; // already loaded

        api.RENDERING_API.loadTexture(tex_data);
    }

    fn unload(asset: *Asset) void {
        if (!initialized)
            return;

        if (asset.resource_id == UNDEF_INDEX)
            return;

        var tex_data: *TextureData = textures.get(asset.resource_id);
        if (tex_data.binding == NO_BINDING)
            return; // already disposed

        api.RENDERING_API.disposeTexture(tex_data);

        assert(tex_data.binding == NO_BINDING);
        assert(tex_data.width == -1);
        assert(tex_data.height == -1);
    }

    fn delete(asset: *Asset) void {
        Asset.activateById(asset.id, false);
        textures.reset(asset.resource_id);
    }
};
