const std = @import("std");
const ArrayList = std.ArrayList;

const graphics = @import("graphics.zig");
const api = graphics.api;
const utils = graphics.utils;

const BitSet = utils.bitset.BitSet;
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
const Entity = api.Entity;
const RenderEvent = api.RenderEvent;
const System = api.System;

const Index = api.Index;
const BindingId = api.BindingId;
const UNDEF_INDEX = api.UNDEF_INDEX;
const NO_BINDING = api.NO_BINDING;
const NO_NAME = api.utils.NO_NAME;

//////////////////////////////////////////////////////////////
//// global
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    // init ViewRenderer
    ViewRenderer.system_id = System.new(ViewRenderer.sys).id;
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit ViewRenderer
    System.activateById(ViewRenderer.system_id, false);
    System.disposeById(ViewRenderer.system_id);
    ViewRenderer.system_id = UNDEF_INDEX;
}

pub const ViewRenderEvent = struct {
    view_id: Index,
    layer_id: Index,
};
pub const ViewRenderListener = *const fn (*const ViewRenderEvent) void;

pub fn subscribeViewRendering(listener: ViewRenderListener) void {
    ViewRenderer.VIEW_RENDER_EVENT_DISPATCHER.register(listener);
}

pub fn subscribeViewRenderingAt(index: usize, listener: ViewRenderListener) void {
    ViewRenderer.VIEW_RENDER_EVENT_DISPATCHER.register(index, listener);
}

pub fn unsubscribeViewRendering(listener: ViewRenderListener) void {
    ViewRenderer.VIEW_RENDER_EVENT_DISPATCHER.unregister(listener);
}

//////////////////////////////////////////////////////////////
//// View-Layer-Mapping
//////////////////////////////////////////////////////////////

pub const ViewLayerMapping = struct {
    undef_mapping: BitSet,
    mapping: DynArray(DynArray(BitSet)),

    pub fn new() ViewLayerMapping {
        return ViewLayerMapping{
            .undef_mapping = BitSet.init(api.ALLOC),
            .mapping = DynArray(DynArray(BitSet)).init(api.ALLOC, null),
        };
    }

    pub fn deinit(self: *ViewLayerMapping) void {
        var it = self.mapping.iterator();
        while (it.next()) |*next| {
            var itt = next.iterator();
            while (itt.next()) |*n| {
                n.deinit();
            }
            next.deinit();
        }
        self.mapping.deinit();
    }

    pub fn add(self: *ViewLayerMapping, view_id: Index, layer_id: Index, id: Index) void {
        getIdMapping(self, view_id, layer_id).append(id);
    }

    pub fn get(self: *ViewLayerMapping, view_id: Index, layer_id: Index) ?*BitSet {
        if (view_id == UNDEF_INDEX) {}
        if (self.mapping.getIfExists(view_id)) |lmap| {
            if (layer_id != UNDEF_INDEX) {
                return lmap.getIfExists(layer_id);
            } else {
                return lmap.getIfExists(0);
            }
        }
    }

    pub fn remove(self: *ViewLayerMapping, view_id: Index, layer_id: Index, id: Index) void {
        getIdMapping(self, view_id, layer_id).re;
    }

    pub fn clear(self: *ViewLayerMapping) void {
        var it = self.mapping.iterator();
        while (it.next()) |*next| {
            var itt = next.iterator();
            while (itt.next()) |*n| {
                n.clearAndFree();
            }
            next.clear();
        }
        self.mapping.clear();
    }

    fn getIdMapping(self: *ViewLayerMapping, view_id: Index, layer_id: Index) *BitSet {
        if (view_id == UNDEF_INDEX) {
            return &self.undef_mapping;
        }
        var layer_mapping: *DynArray(BitSet) = getLayerMapping(self, view_id);
        var l_id = if (layer_id == UNDEF_INDEX) 0 else layer_id;
        if (!layer_mapping.exists(l_id)) {
            layer_mapping.set(BitSet.init(api.ALLOC), l_id);
        }
        return layer_mapping.get(l_id);
    }

    fn getLayerMapping(self: *ViewLayerMapping, view_id: Index) *DynArray(BitSet) {
        if (!self.mapping.exists(view_id)) {
            self.mapping.set(
                DynArray(BitSet).init(api.ALLOC, null) catch unreachable,
                view_id,
            );
        }
        return self.mapping.get(view_id);
    }
};

//////////////////////////////////////////////////////////////
//// View Component
//////////////////////////////////////////////////////////////

pub const View = struct {
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
    shader_binding: BindingId = NO_BINDING,
    ordered_active_layer: ?*DynArray(Index) = null,

    pub var screen_projection: Projection = Projection{};
    pub var screen_shader_binding: BindingId = NO_BINDING;
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
};

//////////////////////////////////////////////////////////////
//// Layer Component
//////////////////////////////////////////////////////////////

pub const Layer = struct {
    // component type fields
    pub const NULL_VALUE = Layer{};
    pub const COMPONENT_NAME = "Layer";
    pub const pool = Component.ComponentPool(Layer);
    // component type pool references
    pub var type_aspect: *Aspect = undefined;
    pub var new: *const fn (Layer) *Layer = undefined;
    pub var exists: *const fn (Index) bool = undefined;
    pub var existsName: *const fn (String) bool = undefined;
    pub var get: *const fn (Index) *Layer = undefined;
    pub var byId: *const fn (Index) *const Layer = undefined;
    pub var byName: *const fn (String) *const Layer = undefined;
    pub var activateById: *const fn (Index, bool) void = undefined;
    pub var activateByName: *const fn (String, bool) void = undefined;
    pub var disposeById: *const fn (Index) void = undefined;
    pub var disposeByName: *const fn (String) void = undefined;
    pub var subscribe: *const fn (Component.EventListener) void = undefined;
    pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

    // struct fields
    id: Index = UNDEF_INDEX,
    name: String = NO_NAME,
    position: Vec2f = Vec2f{},
    order: u8 = 0,
    view_id: Index,
    shader_binding: api.BindingId = api.NO_BINDING,

    pub fn setViewByName(self: *Layer, view_name: String) void {
        self.view_id = View.byName(view_name).id;
    }

    pub fn withShader(self: *Layer, id: Index) void {
        const shader_asset: *api.Asset = api.Asset.byId(id);
        self.shader_binding = graphics.ShaderAsset.getResource(shader_asset.resource_id).binding;
    }

    pub fn withShaderByName(self: *Layer, name: String) void {
        const shader_asset: *api.Asset = api.Asset.byIdName(name);
        self.shader_binding = graphics.ShaderAsset.getResource(shader_asset.resource_id).binding;
    }
};

//////////////////////////////////////////////////////////////
//// ETransform Entity
//////////////////////////////////////////////////////////////

pub const ETransform = struct {
    // component type fields
    pub const NULL_VALUE = ETransform{};
    pub const COMPONENT_NAME = "ETransform";
    pub const pool = Entity.EntityComponentPool(ETransform);
    // component type pool references
    pub var type_aspect: *Aspect = undefined;
    pub var get: *const fn (Index) *ETransform = undefined;
    pub var byId: *const fn (Index) *const ETransform = undefined;

    id: Index = UNDEF_INDEX,
    transform: TransformData = TransformData{},
    view_id: Index = UNDEF_INDEX,
    layer_id: Index = UNDEF_INDEX,

    pub fn setViewByName(self: *ETransform, view_name: String) void {
        self.view_id = View.byName(view_name).id;
    }

    pub fn setLayerByName(self: *ETransform, layer_name: String) void {
        self.layer_id = Layer.byName(layer_name).id;
    }
};

//////////////////////////////////////////////////////////////
//// ViewRenderer System
//////////////////////////////////////////////////////////////

const ViewRenderer = struct {
    const sys = System{
        .name = "ViewRenderer",
        .info =
        \\View Renderer emits ViewRenderEvent in order of active Views and its activeLayers
        \\Individual or specialized renderer systems can subscribe to this events and render its parts
        ,
        .onActivation = onActivation,
    };
    var system_id = UNDEF_INDEX;
    var VIEW_RENDER_EVENT_DISPATCHER: utils.EventDispatch(*const ViewRenderEvent) = undefined;
    var VIEW_RENDER_EVENT = ViewRenderEvent{
        .view_id = UNDEF_INDEX,
        .layer_id = UNDEF_INDEX,
    };

    fn onActivation(active: bool) void {
        if (active) {
            api.subscribeRender(render);
        } else {
            api.unsubscribeRender(render);
        }
    }

    fn render(event: *const RenderEvent) void {
        if (event.type != api.RenderEventType.RENDER)
            return;

        if (View.ordered_active_views.slots.nextSetBit(0) == null) {
            // in this case we have only the screen, no FBO
            if (View.screen_shader_binding != NO_BINDING)
                api.RENDERING_API.setActiveShader(View.screen_shader_binding);

            api.RENDERING_API.startRendering(null, &View.screen_projection);
            VIEW_RENDER_EVENT.view_id = UNDEF_INDEX;
            VIEW_RENDER_EVENT.layer_id = UNDEF_INDEX;
            VIEW_RENDER_EVENT_DISPATCHER.notify(&VIEW_RENDER_EVENT);
            api.RENDERING_API.endRendering();
        } else {
            // render to all FBO
            var view_it = View.ordered_active_views.iterator();
            while (view_it.next()) |view_id| {
                renderView(View.byId(view_id));
            }

            // rendering all FBO to screen
            view_it = View.ordered_active_views.iterator();
            // set shader if needed
            if (View.screen_shader_binding != NO_BINDING)
                api.RENDERING_API.setActiveShader(View.screen_shader_binding);
            // activate render to screen
            api.RENDERING_API.startRendering(null, &View.screen_projection);
            // render all FBO as textures to the screen
            while (view_it.next()) |view_id| {
                var view: *View = View.byId(view_id);
                api.RENDERING_API.renderTexture(
                    view.render_texture.binding,
                    view.transform,
                    view.render_data,
                    null,
                );
            }
            // end rendering to screen
            api.RENDERING_API.endRendering();
        }
    }

    fn renderView(view: *const View) void {
        // start rendering to view (FBO)
        // set shader...
        if (view.shader_binding != NO_BINDING)
            api.RENDERING_API.setActiveShader(view.shader_binding);
        // activate FBO
        api.RENDERING_API.startRendering(view.render_texture.binding, &view.projection);
        // emit render events for all layers of the view in order to render to FBO
        if (view.ordered_active_layer) |layers| {
            var layer_it = layers.iterator();
            while (layer_it.next()) |layer_id| {
                VIEW_RENDER_EVENT.view_id = view.id;
                VIEW_RENDER_EVENT.layer_id = layer_id;
                VIEW_RENDER_EVENT_DISPATCHER.notify(&VIEW_RENDER_EVENT);
            }
        } else {
            // we have no layer so only one render call for this view
            VIEW_RENDER_EVENT.view_id = view.id;
            VIEW_RENDER_EVENT.layer_id = UNDEF_INDEX;
            VIEW_RENDER_EVENT_DISPATCHER.notify(&VIEW_RENDER_EVENT);
        }
        // end rendering to FBO
        api.RENDERING_API.endRendering();
    }
};
