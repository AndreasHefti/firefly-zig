const std = @import("std");
const ArrayList = std.ArrayList;

const graphics = @import("graphics.zig");
const api = graphics.api;
const utils = api.utils;

const EventDispatch = utils.EventDispatch;
const BitSet = utils.BitSet;
const Component = api.Component;
const ComponentListener = Component.ComponentListener;
const ComponentEvent = Component.ComponentEvent;
const Aspect = utils.Aspect;
const String = utils.String;
const TransformData = api.TransformData;
const RenderData = api.RenderData;
const RenderTextureData = api.RenderTextureData;
const Vector2f = utils.Vector2f;
const DynArray = utils.DynArray;
const ActionType = Component.ActionType;
const Projection = api.Projection;
const Entity = api.Entity;
const EntityComponent = api.EntityComponent;
const RenderEvent = api.RenderEvent;
const RenderEventSubscription = api.RenderEventSubscription;
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
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    Component.API.registerComponent(Layer);
    Component.API.registerComponent(View);
    EntityComponent.registerEntityComponent(ETransform);
    EntityComponent.registerEntityComponent(EMultiplier);
    ViewRenderer.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    View.deinit();
    ViewRenderer.deinit();
}

pub const ViewRenderEvent = struct {
    view_id: Index,
    layer_id: Index,
};
pub const ViewRenderListener = *const fn (ViewRenderEvent) void;

pub fn subscribeViewRendering(listener: ViewRenderListener) void {
    ViewRenderer.VIEW_RENDER_EVENT_DISPATCHER.register(listener);
}

pub fn subscribeViewRenderingAt(index: usize, listener: ViewRenderListener) void {
    ViewRenderer.VIEW_RENDER_EVENT_DISPATCHER.registerInsert(index, listener);
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
            .undef_mapping = BitSet.init(api.ALLOC) catch unreachable,
            .mapping = DynArray(DynArray(BitSet)).init(api.ALLOC, null) catch unreachable,
        };
    }

    pub fn deinit(self: *ViewLayerMapping) void {
        var it = self.mapping.iterator();
        while (it.next()) |next| {
            var itt = next.iterator();
            while (itt.next()) |n| {
                n.deinit();
            }
            next.deinit();
        }
        self.mapping.deinit();
        self.undef_mapping.deinit();
    }

    pub fn add(self: *ViewLayerMapping, view_id: Index, layer_id: Index, id: Index) void {
        getIdMapping(self, view_id, layer_id).set(id);
    }

    pub fn get(self: *ViewLayerMapping, view_id: Index, layer_id: Index) ?*BitSet {
        if (view_id == UNDEF_INDEX) {
            return &self.undef_mapping;
        }
        if (self.mapping.getIfExists(view_id)) |lmap| {
            if (layer_id != UNDEF_INDEX) {
                return lmap.getIfExists(layer_id);
            } else {
                return lmap.getIfExists(0);
            }
        }
        return null;
    }

    pub fn remove(self: *ViewLayerMapping, view_id: Index, layer_id: Index, id: Index) void {
        getIdMapping(self, view_id, layer_id).setValue(id, false);
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
            layer_mapping.set(BitSet.init(api.ALLOC) catch unreachable, l_id);
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
    pub usingnamespace Component.API.Adapter(View, .{ .name = "View" });

    // struct fields
    id: Index = UNDEF_INDEX,
    name: String = NO_NAME,
    /// Rendering order. 0 means screen, every above means render texture that is rendered in ascending order
    camera_position: Vector2f = Vector2f{ 0, 0 },
    order: u8 = undefined,
    render_data: RenderData = RenderData{},
    transform: TransformData = TransformData{},
    projection: Projection = Projection{},
    render_texture: RenderTextureData = RenderTextureData{},
    shader_binding: BindingId = NO_BINDING,
    ordered_active_layer: ?DynArray(Index) = null,

    pub var screen_projection: Projection = Projection{};
    pub var screen_shader_binding: BindingId = NO_BINDING;
    pub var ordered_active_views: DynArray(Index) = undefined;

    pub fn init() !void {
        ordered_active_views = try DynArray(Index).initWithRegisterSize(
            api.COMPONENT_ALLOC,
            10,
            UNDEF_INDEX,
        );
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
        var view: *View = View.get(id);
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

        api.RENDERING_API.createRenderTexture(&view.render_texture);
    }

    fn deactivate(view: *View) void {
        // dispose render texture for this view and cancel binding
        if (view.order == 0)
            return; // screen, no render texture dispose needed

        removeViewMapping(view);
        api.RENDERING_API.disposeRenderTexture(&view.render_texture);
    }

    fn onLayerAction(event: Component.ComponentEvent) void {
        switch (event.event_type) {
            ActionType.ACTIVATED => addLayerMapping(Layer.byId(event.c_id)),
            ActionType.DEACTIVATING => removeLayerMapping(Layer.byId(event.c_id)),
            else => {},
        }
    }

    fn addViewMapping(view: *View) void {
        if (ordered_active_views.slots.isSet(view.order)) {
            std.log.err("Order of view already in use: {any}", .{view});
            @panic("View order mismatch");
        }

        ordered_active_views.set(view.order, view.id);
    }

    fn removeViewMapping(view: *View) void {
        if (!ordered_active_views.slots.isSet(view.order))
            return;

        // clear layer mapping
        if (view.ordered_active_layer) |*l| {
            l.clear();
        }

        // clear view mapping
        ordered_active_views.reset(view.order);
    }

    fn addLayerMapping(layer: *const Layer) void {
        var view: *View = View.get(layer.view_id);
        if (view.ordered_active_layer == null) {
            view.ordered_active_layer = DynArray(Index).initWithRegisterSize(
                api.COMPONENT_ALLOC,
                10,
                UNDEF_INDEX,
            ) catch unreachable;
        }
        if (view.ordered_active_layer.?.slots.isSet(layer.order)) {
            std.log.err("Order of Layer already in use: {any}", .{layer});
            @panic("message: []const u8");
        }

        view.ordered_active_layer.?.set(layer.order, layer.id);
    }

    fn removeLayerMapping(layer: *const Layer) void {
        var view: *View = View.get(layer.view_id);
        if (view.ordered_active_layer) |*l| {
            l.reset(layer.order);
        }
    }
};

//////////////////////////////////////////////////////////////
//// Layer Component
//////////////////////////////////////////////////////////////

pub const Layer = struct {
    pub usingnamespace Component.API.Adapter(Layer, .{ .name = "Layer" });

    // struct fields
    id: Index = UNDEF_INDEX,
    name: String = NO_NAME,
    offset: Vector2f = Vector2f{ 0, 0 },
    order: u8 = 0,
    view_id: Index = UNDEF_INDEX,
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
    pub usingnamespace EntityComponent.API.Adapter(@This(), "ETransform");

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

    pub fn destruct(self: *ETransform) void {
        self.layer_id = UNDEF_INDEX;
        self.view_id = UNDEF_INDEX;
        self.transform.clear();
    }

    pub fn withData(self: ETransform, data: TransformData) ETransform {
        var copy = self;
        copy.transform = data;
        return copy;
    }
};

//////////////////////////////////////////////////////////////////////////
//// EMultiplier Entity position multiplier
//////////////////////////////////////////////////////////////////////////

pub const EMultiplier = struct {
    pub usingnamespace EntityComponent.API.Adapter(@This(), "EMultiplier");
    pub const NULL_POS_ENTRY = Vector2f{};

    id: Index = UNDEF_INDEX,
    positions: DynArray(Vector2f) = undefined,

    pub fn construct(self: *EMultiplier) void {
        self.positions = DynArray(Vector2f).init(
            api.COMPONENT_ALLOC,
            NULL_POS_ENTRY,
        ) catch unreachable;
    }

    pub fn destruct(self: *EMultiplier) void {
        self.positions.deinit();
        self.positions = undefined;
    }
};

//////////////////////////////////////////////////////////////
//// ViewRenderer System
//////////////////////////////////////////////////////////////

const ViewRenderer = struct {
    var VIEW_RENDER_EVENT_DISPATCHER: EventDispatch(ViewRenderEvent) = undefined;
    var VIEW_RENDER_EVENT = ViewRenderEvent{
        .view_id = UNDEF_INDEX,
        .layer_id = UNDEF_INDEX,
    };

    var re_subscription: RenderEventSubscription(ViewRenderer) = undefined;

    fn init() void {
        VIEW_RENDER_EVENT_DISPATCHER = EventDispatch(ViewRenderEvent).init(api.ALLOC);
        _ = System.new(System{
            .name = "ViewRenderer",
            .info = "Emits ViewRenderEvent in order of active Views and its Layers",
            .onActivation = onActivation,
        });
        System.activateByName("ViewRenderer", true);
    }

    fn deinit() void {
        System.activateByName("ViewRenderer", false);
        System.disposeByName("ViewRenderer");
        VIEW_RENDER_EVENT_DISPATCHER.deinit();
    }

    fn onActivation(active: bool) void {
        if (active) {
            re_subscription = RenderEventSubscription(ViewRenderer)
                .of(render)
                .subscribe();
        } else {
            _ = re_subscription.unsubscribe();
            re_subscription = undefined;
        }
    }

    fn render(event: RenderEvent) void {
        if (event.type != api.RenderEventType.RENDER)
            return;

        if (View.ordered_active_views.slots.nextSetBit(0) == null) {
            // in this case we have only the screen, no FBO
            if (View.screen_shader_binding != NO_BINDING)
                api.RENDERING_API.setActiveShader(View.screen_shader_binding);

            api.RENDERING_API.startRendering(null, &View.screen_projection);
            VIEW_RENDER_EVENT.view_id = UNDEF_INDEX;
            VIEW_RENDER_EVENT.layer_id = UNDEF_INDEX;
            VIEW_RENDER_EVENT_DISPATCHER.notify(VIEW_RENDER_EVENT);
            api.RENDERING_API.endRendering();
        } else {
            // render to all FBO
            var view_it = View.ordered_active_views.iterator();
            while (view_it.next()) |view_id| {
                renderView(View.byId(view_id.*));
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
                var view: *const View = View.byId(view_id.*);
                api.RENDERING_API.renderTexture(
                    view.render_texture.binding,
                    &view.transform,
                    &view.render_data,
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
        if (view.ordered_active_layer != null) {
            var it = view.ordered_active_layer.?.slots.nextSetBit(0);
            while (it) |layer_id| {
                var layer: *const Layer = Layer.byId(layer_id);
                // apply layer shader to render engine if set
                if (layer.shader_binding != NO_BINDING)
                    api.RENDERING_API.setActiveShader(layer.shader_binding);
                // add layer offset to render engine
                api.RENDERING_API.addOffset(layer.offset);
                // send layer render event
                VIEW_RENDER_EVENT.view_id = view.id;
                VIEW_RENDER_EVENT.layer_id = layer_id;
                VIEW_RENDER_EVENT_DISPATCHER.notify(VIEW_RENDER_EVENT);
                // remove layer offset form render engine
                api.RENDERING_API.removeOffset(layer.offset);
                it = view.ordered_active_layer.?.slots.nextSetBit(layer_id + 1);
            }
        } else {
            // we have no layer so only one render call for this view
            VIEW_RENDER_EVENT.view_id = view.id;
            VIEW_RENDER_EVENT.layer_id = UNDEF_INDEX;
            VIEW_RENDER_EVENT_DISPATCHER.notify(VIEW_RENDER_EVENT);
        }
        // end rendering to FBO
        api.RENDERING_API.endRendering();
    }
};
