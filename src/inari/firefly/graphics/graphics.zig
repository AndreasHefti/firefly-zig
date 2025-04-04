const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;
const sprite = @import("sprite.zig");
const shape = @import("shape.zig");
const view = @import("view.zig");
const tile = @import("tile.zig");
const text = @import("text.zig");

const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const String = utils.String;
const Float = utils.Float;
const Vector2f = utils.Vector2f;
const Vector3f = utils.Vector3f;
const Vector4f = utils.Vector4f;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const Sprite = sprite.Sprite;
pub const ESprite = sprite.ESprite;
pub const SpriteSet = sprite.SpriteSet;
pub const DefaultSpriteRenderer = sprite.DefaultSpriteRenderer;

pub const ETile = tile.ETile;
pub const TileGrid = tile.TileGrid;
// Tile Type Aspects
pub const TileTypeAspectGroup = utils.AspectGroup("TileType");
pub const TileTypeAspect = TileTypeAspectGroup.Aspect;
pub const TileTypeKind = TileTypeAspectGroup.Kind;
pub const BasicTileTypes = tile.BasicTileTypes;
pub const DefaultTileGridRenderer = tile.DefaultTileGridRenderer;

pub const EShape = shape.EShape;
pub const DefaultShapeRenderer = shape.DefaultShapeRenderer;
pub const EText = text.EText;
pub const Font = text.Font;
pub const DefaultTextRenderer = text.DefaultTextRenderer;

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
pub const WindowResolutionAdaption = view.WindowResolutionAdaption;

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;
var api_init = false;

pub fn init(_: firefly.api.InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    // register Assets sub types
    api.Component.Subtype.register(api.Asset, Texture, "Texture");
    api.Component.Subtype.register(api.Asset, Shader, "Shader");

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
//// EntityRendererMixin useful for entity renderer systems
//////////////////////////////////////////////////////////////

pub fn EntityRendererMixin(comptime T: type) type {
    return struct {
        comptime {
            if (@typeInfo(T) != .Struct)
                @compileError("Expects component type is a struct.");
            if (!@hasDecl(T, "renderEntities"))
                @compileError("Expects type has fn: renderEntities(*utils.BitSet)");
        }

        pub var entity_condition: ?api.EntityTypeCondition = null;
        pub var entities: ViewLayerMapping = undefined;

        pub fn init() void {
            entities = ViewLayerMapping.new();
            if (@hasDecl(T, "accept") or @hasDecl(T, "dismiss")) {
                entity_condition = api.EntityTypeCondition{
                    .accept_kind = if (@hasDecl(T, "accept")) api.EComponentAspectGroup.newKindOf(T.accept) else null,
                    .accept_full_only = if (@hasDecl(T, "accept_full_only")) T.accept_full_only else true,
                    .dismiss_kind = if (@hasDecl(T, "dismiss")) api.EComponentAspectGroup.newKindOf(T.dismiss) else null,
                };
            }
        }

        pub fn deinit() void {
            entity_condition = undefined;
            entities.deinit();
            entities = undefined;
        }

        pub fn entityRegistration(id: Index, register: bool) void {
            if (register)
                entities.addWithEView(EView.Component.byIdOptional(id), id)
            else
                entities.removeWithEView(EView.Component.byIdOptional(id), id);
        }

        pub fn renderView(e: ViewRenderEvent) void {
            if (entities.get(e.view_id, e.layer_id)) |all| {
                T.renderEntities(all, e);
            }
        }
    };
}

//////////////////////////////////////////////////////////////
//// ComponentRendererMixin useful for component renderer systems
//////////////////////////////////////////////////////////////

pub fn ComponentRendererMixin(comptime T: type, comptime CType: type) type {
    return struct {
        comptime {
            if (@typeInfo(T) != .Struct)
                @compileError("Expects component type is a struct.");
            if (!@hasDecl(T, api.FUNCTION_NAMES.SYSTEM_RENDER_COMPONENT_FUNCTION))
                @compileError("Expects type has fn: renderComponents(*utils.BitSet)");
        }

        pub const component_register_type = CType;
        pub var components: ViewLayerMapping = undefined;

        pub fn init() void {
            components = ViewLayerMapping.new();
        }

        pub fn deinit() void {
            components.deinit();
            components = undefined;
        }

        pub fn componentRegistration(id: Index, register: bool) void {
            const comp = CType.Component.byId(id);
            if (register)
                components.add(comp.view_id, comp.layer_id, id)
            else
                components.remove(comp.view_id, comp.layer_id, id);
        }

        pub fn renderView(e: ViewRenderEvent) void {
            if (components.get(e.view_id, e.layer_id)) |all| {
                T.renderComponents(all, e);
            }
        }
    };
}

//////////////////////////////////////////////////////////////
//// ShaderAsset
//////////////////////////////////////////////////////////////

pub const Shader = struct {
    pub const Component = api.Component.SubTypeMixin(api.Asset, Shader);

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    vertex_shader_resource: ?String = null,
    fragment_shader_resource: ?String = null,
    file_resource: bool = true,

    _binding: ?api.ShaderBinding = null,

    pub fn activation(self: *Shader, active: bool) void {
        if (active) {
            if (self._binding != null)
                return; // already loaded

            self._binding = firefly.api.rendering.createShader(
                self.vertex_shader_resource,
                self.fragment_shader_resource,
                self.file_resource,
            ) catch |err| {
                api.Logger.errWith("Failed to load shader: {any}", .{self}, err);
                api.Asset.assetLoadError(self.id, err);
                return;
            };
            api.Asset.assetLoaded(self.id, true);
        } else {
            if (self._binding) |b| {
                firefly.api.rendering.disposeShader(b.id);
                self._binding = null;
            }
            api.Asset.assetLoaded(self.id, false);
        }
    }

    pub fn setByNameUniformFloat(asset_name: String, name: String, v: Float) bool {
        if (Shader.Component.byName(asset_name)) |s| {
            if (s._binding) |b|
                return b._set_uniform_float(s.binding_id, name, v);
        }
        return false;
    }
    pub fn setByNameUniformVec2(asset_name: String, name: String, v: Vector2f) bool {
        if (Shader.Component.byName(asset_name)) |s| {
            if (s._binding) |b|
                return b._set_uniform_vec2(b.id, name, v);
        }
        return false;
    }
    pub fn setByNameUniformVec3(asset_name: String, name: String, v: Vector3f) bool {
        if (Shader.Component.byName(asset_name)) |s| {
            if (s._binding) |b|
                return b._set_uniform_vec3(b.id, name, v);
        }
        return false;
    }
    pub fn setByNameUniformVec4(asset_name: String, name: String, v: Vector4f) bool {
        if (Shader.Component.byName(asset_name)) |s| {
            if (s._binding) |b|
                return b._set_uniform_vec4(b.id, name, v);
        }
        return false;
    }
    pub fn setByNameUniformTexture(asset_name: String, name: String, tex_binding: api.BindingId) bool {
        if (Shader.Component.byName(asset_name)) |s| {
            if (s._binding) |b|
                return b._set_uniform_texture(b.id, name, tex_binding);
        }
        return false;
    }

    pub fn setUniformFloat(self: *Shader, name: String, v: Float) bool {
        if (self._binding) |b|
            return b._set_uniform_float(b.id, name, v);
        return false;
    }
    pub fn setUniformVec2(self: *Shader, name: String, v: Vector2f) bool {
        if (self._binding) |b|
            return b._set_uniform_vec2(b.id, name, v);
        return false;
    }
    pub fn setUniformVec3(self: *Shader, name: String, v: Vector3f) bool {
        if (self._binding) |b|
            return b._set_uniform_vec3(b.id, name, v);
        return false;
    }
    pub fn setUniformVec4(self: *Shader, name: String, v: Vector4f) bool {
        if (self._binding) |b|
            return b._set_uniform_vec4(b.id, name, v);
        return false;
    }
    pub fn setUniformTexture(self: *Shader, name: String, tex_binding: api.BindingId) bool {
        if (self._binding) |b|
            return b._set_uniform_texture(b.id, name, tex_binding);
        return false;
    }
};

//////////////////////////////////////////////////////////////
//// Texture Asset
//////////////////////////////////////////////////////////////

pub const Texture = struct {
    pub const Component = api.Component.SubTypeMixin(api.Asset, Texture);

    id: Index = UNDEF_INDEX,
    name: String,
    resource: String,
    is_mipmap: bool = false,
    filter: api.TextureFilter = api.TextureFilter.TEXTURE_FILTER_POINT,
    wrap: api.TextureWrap = api.TextureWrap.TEXTURE_WRAP_CLAMP,

    _binding: ?api.TextureBinding = null,

    pub fn activation(self: *Texture, active: bool) void {
        if (active) {
            if (self._binding != null)
                return; // already loaded

            self._binding = firefly.api.rendering.loadTexture(
                self.resource,
                self.is_mipmap,
                self.filter,
                self.wrap,
            ) catch |err| {
                api.Logger.errWith("Failed to load texture: {any}", .{self}, err);
                api.Asset.assetLoadError(self.id, err);
                return;
            };
            api.Asset.assetLoaded(self.id, true);
        } else {
            if (self._binding) |b| {
                firefly.api.rendering.disposeTexture(b.id);
                self._binding = null;
            }
            api.Asset.assetLoaded(self.id, false);
        }
    }
};
