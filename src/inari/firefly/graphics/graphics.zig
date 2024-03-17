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
const TextureBinding = firefly.api.TextureBinding;
const TextureFilter = firefly.api.TextureFilter;
const TextureWrap = firefly.api.TextureWrap;

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

pub const Component = firefly.api.Component;
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

pub fn init(_: firefly.api.InitMode) !void {
    defer initialized = true;
    if (initialized)
        return;

    // register Assets
    Component.API.registerComponent(Asset(Texture));

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

    // deinit api if it was initialized by this package
    if (api_init) {
        firefly.api.deinit();
        api_init = false;
    }
}

//////////////////////////////////////////////////////////////
//// ShaderAsset
//////////////////////////////////////////////////////////////

// pub const ShaderAsset = struct {
//     pub var asset_type: *Aspect = undefined;

//     pub const Shader = struct {
//         asset_name: String = NO_NAME,
//         vertex_shader_resource: String = NO_NAME,
//         fragment_shader_resource: String = NO_NAME,
//         file_resource: bool = true,
//     };

//     fn init() !void {
//         asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Shader");
//         shader = try DynArray(ShaderData).new(firefly.api.COMPONENT_ALLOC);
//         Asset.subscribe(listener);
//     }

//     fn deinit() void {
//         Asset.unsubscribe(listener);
//         asset_type = undefined;
//         shader.deinit();
//         shader = undefined;
//     }

//     pub fn new(data: Shader) *Asset {
//         if (!initialized)
//             @panic("Firefly module not initialized");

//         return Asset.new(Asset{
//             .asset_type = asset_type,
//             .name = data.asset_name,
//             .resource_id = shader.add(ShaderData{
//                 .vertex_shader_resource = data.vertex_shader_resource,
//                 .fragment_shader_resource = data.fragment_shader_resource,
//                 .file_resource = data.file_resource,
//             }),
//         });
//     }

//     fn listener(e: ComponentEvent) void {
//         var asset: *Asset = Asset.byId(e.c_id);
//         if (asset_type.index != asset.asset_type.index)
//             return;

//         switch (e.event_type) {
//             ActionType.ACTIVATED => load(asset),
//             ActionType.DEACTIVATING => unload(asset),
//             ActionType.DISPOSING => delete(asset),
//             else => {},
//         }
//     }

//     pub fn getResourceById(asset_id: Index, auto_load: bool) ?*const ShaderData {
//         var asset: *Asset = Asset.byId(asset_id);
//         // check if the asset is loaded, if not, try to auto-load it
//         if (!asset.isLoaded() and auto_load) {
//             if (!asset.load()) {
//                 std.log.err("Failed to load/activate dependent ShaderAsset: {any}", .{Asset.byId(asset.parent_asset_id)});
//                 return null;
//             }
//         }

//         return shader.get(asset.resource_id);
//     }

//     pub fn getBindingByAssetId(asset_id: Index) BindingId {
//         if (getResourceById(asset_id, true)) |res| {
//             return res.binding;
//         }
//         return NO_BINDING;
//     }

//     fn load(asset: *Asset) void {
//         if (!initialized)
//             return;

//         if (shader.get(asset.resource_id)) |sd| {
//             if (sd.binding != NO_BINDING)
//                 return; // already loaded

//             firefly.api.rendering.createShader(sd);
//         }
//     }

//     fn unload(asset: *Asset) void {
//         if (!initialized)
//             return;

//         if (shader.get(asset.resource_id)) |s| {
//             firefly.api.rendering.disposeShader(s);
//         }
//     }

//     fn delete(asset: *Asset) void {
//         Asset.activateById(asset.id, false);
//         shader.delete(asset.resource_id);
//     }
// };

//////////////////////////////////////////////////////////////
//// Texture Asset
//////////////////////////////////////////////////////////////

pub const Texture = struct {
    pub usingnamespace firefly.api.AssetTrait(Texture, "Texture");

    var textures: DynArray(Texture) = undefined;
    var type_init = false;

    name: ?String = null,
    resource: String,
    is_mipmap: bool = false,
    filter: TextureFilter = TextureFilter.TEXTURE_FILTER_POINT,
    wrap: TextureWrap = TextureWrap.TEXTURE_WRAP_CLAMP,

    _binding: ?TextureBinding = null,

    pub fn init() void {
        defer type_init = true;
        if (type_init)
            return;

        textures = DynArray(Texture).new(firefly.api.COMPONENT_ALLOC) catch unreachable;
    }

    pub fn deinit() void {
        defer type_init = false;
        if (!type_init)
            return;

        textures.deinit();
    }

    pub fn new(data: Texture) Index {
        if (!type_init) @panic("not initialized");

        return newAnd(data).id;
    }

    pub fn newAnd(data: Texture) *Asset(Texture) {
        if (!type_init) @panic("not initialized");

        return Asset(Texture).newAnd(.{
            .name = data.name,
            .resource_id = textures.add(data),
        });
    }

    pub fn doLoad(asset: *Asset(Texture)) void {
        if (!type_init) @panic("not initialized");

        if (textures.get(asset.resource_id)) |tex| {
            if (tex._binding != null)
                return; // already loaded

            tex._binding = firefly.api.rendering.loadTexture(
                tex.resource,
                tex.is_mipmap,
                tex.filter,
                tex.wrap,
            );
        }
    }

    pub fn doUnload(asset: *Asset(Texture)) void {
        if (!type_init) @panic("not initialized");

        if (asset.resource_id == UNDEF_INDEX)
            return;
        if (textures.get(asset.resource_id)) |tex| {
            if (tex._binding) |b| {
                firefly.api.rendering.disposeTexture(b.id);
                tex._binding = null;
            }
        }
    }

    pub fn getResource(asset_id: Index) ?*Texture {
        if (!type_init)
            return null;

        return textures.get(Asset(Texture).byId(asset_id).resource_id);
    }
};
