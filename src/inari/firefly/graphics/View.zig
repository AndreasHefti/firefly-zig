const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const api = @import("../api/api.zig"); // TODO module
const graphics = @import("graphics.zig");

const Layer = graphics.Layer;
const Component = api.Component;
const Kind = api.utils.aspect.Kind;
const Aspect = api.utils.aspect.Aspect;
const String = api.utils.String;
const TransformData = api.TransformData;
const RenderData = api.RenderData;
const RenderTextureData = api.RenderTextureData;
const Vec2f = api.utils.geom.Vector2f;

const UNDEF_INDEX = api.utils.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;
const View = @This();

// component type fields
pub const NULL_VALUE = View{};
pub const COMPONENT_NAME = "View";
pub const pool = Component.ComponentPool(View);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (View) *View = undefined;
pub var byId: *const fn (usize) *View = undefined;
pub var byName: *const fn (String) ?*View = undefined;
pub var activateById: *const fn (usize, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (usize) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
/// Rendering order. 0 means screen, every above means render texture that is rendered in ascending order
order: usize = 0,
camera_position: Vec2f = Vec2f{},
render: RenderData = RenderData{},
render_texture: RenderTextureData = RenderTextureData{},
transform: TransformData = TransformData{},
shader_binding: api.BindingIndex = api.NO_BINDING,

pub fn withLayerByName(self: *View, name: String) *View {
    Component.checkValid(self);

    var l: *Layer = Layer.byName(name);
    l.view_ref = self.index;
    return self;
}

pub fn withNewLayer(self: *View, layer: Layer) *View {
    Component.checkValid(self);

    Layer.new(layer).view_ref = self.index;
    return self;
}

pub fn onActivation(index: usize, active: bool) void {
    var view: *View = View.byId(index);
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

// inline fn checkValid(view: *View) void {
//     assert(view.index != UNDEF_INDEX);
// }
