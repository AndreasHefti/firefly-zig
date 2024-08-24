const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;
const graphics = firefly.graphics;

const String = utils.String;
const Vector2f = utils.Vector2f;
const PosF = utils.PosF;
const RectF = utils.RectF;
const CInt = utils.CInt;
const Color = utils.Color;
const BlendMode = api.BlendMode;
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

    ViewRenderer.init();
    api.Component.registerComponent(Layer);
    api.Component.registerComponent(View);
    api.Component.registerComponent(Scene);
    api.EComponent.registerEntityComponent(EView);
    api.EComponent.registerEntityComponent(ETransform);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// View-Layer-Mapping
//////////////////////////////////////////////////////////////

pub const ViewLayerMapping = struct {
    undef_mapping: utils.BitSet,
    mapping: utils.DynArray(utils.DynArray(utils.BitSet)),

    pub fn match(view1_id: ?Index, view2_id: ?Index, layer1_id: ?Index, layer2_id: ?Index) bool {
        const v1 = view1_id orelse 0;
        const v2 = view2_id orelse 0;
        const l1 = layer1_id orelse 0;
        const l2 = layer2_id orelse 0;
        return v1 == v2 and l1 == l2;
    }

    pub fn new() ViewLayerMapping {
        return ViewLayerMapping{
            .undef_mapping = utils.BitSet.new(firefly.api.ALLOC),
            .mapping = utils.DynArray(utils.DynArray(utils.BitSet)).new(firefly.api.ALLOC),
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

    pub fn get(self: *ViewLayerMapping, view_id: ?Index, layer_id: ?Index) ?*utils.BitSet {
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

    fn getIdMapping(self: *ViewLayerMapping, view_id: ?Index, layer_id: ?Index) *utils.BitSet {
        if (view_id) |vid| {
            var layer_mapping: *utils.DynArray(utils.BitSet) = getLayerMapping(self, vid);
            const l_id = layer_id orelse 0;
            if (!layer_mapping.exists(l_id)) {
                return layer_mapping.set(utils.BitSet.new(firefly.api.ALLOC), l_id);
            }
            return layer_mapping.get(l_id).?;
        }

        return &self.undef_mapping;
    }

    fn getLayerMapping(self: *ViewLayerMapping, view_id: Index) *utils.DynArray(utils.BitSet) {
        if (!self.mapping.exists(view_id)) {
            return self.mapping.set(
                utils.DynArray(utils.BitSet).new(firefly.api.ALLOC),
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
//// View api.Component
//////////////////////////////////////////////////////////////

pub const View = struct {
    pub usingnamespace api.Component.Trait(View, .{
        .name = "View",
        .control = true,
    });

    // struct fields
    id: Index = UNDEF_INDEX,
    name: ?String = null,
    //order: u8 = undefined,

    position: PosF,
    pivot: ?PosF = .{ 0, 0 },
    scale: ?PosF = .{ 1, 1 },
    rotation: ?Float = 0,
    tint_color: ?Color = .{ 255, 255, 255, 255 },
    blend_mode: ?BlendMode = BlendMode.ALPHA,
    projection: api.Projection = .{},

    render_texture_binding: ?api.RenderTextureBinding = null,
    shader_binding: ?BindingId = null,
    ordered_active_layer: ?utils.DynArray(Index) = null,
    /// If not null, this view is rendered to another view instead of the screen
    target_view_id: ?Index = null,

    pub var screen_projection: api.Projection = .{};
    pub var screen_shader_binding: ?BindingId = null;

    var active_views_to_fbo: utils.DynIndexArray = undefined;
    var active_views_to_screen: utils.DynIndexArray = undefined;
    var eventDispatch: utils.EventDispatch(ViewChangeEvent) = undefined;

    pub fn componentTypeInit() !void {
        eventDispatch = utils.EventDispatch(ViewChangeEvent).new(firefly.api.COMPONENT_ALLOC);
        active_views_to_fbo = utils.DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 10);
        active_views_to_screen = utils.DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 10);
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

    pub fn destruct(self: *View) void {
        if (self.ordered_active_layer) |*l|
            l.deinit();
        self.ordered_active_layer = undefined;
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
        //std.debug.print("bounds : {d}\n", .{bounds});
        const _bounds: RectF = .{
            bounds[0] * self.projection.zoom * self.scale.?[0],
            bounds[1] * self.projection.zoom * self.scale.?[1],
            bounds[2] * self.projection.zoom * self.scale.?[0],
            bounds[3] * self.projection.zoom * self.scale.?[1],
        };
        //std.debug.print("_bounds : {d}\n", .{_bounds});

        self.projection.position[0] = @min(self.projection.position[0], _bounds[0] + _bounds[2] - self.projection.width);
        self.projection.position[1] = @min(self.projection.position[1], _bounds[1] + _bounds[3] - self.projection.height);
        self.projection.position[0] = @max(self.projection.position[0], _bounds[0]);
        self.projection.position[1] = @max(self.projection.position[1], _bounds[1]);
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

    fn onLayerAction(event: api.ComponentEvent) void {
        switch (event.event_type) {
            .ACTIVATED => addLayerMapping(Layer.byId(event.c_id.?)),
            .DEACTIVATING => removeLayerMapping(Layer.byId(event.c_id.?)),
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
            view.ordered_active_layer = utils.DynArray(Index).newWithRegisterSize(
                firefly.api.COMPONENT_ALLOC,
                10,
            );
        }
        if (view.ordered_active_layer.?.slots.isSet(layer.order)) {
            std.log.err("Order of Layer already in use: {any}", .{layer});
            @panic("Order of Layer already in use");
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
//// Layer api.Component
//////////////////////////////////////////////////////////////

pub const Layer = struct {
    pub usingnamespace api.Component.Trait(Layer, .{ .name = "Layer" });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    view_id: Index,
    order: usize = 0,
    offset: ?Vector2f = null,
    parallax: ?Vector2f = null,
    shader_binding: ?BindingId = null,

    pub fn setViewByName(self: *Layer, view_name: String) void {
        self.view_id = View.byName(view_name).id;
    }

    pub fn withShader(self: *Layer, id: Index) void {
        self.shader_binding = graphics.Shader.byId(id).binding;
    }

    pub fn withShaderByName(self: *Layer, name: String) void {
        if (graphics.Shader.byName(name)) |shader|
            self.shader_binding = shader.binding;
    }
};

//////////////////////////////////////////////////////////////
//// EView Entity api.Component
//////////////////////////////////////////////////////////////

pub const EView = struct {
    pub usingnamespace api.EComponent.Trait(EView, "EView");

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
//// ETransform Entity api.Component
//////////////////////////////////////////////////////////////

pub const ETransform = struct {
    pub usingnamespace api.EComponent.Trait(ETransform, "ETransform");

    id: Index = UNDEF_INDEX,
    position: PosF = .{ 0, 0 },
    pivot: ?PosF = null,
    scale: ?PosF = null,
    rotation: ?Float = null,

    pub fn move(self: *ETransform, x: Float, y: Float) void {
        self.position[0] += x;
        self.position[1] += y;
    }

    pub fn moveCInt(self: *ETransform, x: CInt, y: CInt) void {
        self.position[0] += utils.cint_float(x);
        self.position[1] += utils.cint_float(y);
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
//// Scene Component
//////////////////////////////////////////////////////////////

pub const Scene = struct {
    pub usingnamespace api.Component.Trait(Scene, .{ .name = "Scene" });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    delete_after_run: bool = false,

    scheduler: ?*api.UpdateScheduler = null,

    init_function: ?api.RegFunction = null,
    dispose_function: ?api.RegFunction = null,
    update_action: api.ActionFunction,
    callback: ?api.ActionCallback = null,
    registry: api.CallReg = api.CallReg{},
    attributes: api.Attributes = undefined,

    _loaded: bool = false,

    pub fn componentTypeInit() !void {
        firefly.api.subscribeUpdate(update);
    }

    pub fn componentTypeDeinit() void {
        firefly.api.unsubscribeUpdate(update);
    }

    pub fn construct(self: *Scene) void {
        self.attributes = api.Attributes.new();
        self.registry.caller_id = self.id;
    }

    pub fn destruct(self: *Scene) void {
        self.attributes.deinit();
        self.attributes = undefined;
    }

    pub fn withUpdateAction(self: *Scene, action: api.ActionFunction) *Scene {
        self.update_action = action;
        return self;
    }

    pub fn withCallback(self: *Scene, callback: api.ActionCallback) *Scene {
        self.callback = callback;
        return self;
    }

    pub fn withScheduler(self: *Scene, scheduler: api.UpdateScheduler) *Scene {
        self.scheduler = scheduler;
        return self;
    }

    pub fn activation(self: *Scene, active: bool) void {
        if (active) {
            defer self._loaded = true;
            if (self._loaded)
                return;

            if (self.init_function) |f|
                f(self.registry);
        } else {
            stop(self);
            defer self._loaded = false;
            if (!self._loaded)
                return;

            if (self.dispose_function) |f|
                f(self.registry);
        }
    }

    pub fn run(self: *Scene) void {
        Scene.activateById(self.id, true);
    }

    pub fn stop(self: *Scene) void {
        Scene.activateById(self.id, false);
    }

    pub fn reset(self: *Scene) void {
        activation(self, false);
        activation(self, true);
    }

    pub fn resetAndRun(self: *Scene) void {
        reset();
        run(self);
    }

    fn update(_: api.UpdateEvent) void {
        var next = Scene.nextActiveId(0);
        while (next) |i| {
            next = Scene.nextActiveId(i + 1);
            var scene = Scene.byId(i);
            if (scene.scheduler) |s| {
                if (!s.needs_update)
                    continue;
            }

            const result = scene.update_action(scene.registry);
            if (result == .Running)
                continue;

            scene.stop();
            if (scene.callback) |call|
                call(scene.registry, result);

            if (scene.delete_after_run)
                Scene.disposeById(scene.id);
        }
    }
};

//////////////////////////////////////////////////////////////
//// ViewRenderer api.System
//////////////////////////////////////////////////////////////

pub const ViewRenderer = struct {
    pub usingnamespace api.SystemTrait(ViewRenderer);
    var VIEW_RENDER_EVENT = api.ViewRenderEvent{};
    pub const render_order = 0;

    pub fn render(event: api.RenderEvent) void {
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
                VIEW_RENDER_EVENT.projection = &view.projection;
                firefly.api.renderView(VIEW_RENDER_EVENT);
            }
            // end rendering to FBO
            firefly.api.rendering.endRendering();
        }
    }
};
