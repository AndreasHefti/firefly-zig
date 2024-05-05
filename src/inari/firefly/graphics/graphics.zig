const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const assert = std.debug.assert;
const sprite = @import("sprite.zig");
const shape = @import("shape.zig");
const view = @import("view.zig");
const tile = @import("tile.zig");
const text = @import("text.zig");

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
const ShaderBinding = firefly.api.ShaderBinding;
const Component = firefly.api.Component;

const NO_BINDING = firefly.api.NO_BINDING;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;
const CInt = utils.CInt;
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

pub const EShape = shape.EShape;

pub const EText = text.EText;
pub const Font = text.Font;

pub const View = view.View;
pub const Layer = view.Layer;
pub const EView = view.EView;
pub const ViewLayerMapping = view.ViewLayerMapping;
pub const ETransform = view.ETransform;
pub const ViewRenderEvent = firefly.api.ViewRenderEvent;
pub const ViewRenderListener = firefly.api.ViewRenderListener;
pub const ViewRenderer = view.ViewRenderer;

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;
var api_init = false;

pub fn init(_: firefly.api.InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    // register Assets
    Component.registerComponent(Asset(Texture));
    Component.registerComponent(Asset(Shader));

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

    _binding: ?ShaderBinding = null,

    pub fn doLoad(_: *Asset(Shader), resource: *Shader) void {
        if (resource._binding != null)
            return; // already loaded

        resource._binding = firefly.api.rendering.createShader(
            resource.vertex_shader_resource,
            resource.fragment_shader_resource,
            resource.file_resource,
        );
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
    pub fn setByNameUniformTexture(asset_name: String, name: String, tex_binding: BindingId) bool {
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
    pub fn setUniformTexture(self: *Shader, name: String, tex_binding: BindingId) bool {
        return self._set_uniform_texture(self.binding_id, name, tex_binding);
    }

    pub fn doUnload(_: *Asset(Shader), resource: *Shader) void {
        if (resource._binding) |b| {
            firefly.api.rendering.disposeShader(b.id);
            resource._binding = null;
        }
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
    filter: TextureFilter = TextureFilter.TEXTURE_FILTER_POINT,
    wrap: TextureWrap = TextureWrap.TEXTURE_WRAP_CLAMP,

    _binding: ?TextureBinding = null,

    pub fn doLoad(_: *Asset(Texture), resource: *Texture) void {
        if (resource._binding != null)
            return; // already loaded

        resource._binding = firefly.api.rendering.loadTexture(
            resource.resource,
            resource.is_mipmap,
            resource.filter,
            resource.wrap,
        );
    }

    pub fn doUnload(_: *Asset(Texture), resource: *Texture) void {
        if (resource._binding) |b| {
            firefly.api.rendering.disposeTexture(b.id);
            resource._binding = null;
        }
    }
};
