const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const graphics = inari.firefly.graphics;

const ArrayList = std.ArrayList;
const EventDispatch = utils.EventDispatch;
const BitSet = utils.BitSet;
const Component = api.Component;
const ComponentListener = Component.ComponentListener;
const ComponentEvent = Component.ComponentEvent;
const Aspect = utils.Aspect;
const String = utils.String;
const RenderTextureBinding = api.RenderTextureBinding;
const Vector2f = utils.Vector2f;
const PosF = utils.PosF;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const DynArray = utils.DynArray;
const ActionType = Component.ActionType;
const Projection = api.Projection;
const Entity = api.Entity;
const EComponent = api.EComponent;
const RenderEvent = api.RenderEvent;
const System = api.System;
const ViewRenderEvent = api.ViewRenderEvent;
const ViewRenderListener = api.ViewRenderListener;
const Index = utils.Index;
const Float = utils.Float;
const BindingId = api.BindingId;
const UNDEF_INDEX = utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// global
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(Layer);
    Component.registerComponent(View);
    EComponent.registerEntityComponent(ETransform);
    EComponent.registerEntityComponent(EMultiplier);
    System(ViewRenderer).createSystem(
        "ViewRenderer",
        "Emits ViewRenderEvent in order of active Views and its Layers",
        true,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    System(ViewRenderer).disposeSystem();
}

//////////////////////////////////////////////////////////////
//// View-Layer-Mapping
//////////////////////////////////////////////////////////////

pub const ViewLayerMapping = struct {
    undef_mapping: BitSet,
    mapping: DynArray(DynArray(BitSet)),

    pub fn new() ViewLayerMapping {
        return ViewLayerMapping{
            .undef_mapping = BitSet.new(api.ALLOC) catch unreachable,
            .mapping = DynArray(DynArray(BitSet)).new(api.ALLOC) catch unreachable,
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

    pub fn add(self: *ViewLayerMapping, view_id: ?Index, layer_id: ?Index, id: Index) void {
        getIdMapping(self, view_id, layer_id).set(id);
    }

    pub fn get(self: *ViewLayerMapping, view_id: ?Index, layer_id: ?Index) ?*BitSet {
        if (view_id) |vid| {
            if (self.mapping.get(vid)) |l_map| {
                if (l_map.get(layer_id orelse 0)) |m| return m;
            }
            return null;
        }
        return &self.undef_mapping;
    }

    pub fn remove(self: *ViewLayerMapping, view_id: ?Index, layer_id: ?Index, id: Index) void {
        getIdMapping(self, view_id, layer_id).setValue(id, false);
    }

    fn getIdMapping(self: *ViewLayerMapping, view_id: ?Index, layer_id: ?Index) *BitSet {
        if (view_id) |vid| {
            var layer_mapping: *DynArray(BitSet) = getLayerMapping(self, vid);
            var l_id = layer_id orelse 0;
            if (!layer_mapping.exists(l_id)) {
                return layer_mapping.set(BitSet.new(api.ALLOC) catch unreachable, l_id);
            }
            return layer_mapping.get(l_id).?;
        }

        return &self.undef_mapping;
    }

    fn getLayerMapping(self: *ViewLayerMapping, view_id: Index) *DynArray(BitSet) {
        if (!self.mapping.exists(view_id)) {
            return self.mapping.set(
                DynArray(BitSet).new(api.ALLOC) catch unreachable,
                view_id,
            );
        }
        return self.mapping.get(view_id).?;
    }
};

//////////////////////////////////////////////////////////////
//// View Component
//////////////////////////////////////////////////////////////

pub const View = struct {
    pub usingnamespace Component.Trait(View, .{ .name = "View" });

    // struct fields
    id: Index = UNDEF_INDEX,
    name: ?String = null,
    /// Rendering order. 0 means screen, every above means render texture that is rendered in ascending order
    order: u8 = undefined,
    width: c_int,
    height: c_int,

    position: PosF,
    pivot: ?PosF,
    scale: ?PosF,
    rotation: ?Float,
    tint_color: ?Color,
    blend_mode: ?BlendMode,
    projection: ?Projection = Projection{},

    render_texture_binding: ?RenderTextureBinding = null,
    shader_binding: ?BindingId = null,
    ordered_active_layer: ?DynArray(Index) = null,

    pub var screen_projection: ?Projection = null;
    pub var screen_shader_binding: ?BindingId = null;
    pub var ordered_active_views: DynArray(Index) = undefined;

    pub fn componentTypeInit() !void {
        ordered_active_views = try DynArray(Index).newWithRegisterSize(
            api.COMPONENT_ALLOC,
            10,
        );
        Layer.subscribe(onLayerAction);
    }

    pub fn componentTypeDeinit() void {
        Layer.unsubscribe(onLayerAction);
        ordered_active_views.deinit();
    }

    pub fn withLayer(self: *View, layer: Layer) *View {
        Layer.newAnd(layer).view_ref = self.id;
        return self;
    }

    pub fn withLayerByName(self: *View, name: String) *View {
        if (Layer.byName(name)) |l| l.view_ref = self.id;
        return self;
    }

    pub fn activation(view: *View, active: bool) void {
        if (active) {
            if (view.order == 0)
                return; // screen, no render texture load needed

            addViewMapping(view);
            view.render_texture_binding = api.rendering.createRenderTexture(view.width, view.height);
        } else {
            // dispose render texture for this view and cancel binding
            if (view.order == 0)
                return; // screen, no render texture dispose needed

            removeViewMapping(view);
            if (view.render_texture_binding) |b| {
                api.rendering.disposeRenderTexture(b.id);
                view.render_texture_binding = null;
            }
        }
    }

    fn onLayerAction(event: Component.ComponentEvent) void {
        switch (event.event_type) {
            ActionType.ACTIVATED => addLayerMapping(Layer.byId(event.c_id.?)),
            ActionType.DEACTIVATING => removeLayerMapping(Layer.byId(event.c_id.?)),
            else => {},
        }
    }

    fn addViewMapping(view: *View) void {
        if (ordered_active_views.slots.isSet(view.order)) {
            std.log.err("Order of view already in use: {any}", .{view});
            @panic("View order mismatch");
        }

        _ = ordered_active_views.set(view.order, view.id);
    }

    fn removeViewMapping(view: *View) void {
        if (!ordered_active_views.slots.isSet(view.order))
            return;

        // clear layer mapping
        if (view.ordered_active_layer) |*l| {
            l.clear();
        }

        // clear view mapping
        ordered_active_views.delete(view.order);
    }

    fn addLayerMapping(layer: *const Layer) void {
        var view: *View = View.byId(layer.view_id);
        if (view.ordered_active_layer == null) {
            view.ordered_active_layer = DynArray(Index).newWithRegisterSize(
                api.COMPONENT_ALLOC,
                10,
            ) catch unreachable;
        }
        if (view.ordered_active_layer.?.slots.isSet(layer.order)) {
            std.log.err("Order of Layer already in use: {any}", .{layer});
            @panic("message: []const u8");
        }

        _ = view.ordered_active_layer.?.set(layer.order, layer.id);
    }

    fn removeLayerMapping(layer: *const Layer) void {
        var view: *View = View.byId(layer.view_id);
        if (view.ordered_active_layer) |*l| {
            l.delete(layer.order);
        }
    }
};

//////////////////////////////////////////////////////////////
//// Layer Component
//////////////////////////////////////////////////////////////

pub const Layer = struct {
    pub usingnamespace Component.Trait(Layer, .{ .name = "Layer" });

    // struct fields
    id: Index = UNDEF_INDEX,
    name: ?String = null,
    offset: ?Vector2f = null,
    order: u8 = 0,
    view_id: Index,
    shader_binding: ?BindingId = null,

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
    pub usingnamespace EComponent.Trait(ETransform, "ETransform");

    id: Index = UNDEF_INDEX,
    position: PosF = .{ 0, 0 },
    pivot: ?PosF = null,
    scale: ?PosF = null,
    rotation: ?Float = null,
    view_id: ?Index = null,
    layer_id: ?Index = null,

    pub fn setViewByName(self: *ETransform, view_name: String) void {
        self.view_id = View.byName(view_name).id;
    }

    pub fn setLayerByName(self: *ETransform, layer_name: String) void {
        self.layer_id = Layer.byName(layer_name).id;
    }

    pub fn destruct(self: *ETransform) void {
        self.layer_id = null;
        self.view_id = null;
        self.position = .{ 0, 0 };
        self.pivot = null;
        self.scale = null;
        self.rotation = null;
    }

    fn getScale(self: *ETransform) *PosF {
        if (self.scale == null) {
            self.scale = .{ 1, 1 };
        }
        return self.scale.?;
    }

    fn getRotation(self: *ETransform) *Float {
        if (self.rotation == null) {
            self.rotation = 0;
        }
        return &self.rotation.?;
    }

    pub const Property = struct {
        pub fn XPos(id: Index) *Float {
            return &ETransform.byId(id).position[0];
        }
        pub fn YPos(id: Index) *Float {
            return &ETransform.byId(id).position[1];
        }
        pub fn XScale(id: Index) *Float {
            return &ETransform.byId(id).getScale()[1];
        }
        pub fn YScale(id: Index) *Float {
            return &ETransform.byId(id).getScale()[1];
        }
        pub fn Rotation(id: Index) *Float {
            return ETransform.byId(id).getRotation();
        }
    };
};

//////////////////////////////////////////////////////////////////////////
//// EMultiplier Entity position multiplier
//////////////////////////////////////////////////////////////////////////

pub const EMultiplier = struct {
    pub usingnamespace EComponent.Trait(@This(), "EMultiplier");
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

pub const ViewRenderer = struct {
    var VIEW_RENDER_EVENT = ViewRenderEvent{};
    pub const render_order = 0;

    pub fn render(event: RenderEvent) void {
        if (event.type != api.RenderEventType.RENDER)
            return;

        if (View.ordered_active_views.slots.nextSetBit(0) == null) {
            // in this case we have only the screen, no FBO
            if (View.screen_shader_binding) |sb|
                api.rendering.setActiveShader(sb);

            api.rendering.startRendering(null, View.screen_projection);
            VIEW_RENDER_EVENT.view_id = null;
            VIEW_RENDER_EVENT.layer_id = null;
            api.renderView(VIEW_RENDER_EVENT);
            api.rendering.endRendering();
        } else {
            // render to all FBO
            var next = View.ordered_active_views.slots.nextSetBit(0);
            while (next) |id| {
                renderView(View.byId(id));
                next = View.ordered_active_views.slots.nextSetBit(id + 1);
            }
            // rendering all FBO to screen
            next = View.ordered_active_views.slots.nextSetBit(0);
            // set shader if needed
            if (View.screen_shader_binding) |sb|
                api.rendering.setActiveShader(sb);
            // activate render to screen
            api.rendering.startRendering(null, View.screen_projection);
            // render all FBO as textures to the screen
            while (next) |id| {
                var view: *View = View.byId(id);
                if (view.render_texture_binding) |b| {
                    api.rendering.renderTexture(
                        b.id,
                        &view.position,
                        &view.pivot,
                        &view.scale,
                        &view.rotation,
                        &view.tint_color,
                        view.blend_mode,
                    );
                }
                next = View.ordered_active_views.slots.nextSetBit(id + 1);
            }
            // end rendering to screen
            api.rendering.endRendering();
        }
    }

    fn renderView(view: *View) void {
        if (view.render_texture_binding) |b| {
            // start rendering to view (FBO)
            // set shader...
            if (view.shader_binding) |sb|
                api.rendering.setActiveShader(sb);
            // activate FBO
            api.rendering.startRendering(b.id, view.projection);
            // emit render events for all layers of the view in order to render to FBO
            if (view.ordered_active_layer != null) {
                var it = view.ordered_active_layer.?.slots.nextSetBit(0);
                while (it) |layer_id| {
                    var layer: *const Layer = Layer.byId(layer_id);
                    // apply layer shader to render engine if set
                    if (layer.shader_binding) |sb|
                        api.rendering.setActiveShader(sb);
                    // add layer offset to render engine
                    if (layer.offset) |o|
                        api.rendering.addOffset(o);
                    // send layer render event
                    VIEW_RENDER_EVENT.view_id = view.id;
                    VIEW_RENDER_EVENT.layer_id = layer_id;
                    api.renderView(VIEW_RENDER_EVENT);
                    // remove layer offset form render engine
                    if (layer.offset) |o|
                        api.rendering.addOffset(o * @as(Vector2f, @splat(-1)));
                    it = view.ordered_active_layer.?.slots.nextSetBit(layer_id + 1);
                }
            } else {
                // we have no layer so only one render call for this view
                VIEW_RENDER_EVENT.view_id = view.id;
                VIEW_RENDER_EVENT.layer_id = null;
                api.renderView(VIEW_RENDER_EVENT);
            }
            // end rendering to FBO
            api.rendering.endRendering();
        }
    }
};
