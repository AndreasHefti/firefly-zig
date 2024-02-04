const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const api = @import("../../api/api.zig"); // TODO module
const graphics = @import("../graphics.zig");

const Layer = graphics.Layer;
const Component = api.Component;
const Kind = api.utils.aspect.Kind;
const Aspect = api.utils.aspect.Aspect;
const String = api.utils.String;
const TransformData = api.TransformData;
const RenderData = api.RenderData;
const RenderTextureData = api.RenderTextureData;
const Vec2f = api.utils.geom.Vector2f;

const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;
const View = @This();

// component type fields
pub const NULL_VALUE = View{};
pub const COMPONENT_NAME = "View";
pub const pool = Component.ComponentPool(View);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (View) *View = undefined;
pub var exists: *const fn (Index) bool = undefined;
pub var existsName: *const fn (String) bool = undefined;
pub var get: *const fn (Index) *View = undefined;
pub var byId: *const fn (Index) *const View = undefined;
pub var byName: *const fn (String) *const View = undefined;
pub var activateById: *const fn (Index, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (Index) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields
id: Index = UNDEF_INDEX,
name: String = NO_NAME,
/// Rendering order. 0 means screen, every above means render texture that is rendered in ascending order
camera_position: Vec2f = Vec2f{},
order: u8 = 0,
render_data: RenderData = RenderData{},
transform_data: TransformData = TransformData{},
render_texture: RenderTextureData = RenderTextureData{},
shader_binding: api.BindingIndex = api.NO_BINDING,

pub fn withNewLayer(self: *View, layer: Layer) *View {
    Component.checkValid(self);

    Layer.new(layer).view_ref = self.id;
    return self;
}

pub fn withShader(self: *View, id: Index) void {
    const shader_asset: *api.Asset = api.Asset.byId(id);
    self.shader_binding = graphics.ShaderAsset.getResource(shader_asset.resource_id).binding;
}

pub fn withShaderByName(self: *View, name: String) void {
    const shader_asset: *api.Asset = api.Asset.byIdName(name);
    self.shader_binding = graphics.ShaderAsset.getResource(shader_asset.resource_id).binding;
}

pub fn onActivation(id: Index, active: bool) void {
    var view: *View = View.byId(id);
    Component.checkValid(view);
    if (active) {
        activate(view);
    } else {
        deactivate(view);
    }
}

fn activate(view: *View) void {
    if (view.order == 0) {
        // screen, no render texture load needed
        return;
    }

    // create render texture for this view and make binding
    api.RENDERING_API.createRenderTexture(&view.render_texture) catch {
        std.log.err("Failed to create render texture vor view: {any}", .{view});
    };
}

fn deactivate(view: *View) void {
    if (view.order == 0) {
        // screen, no render texture load needed
        return;
    }

    // dispose render texture for this view and cancel binding
    api.RENDERING_API.disposeRenderTexture(&view.render_texture) catch {
        std.log.err("Failed to dispose render texture vor view: {any}", .{view});
    };
}
