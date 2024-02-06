const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const graphics = @import("../graphics.zig");
const api = graphics.api;

const Layer = graphics.Layer;
const Component = api.Component;
const Aspect = api.utils.aspect.Aspect;
const String = api.utils.String;
const TransformData = api.TransformData;
const RenderData = api.RenderData;
const RenderTextureData = api.RenderTextureData;
const Vec2f = api.utils.geom.Vector2f;
const DynArray = graphics.utils.dynarray.DynArray;
const ActionType = api.ActionType;
const Projection = api.Projection;

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
order: u8 = undefined,
render_data: RenderData = RenderData{},
transform: TransformData = TransformData{},
projection: Projection = Projection{},
render_texture: RenderTextureData = RenderTextureData{},
shader_binding: api.BindingIndex = api.NO_BINDING,
ordered_active_layer: ?*DynArray(Index) = null,

pub var screen_projection: Projection = Projection{};
pub var ordered_active_views: DynArray(Index) = undefined;

pub fn init() !void {
    ordered_active_views = DynArray(Index).initWithRegisterSize(api.COMPONENT_ALLOC, 10, UNDEF_INDEX);
    Layer.subscribe(onLayerAction);
}

pub fn deinit() void {
    Layer.unsubscribe(onLayerAction);
    ordered_active_views.deinit();
}

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
    if (view.order == 0)
        return; // screen, no render texture load needed

    addViewMapping(view);

    api.RENDERING_API.createRenderTexture(&view.render_texture) catch {
        std.log.err("Failed to create render texture for view: {any}", .{view});
    };
}

fn deactivate(view: *View) void {
    // dispose render texture for this view and cancel binding
    if (view.order == 0)
        return; // screen, no render texture dispose needed

    removeViewMapping(view);
    api.RENDERING_API.disposeRenderTexture(&view.render_texture) catch {
        std.log.err("Failed to dispose render texture for view: {any}", .{view});
    };
}

fn onLayerAction(event: *const Component.Event) void {
    switch (event.event_type) {
        ActionType.ACTIVATED => addLayerMapping(Layer.byId(event.c_id)),
        ActionType.DEACTIVATED => removeLayerMapping(Layer.byId(event.c_id)),
        else => {},
    }
}

fn addViewMapping(view: *View) void {
    if (ordered_active_views.slots.isSet(view.order)) {
        std.log.err("Order of view already in use: {any}", .{view});
        @panic("View order mismatch");
    }

    ordered_active_views.insert(view.order, view.id);
}

fn removeViewMapping(view: *View) void {
    if (!ordered_active_views.slots.isSet(view.order))
        return;

    // clear layer mapping
    if (view.ordered_active_layer) |l| {
        l.clear();
    }

    // clear view mapping
    ordered_active_views.reset(view.order);
}

fn addLayerMapping(layer: *Layer) void {
    var view: *View = View.get(layer.view_id);
    if (view.ordered_active_layer == null) {
        view.ordered_active_layer = DynArray(Index).initWithRegisterSize(
            api.COMPONENT_ALLOC,
            10,
            UNDEF_INDEX,
        );
    }
    if (view.ordered_active_layer.?.slots.isSet(layer.order)) {
        std.log.err("Order of Layer already in use: {any}", .{layer});
        @panic("message: []const u8");
    }

    view.ordered_active_layer.?.set(layer.order, layer.id);
}

fn removeLayerMapping(layer: *Layer) void {
    var view: *View = View.get(layer.view_id);
    if (view.ordered_active_layer) |l| {
        l.reset(layer.order);
    }
}
