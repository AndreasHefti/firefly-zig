const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;
const sprite = @import("sprite.zig");
const shape = @import("shape.zig");
const view = @import("view.zig");
const tile = @import("tile.zig");
const text = @import("text.zig");

const String = utils.String;
const Float = utils.Float;
const Vector2f = utils.Vector2f;
const Vector3f = utils.Vector3f;
const Vector4f = utils.Vector4f;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const SpriteTemplate = sprite.SpriteTemplate;
pub const ESprite = sprite.ESprite;
pub const SpriteSet = sprite.SpriteSet;

pub const ETile = tile.ETile;
pub const TileGrid = tile.TileGrid;
pub const TileTypeAspect = tile.TileTypeAspect;
pub const TileTypeAspectGroup = tile.TileTypeAspectGroup;
pub const TileTypeKind = tile.TileTypeKind;
pub const BasicTileTypes = tile.BasicTileTypes;

pub const EShape = shape.EShape;
pub const EText = text.EText;
pub const Font = text.Font;

pub const View = view.View;
pub const ViewChangeListener = view.ViewChangeListener;
pub const ViewChangeEvent = view.ViewChangeEvent;
pub const Layer = view.Layer;
pub const EView = view.EView;
pub const ViewLayerMapping = view.ViewLayerMapping;
pub const ETransform = view.ETransform;
pub const ViewRenderEvent = firefly.api.ViewRenderEvent;
pub const ViewRenderListener = firefly.api.ViewRenderListener;
pub const ViewRenderer = view.ViewRenderer;
pub const Scene = view.Scene;

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;
var api_init = false;

pub fn init(_: firefly.api.InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    // init Assets types
    api.Asset(Texture).init();
    api.Asset(Shader).init();

    // init sub packages
    try view.init();
    try sprite.init();
    try shape.init();
    try tile.init();
    try text.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit Assets types
    api.Asset(Texture).deinit();
    api.Asset(Shader).deinit();

    // deinit sub packages
    text.deinit();
    tile.deinit();
    shape.deinit();
    sprite.deinit();
    view.deinit();

    // deinit api if it was initialized by this package
    if (api_init) {
        firefly.api.deinit();
        api_init = false;
    }
}

//////////////////////////////////////////////////////////////
//// ShaderAsset
//////////////////////////////////////////////////////////////

pub const Shader = struct {
    pub usingnamespace firefly.api.AssetTrait(Shader, "Shader");

    name: String,
    vertex_shader_resource: ?String = null,
    fragment_shader_resource: ?String = null,
    file_resource: bool = true,

    _binding: ?api.ShaderBinding = null,

    pub fn loadResource(component: *api.AssetComponent) void {
        if (Shader.resourceById(component.resource_id)) |res| {
            if (res._binding != null)
                return; // already loaded

            res._binding = firefly.api.rendering.createShader(
                res.vertex_shader_resource,
                res.fragment_shader_resource,
                res.file_resource,
            );
        }
    }

    pub fn disposeResource(component: *api.AssetComponent) void {
        if (Shader.resourceById(component.resource_id)) |res| {
            if (res._binding) |b| {
                firefly.api.rendering.disposeShader(b.id);
                res._binding = null;
            }
        }
    }

    pub fn setByNameUniformFloat(asset_name: String, name: String, v_ptr: *Float) bool {
        if (Shader.getResourceByName(asset_name)) |s| {
            return s._set_uniform_float(s.binding_id, name, v_ptr);
        }
        return false;
    }
    pub fn setByNameUniformVec2(asset_name: String, name: String, v_ptr: *Vector2f) bool {
        if (Shader.getResourceByName(asset_name)) |s| {
            return s._set_uniform_vec2(s.binding_id, name, v_ptr);
        }
        return false;
    }
    pub fn setByNameUniformVec3(asset_name: String, name: String, v_ptr: *Vector3f) bool {
        if (Shader.getResourceByName(asset_name)) |s| {
            return s._set_uniform_vec3(s.binding_id, name, v_ptr);
        }
        return false;
    }
    pub fn setByNameUniformVec4(asset_name: String, name: String, v_ptr: *Vector4f) bool {
        if (Shader.getResourceByName(asset_name)) |s| {
            return s._set_uniform_vec4(s.binding_id, name, v_ptr);
        }
        return false;
    }
    pub fn setByNameUniformTexture(asset_name: String, name: String, tex_binding: api.BindingId) bool {
        if (Shader.getResourceByName(asset_name)) |s| {
            return s._set_uniform_texture(s.binding_id, name, tex_binding);
        }
        return false;
    }

    pub fn setUniformFloat(self: *Shader, name: String, v_ptr: *Float) bool {
        return self._set_uniform_float(self.binding_id, name, v_ptr);
    }
    pub fn setUniformVec2(self: *Shader, name: String, v_ptr: *Vector2f) bool {
        return self._set_uniform_vec2(self.binding_id, name, v_ptr);
    }
    pub fn setUniformVec3(self: *Shader, name: String, v_ptr: *Vector3f) bool {
        return self._set_uniform_vec3(self.binding_id, name, v_ptr);
    }
    pub fn setUniformVec4(self: *Shader, name: String, v_ptr: *Vector4f) bool {
        return self._set_uniform_vec4(self.binding_id, name, v_ptr);
    }
    pub fn setUniformTexture(self: *Shader, name: String, tex_binding: api.BindingId) bool {
        return self._set_uniform_texture(self.binding_id, name, tex_binding);
    }
};

//////////////////////////////////////////////////////////////
//// Texture Asset
//////////////////////////////////////////////////////////////

pub const Texture = struct {
    pub usingnamespace firefly.api.AssetTrait(Texture, "Texture");

    name: String,
    resource: String,
    is_mipmap: bool = false,
    filter: api.TextureFilter = api.TextureFilter.TEXTURE_FILTER_POINT,
    wrap: api.TextureWrap = api.TextureWrap.TEXTURE_WRAP_CLAMP,

    _binding: ?api.TextureBinding = null,

    pub fn loadResource(component: *api.AssetComponent) void {
        if (Texture.resourceById(component.resource_id)) |res| {
            if (res._binding != null)
                return; // already loaded

            res._binding = firefly.api.rendering.loadTexture(
                res.resource,
                res.is_mipmap,
                res.filter,
                res.wrap,
            );
        }
    }

    pub fn disposeResource(component: *api.AssetComponent) void {
        if (Texture.resourceById(component.resource_id)) |res| {
            if (res._binding) |b| {
                firefly.api.rendering.disposeTexture(b.id);
                res._binding = null;
            }
        }
    }
};
