const std = @import("std");
const firefly = @import("../firefly.zig");

const EventDispatch = firefly.utils.EventDispatch;
const ComponentEvent = firefly.api.ComponentEvent;
const AssetComponent = firefly.api.AssetComponent;
const Asset = firefly.api.Asset;
const Shader = firefly.graphics.Shader;
const BitSet = firefly.utils.BitSet;
const Component = firefly.api.Component;
const String = firefly.utils.String;
const RenderTextureBinding = firefly.api.RenderTextureBinding;
const Vector2f = firefly.utils.Vector2f;
const PosF = firefly.utils.PosF;
const RectF = firefly.utils.RectF;
const Color = firefly.utils.Color;
const BlendMode = firefly.api.BlendMode;
const DynArray = firefly.utils.DynArray;
const DynIndexArray = firefly.utils.DynIndexArray;
const Projection = firefly.api.Projection;
const EComponent = firefly.api.EComponent;
const RenderEvent = firefly.api.RenderEvent;
const System = firefly.api.System;
const ViewRenderEvent = firefly.api.ViewRenderEvent;
const Index = firefly.utils.Index;
const Float = firefly.utils.Float;
const BindingId = firefly.api.BindingId;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

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
    EComponent.registerEntityComponent(EView);
    EComponent.registerEntityComponent(ETransform);
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

    pub fn match(view1_id: ?Index, view2_id: ?Index, layer1_id: ?Index, layer2_id: ?Index) bool {
        if (view1_id) |v1| {
            if (view2_id) |v2|
                return v1 != v2;
        }
        if (layer1_id) |l1| {
            if (layer2_id) |l2|
                return l1 != l2;
        }
        return true;
    }

    pub fn new() ViewLayerMapping {
        return ViewLayerMapping{
            .undef_mapping = BitSet.new(firefly.api.ALLOC) catch unreachable,
            .mapping = DynArray(DynArray(BitSet)).new(firefly.api.ALLOC) catch unreachable,
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

    pub fn addWithEView(self: *ViewLayerMapping, view: ?*EView, id: Index) void {
        if (view) |v| {
            self.add(v.view_id, v.layer_id, id);
        } else {
            self.add(null, null, id);
        }
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

    pub fn removeWithEView(self: *ViewLayerMapping, view: ?*EView, id: Index) void {
        if (view) |v| {
            self.remove(v.view_id, v.layer_id, id);
        } else {
            self.remove(null, null, id);
        }
    }

    pub fn remove(self: *ViewLayerMapping, view_id: ?Index, layer_id: ?Index, id: Index) void {
        getIdMapping(self, view_id, layer_id).setValue(id, false);
    }

    fn getIdMapping(self: *ViewLayerMapping, view_id: ?Index, layer_id: ?Index) *BitSet {
        if (view_id) |vid| {
            var layer_mapping: *DynArray(BitSet) = getLayerMapping(self, vid);
            const l_id = layer_id orelse 0;
            if (!layer_mapping.exists(l_id)) {
                return layer_mapping.set(BitSet.new(firefly.api.ALLOC) catch unreachable, l_id);
            }
            return layer_mapping.get(l_id).?;
        }

        return &self.undef_mapping;
    }

    fn getLayerMapping(self: *ViewLayerMapping, view_id: Index) *DynArray(BitSet) {
        if (!self.mapping.exists(view_id)) {
            return self.mapping.set(
                DynArray(BitSet).new(firefly.api.ALLOC) catch unreachable,
                view_id,
            );
        }
        return self.mapping.get(view_id).?;
    }
};

//////////////////////////////////////////////////////////////
//// View Event Handling
//////////////////////////////////////////////////////////////

pub const ViewChangeListener = *const fn (ViewChangeEvent) void;
pub const ViewChangeEvent = struct {
    pub const Type = enum {
        NONE,
        POSITION,
        PROJECTION,
        SIZE,
    };

    event_type: Type = .NONE,
    view_id: ?Index = null,
};

//////////////////////////////////////////////////////////////
//// View Component
//////////////////////////////////////////////////////////////

// TODO ViewChangeEvent

pub const View = struct {
    pub usingnamespace Component.Trait(View, .{
        .name = "View",
        .control = true,
    });

    // struct fields
    id: Index = UNDEF_INDEX,
    name: ?String = null,
    //order: u8 = undefined,

    position: PosF,
    pivot: ?PosF,
    scale: ?PosF,
    rotation: ?Float,
    tint_color: ?Color,
    blend_mode: ?BlendMode,
    projection: Projection = .{},

    render_texture_binding: ?RenderTextureBinding = null,
    shader_binding: ?BindingId = null,
    ordered_active_layer: ?DynArray(Index) = null,
    /// If not null, this view is rendered to another view instead of the screen
    target_view_id: ?Index = null,

    pub var screen_projection: Projection = .{};
    pub var screen_shader_binding: ?BindingId = null;

    var active_views_to_fbo: DynIndexArray = undefined;
    var active_views_to_screen: DynIndexArray = undefined;
    var eventDispatch: EventDispatch(ViewChangeEvent) = undefined;

    pub fn componentTypeInit() !void {
        eventDispatch = EventDispatch(ViewChangeEvent).new(firefly.api.COMPONENT_ALLOC);
        active_views_to_fbo = DynIndexArray.init(firefly.api.COMPONENT_ALLOC, 10);
        active_views_to_screen = DynIndexArray.init(firefly.api.COMPONENT_ALLOC, 10);
        Layer.subscribe(onLayerAction);
    }

    pub fn componentTypeDeinit() void {
        Layer.unsubscribe(onLayerAction);
        active_views_to_fbo.deinit();
        active_views_to_fbo = undefined;
        active_views_to_screen.deinit();
        active_views_to_screen = undefined;
        eventDispatch.deinit();
        eventDispatch = undefined;
    }

    pub fn setFullscreen() void {
        firefly.api.window.toggleFullscreen();
        // adapt view to full screen
        //const window = firefly.api.window.getWindowData();
        std.debug.print("screen: {d} {d} \n", .{
            firefly.api.window.getMonitorWidth(1),
            firefly.api.window.getMonitorHeight(1),
        });
    }

    pub fn moveProjection(
        self: *View,
        vec: Vector2f,
        pixel_perfect: bool,
        snap_bounds: ?RectF,
    ) void {
        self.projection.position += vec;
        if (pixel_perfect)
            self.projection.position = @ceil(self.projection.position);
        if (snap_bounds) |sb|
            self.snapToBounds(sb);

        eventDispatch.notify(.{
            .event_type = ViewChangeEvent.Type.PROJECTION,
            .view_id = self.id,
        });
    }

    pub fn adjustProjection(
        self: *View,
        vec: Vector2f,
        pixel_perfect: bool,
        snap_bounds: ?RectF,
    ) void {
        self.projection.position = vec;
        if (pixel_perfect)
            self.projection.position = @ceil(self.projection.position);
        if (snap_bounds) |sb|
            self.snapToBounds(sb);

        eventDispatch.notify(.{
            .event_type = ViewChangeEvent.Type.PROJECTION,
            .view_id = self.id,
        });
    }

    inline fn adjustPixelPerfect(self: *View) void {
        self.projection.position = @ceil(self.projection.position);
    }

    inline fn snapToBounds(self: *View, bounds: RectF) void {
        const _bounds: RectF = .{
            bounds[0] * self.projection.zoom,
            bounds[1] * self.projection.zoom,
            bounds[2] * self.projection.zoom,
            bounds[3] * self.projection.zoom,
        };
        self.projection.position[0] = @max(self.projection.position[0], _bounds[0]);
        self.projection.position[1] = @max(self.projection.position[1], _bounds[1]);
        self.projection.position[0] = @min(self.projection.position[0], _bounds[0] + _bounds[2] - self.projection.width);
        self.projection.position[1] = @min(self.projection.position[1], _bounds[1] + _bounds[3] - self.projection.height);
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
            addViewMapping(view);
            view.render_texture_binding = firefly.api.rendering.createRenderTexture(&view.projection);
        } else {
            removeViewMapping(view);
            if (view.render_texture_binding) |b| {
                firefly.api.rendering.disposeRenderTexture(b.id);
                view.render_texture_binding = null;
            }
        }
    }

    fn onLayerAction(event: Component.ComponentEvent) void {
        switch (event.event_type) {
            ComponentEvent.Type.ACTIVATED => addLayerMapping(Layer.byId(event.c_id.?)),
            ComponentEvent.Type.DEACTIVATING => removeLayerMapping(Layer.byId(event.c_id.?)),
            else => {},
        }
    }

    fn addViewMapping(view: *View) void {
        if (view.target_view_id) |_| {
            _ = active_views_to_fbo.add(view.id);
        } else {
            _ = active_views_to_screen.add(view.id);
        }

        // Note: For now none screen target mapping is flat and if a view
        //       that has a target view itself ist a target of another view
        //       that might not be rendered correctly, depending on the order
        //       of active_views_to_fbo
        // TODO sort active_views_to_fbo in the manner that views that are targets
        //      itself are later in the list and first are the once that are no targets.
    }

    fn removeViewMapping(view: *View) void {
        active_views_to_fbo.removeFirst(view.id);
        active_views_to_screen.removeFirst(view.id);
    }

    fn addLayerMapping(layer: *const Layer) void {
        var view: *View = View.byId(layer.view_id);
        if (view.ordered_active_layer == null) {
            view.ordered_active_layer = DynArray(Index).newWithRegisterSize(
                firefly.api.COMPONENT_ALLOC,
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
        const shader_asset: *AssetComponent = AssetComponent.byId(id);
        if (Asset(Shader).resourceById(shader_asset.resource_id)) |res|
            self.shader_binding = res.binding;
    }

    pub fn withShaderByName(self: *Layer, name: String) void {
        if (AssetComponent.byName(name)) |a| {
            if (Asset(Shader).resourceById(a.resource_id)) |res|
                self.shader_binding = res.binding;
        }
    }
};

//////////////////////////////////////////////////////////////
//// EView Entity Component
//////////////////////////////////////////////////////////////

pub const EView = struct {
    pub usingnamespace EComponent.Trait(EView, "EView");

    id: Index = UNDEF_INDEX,
    view_id: Index = UNDEF_INDEX,
    layer_id: ?Index = null,

    pub fn setViewByName(self: *ETransform, view_name: String) void {
        self.view_id = View.byName(view_name).id;
    }

    pub fn setLayerByName(self: *ETransform, layer_name: String) void {
        self.layer_id = Layer.byName(layer_name).id;
    }

    pub fn destruct(self: *EView) void {
        self.layer_id = null;
        self.view_id = UNDEF_INDEX;
    }
};

//////////////////////////////////////////////////////////////
//// ETransform Entity Component
//////////////////////////////////////////////////////////////

pub const ETransform = struct {
    pub usingnamespace EComponent.Trait(ETransform, "ETransform");

    id: Index = UNDEF_INDEX,
    position: PosF = .{ 0, 0 },
    pivot: ?PosF = null,
    scale: ?PosF = null,
    rotation: ?Float = null,

    pub fn move(self: *ETransform, x: Float, y: Float) void {
        self.position[0] += x;
        self.position[1] += y;
    }

    pub fn destruct(self: *ETransform) void {
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
            return &ETransform.byId(id).?.position[0];
        }
        pub fn YPos(id: Index) *Float {
            return &ETransform.byId(id).?.position[1];
        }
        pub fn XScale(id: Index) *Float {
            return &ETransform.byId(id).?.getScale()[1];
        }
        pub fn YScale(id: Index) *Float {
            return &ETransform.byId(id).?.getScale()[1];
        }
        pub fn Rotation(id: Index) *Float {
            return ETransform.byId(id).?.getRotation();
        }
    };
};

//////////////////////////////////////////////////////////////
//// ViewRenderer System
//////////////////////////////////////////////////////////////

pub const ViewRenderer = struct {
    var VIEW_RENDER_EVENT = ViewRenderEvent{};
    pub const render_order = 0;

    pub fn render(event: RenderEvent) void {
        if (event.type != firefly.api.RenderEventType.RENDER)
            return;

        if (View.active_views_to_screen.items.len == 0) {
            // in this case we have only the screen, no FBO
            if (View.screen_shader_binding) |sb|
                firefly.api.rendering.setActiveShader(sb);

            firefly.api.rendering.startRendering(null, &View.screen_projection);
            VIEW_RENDER_EVENT.view_id = null;
            VIEW_RENDER_EVENT.layer_id = null;
            VIEW_RENDER_EVENT.projection = &View.screen_projection;
            firefly.api.renderView(VIEW_RENDER_EVENT);
            firefly.api.rendering.endRendering();
        } else {
            // 1. render objects to all FBOs
            var next = View.nextActiveId(0);
            while (next) |id| {
                renderToFBO(View.byId(id));
                next = View.nextActiveId(id + 1);
            }

            // 2. render all FBO that has not screen as target but other FBO
            for (0..View.active_views_to_fbo.size_pointer) |id| {
                const source_view: *View = View.byId(id);
                if (source_view.target_view_id) |tid| {
                    const target_view: *View = View.byId(tid);
                    if (target_view.render_texture_binding) |b| {
                        firefly.api.rendering.startRendering(b.id, &target_view.projection);
                        firefly.api.rendering.renderTexture(
                            source_view.render_texture_binding.?.id,
                            source_view.position,
                            source_view.pivot,
                            source_view.scale,
                            source_view.rotation,
                            source_view.tint_color,
                            source_view.blend_mode,
                        );
                        firefly.api.rendering.endRendering();
                    }
                }
            }

            // 3. render all FBO to screen that has screen as target
            // set shader if needed
            if (View.screen_shader_binding) |sb|
                firefly.api.rendering.setActiveShader(sb);
            // activate render to screen
            firefly.api.rendering.startRendering(null, &View.screen_projection);
            // render all FBO as textures to the screen
            for (0..View.active_views_to_screen.size_pointer) |id| {
                const view: *View = View.byId(id);
                if (view.render_texture_binding) |b| {
                    firefly.api.rendering.renderTexture(
                        b.id,
                        view.position,
                        view.pivot,
                        view.scale,
                        view.rotation,
                        view.tint_color,
                        view.blend_mode,
                    );
                }
            }
            // end rendering to screen
            firefly.api.rendering.endRendering();
        }
    }

    fn renderToFBO(view: *View) void {
        if (view.render_texture_binding) |b| {
            // start rendering to view (FBO)
            // set shader...
            if (view.shader_binding) |sb|
                firefly.api.rendering.setActiveShader(sb);
            // activate FBO
            firefly.api.rendering.startRendering(b.id, &view.projection);
            // emit render events for all layers of the view in order to render to FBO
            if (view.ordered_active_layer != null) {
                var it = view.ordered_active_layer.?.slots.nextSetBit(0);
                while (it) |layer_id| {
                    const layer: *const Layer = Layer.byId(layer_id);
                    // apply layer shader to render engine if set
                    if (layer.shader_binding) |sb|
                        firefly.api.rendering.setActiveShader(sb);
                    // add layer offset to render engine
                    if (layer.offset) |o|
                        firefly.api.rendering.addOffset(o);
                    // send layer render event
                    VIEW_RENDER_EVENT.view_id = view.id;
                    VIEW_RENDER_EVENT.layer_id = layer_id;
                    VIEW_RENDER_EVENT.projection = &view.projection;
                    firefly.api.renderView(VIEW_RENDER_EVENT);
                    // remove layer offset form render engine
                    if (layer.offset) |o|
                        firefly.api.rendering.addOffset(o * @as(Vector2f, @splat(-1)));
                    it = view.ordered_active_layer.?.slots.nextSetBit(layer_id + 1);
                }
            } else {
                // we have no layer so only one render call for this view
                VIEW_RENDER_EVENT.view_id = view.id;
                VIEW_RENDER_EVENT.layer_id = null;
                firefly.api.renderView(VIEW_RENDER_EVENT);
            }
            // end rendering to FBO
            firefly.api.rendering.endRendering();
        }
    }
};
