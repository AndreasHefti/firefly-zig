const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const assert = std.debug.assert;
const sprite = @import("sprite.zig");
const view = @import("view.zig");

const Allocator = std.mem.Allocator;
const Aspect = utils.Aspect;
const Asset = firefly.api.Asset;
const DynArray = utils.DynArray;
const StringBuffer = utils.StringBuffer;
const ShaderData = firefly.api.ShaderData;
const BindingId = firefly.api.BindingId;
const String = utils.String;
const ComponentEvent = firefly.api.ComponentEvent;
const ActionType = firefly.api.ComponentActionType;
const TextureData = firefly.api.TextureData;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = firefly.api.NO_BINDING;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;
const CInt = utils.CInt;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const ESprite = sprite.ESprite;
pub const SpriteAsset = sprite.SpriteAsset;
pub const SpriteSet = sprite.SpriteSet;
pub const SpriteSetAsset = sprite.SpriteSetAsset;

pub const View = view.View;
pub const Layer = view.Layer;
pub const ViewLayerMapping = view.ViewLayerMapping;
pub const EMultiplier = view.EMultiplier;
pub const ETransform = view.ETransform;
pub const ViewRenderEvent = view.ViewRenderEvent;
pub const ViewRenderListener = view.ViewRenderListener;
pub const ViewRenderer = view.ViewRenderer;

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;
var api_init = false;

var textures: DynArray(TextureData) = undefined;
var shader: DynArray(ShaderData) = undefined;

pub fn init(_: firefly.api.InitMode) !void {
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
        firefly.api.deinit();
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
        shader = try DynArray(ShaderData).new(firefly.api.COMPONENT_ALLOC, NULL_VALUE);
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

        firefly.api.rendering.createShader(shaderData);
    }

    fn unload(asset: *Asset) void {
        if (!initialized)
            return;

        var shaderData: *ShaderData = shader.get(asset.resource_id);
        firefly.api.rendering.disposeShader(shaderData);
    }

    fn delete(asset: *Asset) void {
        Asset.activateById(asset.id, false);
        shader.delete(asset.resource_id);
    }
};

//////////////////////////////////////////////////////////////
//// TextureAsset
//////////////////////////////////////////////////////////////

pub const TextureAsset = struct {
    pub var asset_type: *Aspect = undefined;
    pub const NULL_VALUE = TextureData{};

    name: String = NO_NAME,
    resource_path: String,
    is_mipmap: bool = false,
    s_wrap: CInt = -1,
    t_wrap: CInt = -1,
    min_filter: CInt = -1,
    mag_filter: CInt = -1,

    fn init() !void {
        asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Texture");
        textures = try DynArray(TextureData).new(firefly.api.COMPONENT_ALLOC, NULL_VALUE);
        Asset.subscribe(listener);
    }

    fn deinit() void {
        Asset.unsubscribe(listener);
        asset_type = undefined;
        textures.clear();
        textures.deinit();
        textures = undefined;
    }

    pub fn new(data: TextureAsset) *Asset {
        if (!initialized) @panic("Firefly module not initialized");

        return Asset.new(Asset{
            .asset_type = asset_type,
            .name = data.name,
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

        firefly.api.rendering.loadTexture(tex_data);
    }

    fn unload(asset: *Asset) void {
        if (!initialized)
            return;

        if (asset.resource_id == UNDEF_INDEX)
            return;

        var tex_data: *TextureData = textures.get(asset.resource_id);
        if (tex_data.binding == NO_BINDING)
            return; // already disposed

        firefly.api.rendering.disposeTexture(tex_data);

        assert(tex_data.binding == NO_BINDING);
        assert(tex_data.width == -1);
        assert(tex_data.height == -1);
    }

    fn delete(asset: *Asset) void {
        Asset.activateById(asset.id, false);
        textures.delete(asset.resource_id);
    }
};
