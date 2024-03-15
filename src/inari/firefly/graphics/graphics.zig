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

pub const SpriteTemplate = sprite.SpriteTemplate;
pub const ESprite = sprite.ESprite;
//pub const SpriteDataKey = sprite.SpriteDataKey;
//pub const SpriteSet = sprite.SpriteSet;
//pub const SpriteSetAsset = sprite.SpriteSetAsset;

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

    pub const Shader = struct {
        asset_name: String = NO_NAME,
        vertex_shader_resource: String = NO_NAME,
        fragment_shader_resource: String = NO_NAME,
        file_resource: bool = true,
    };

    fn init() !void {
        asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Shader");
        shader = try DynArray(ShaderData).new(firefly.api.COMPONENT_ALLOC);
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

    fn listener(e: ComponentEvent) void {
        var asset: *Asset = Asset.byId(e.c_id);
        if (asset_type.index != asset.asset_type.index)
            return;

        switch (e.event_type) {
            ActionType.ACTIVATED => load(asset),
            ActionType.DEACTIVATING => unload(asset),
            ActionType.DISPOSING => delete(asset),
            else => {},
        }
    }

    pub fn getResourceById(asset_id: Index, auto_load: bool) ?*const ShaderData {
        var asset: *Asset = Asset.byId(asset_id);
        // check if the asset is loaded, if not, try to auto-load it
        if (!asset.isLoaded() and auto_load) {
            if (!asset.load()) {
                std.log.err("Failed to load/activate dependent ShaderAsset: {any}", .{Asset.byId(asset.parent_asset_id)});
                return null;
            }
        }

        return shader.get(asset.resource_id);
    }

    pub fn getBindingByAssetId(asset_id: Index) BindingId {
        if (getResourceById(asset_id, true)) |res| {
            return res.binding;
        }
        return NO_BINDING;
    }

    fn load(asset: *Asset) void {
        if (!initialized)
            return;

        if (shader.get(asset.resource_id)) |sd| {
            if (sd.binding != NO_BINDING)
                return; // already loaded

            firefly.api.rendering.createShader(sd);
        }
    }

    fn unload(asset: *Asset) void {
        if (!initialized)
            return;

        if (shader.get(asset.resource_id)) |s| {
            firefly.api.rendering.disposeShader(s);
        }
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

    name: String = NO_NAME,
    resource_path: String,
    is_mipmap: bool = false,
    s_wrap: CInt = -1,
    t_wrap: CInt = -1,
    min_filter: CInt = -1,
    mag_filter: CInt = -1,

    fn init() !void {
        asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Texture");
        textures = try DynArray(TextureData).new(firefly.api.COMPONENT_ALLOC);
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

    pub fn getResourceById(asset_id: Index, auto_load: bool) ?*const TextureData {
        var asset: *Asset = Asset.byId(asset_id);
        // check if the asset is loaded, if not, try to auto-load it
        if (!asset.isLoaded() and auto_load) {
            if (!asset.load()) {
                std.log.err("Failed to load/activate dependent TextureAsset: {any}", .{Asset.byId(asset.parent_asset_id)});
                return null;
            }
        }

        return textures.get(asset.resource_id);
    }

    pub fn getResourceByName(asset_name: String, auto_load: bool) ?*const TextureData {
        if (Asset.byName(asset_name)) |asset| {
            // check if the asset is loaded, if not, try to auto-load it
            if (!asset.isLoaded() and auto_load) {
                if (!asset.load()) {
                    std.log.err("Failed to load/activate dependent TextureAsset: {any}", .{Asset.byId(asset.parent_asset_id)});
                    return null;
                }
            }

            return textures.get(asset.resource_id);
        } else {
            return null;
        }
    }

    pub fn getBindingByAssetId(asset_id: Index) BindingId {
        if (getResourceById(asset_id, true)) |res| {
            return res.binding;
        }
        return NO_BINDING;
    }

    pub fn getBindingByAssetName(asset_name: String) BindingId {
        if (getResourceByName(asset_name, true)) |res| {
            return res.binding;
        }
        return NO_BINDING;
    }

    fn listener(e: ComponentEvent) void {
        var asset: *Asset = Asset.byId(e.c_id);
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

        if (textures.get(asset.resource_id)) |tex| {
            if (tex.binding != NO_BINDING)
                return; // already loaded

            firefly.api.rendering.loadTexture(tex);
        }
    }

    fn unload(asset: *Asset) void {
        if (!initialized)
            return;

        if (asset.resource_id == UNDEF_INDEX)
            return;

        if (textures.get(asset.resource_id)) |tex| {
            if (tex.binding == NO_BINDING)
                return; // already disposed

            firefly.api.rendering.disposeTexture(tex);

            assert(tex.binding == NO_BINDING);
            assert(tex.width == -1);
            assert(tex.height == -1);
        }
    }

    fn delete(asset: *Asset) void {
        Asset.activateById(asset.id, false);
        textures.delete(asset.resource_id);
    }
};
