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

    api.System.register(ViewRenderer);

    // register components
    api.Component.register(Layer, "Layer");
    api.Component.register(View, "View");
    api.Component.register(Scene, "Scene");

    // register entity components
    api.Entity.registerComponent(EView, "EView");
    api.Entity.registerComponent(ETransform, "ETransform");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    WindowResolutionAdaption.deinit();
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
    pub const Component = api.Component.Mixin(View);
    pub const Naming = api.Component.NameMappingMixin(View);
    pub const Activation = api.Component.ActivationMixin(View);
    pub const Subscription = api.Component.SubscriptionMixin(View);
    pub const Control = api.Component.ControlMixin(View);

    /// View Component identifier
    id: Index = UNDEF_INDEX,
    /// View Component name
    name: ?String = null,

    position: PosF,
    pivot: PosF = .{ 0, 0 },
    scale: PosF = .{ 1, 1 },
    rotation: Float = 0,
    tint_color: ?Color = .{ 255, 255, 255, 255 },
    blend_mode: ?BlendMode = BlendMode.ALPHA,
    projection: api.Projection = .{},

    /// If not null, this view is a texture to render on and will later be draw to screen or another texture
    render_texture_binding: ?api.RenderTextureBinding = null,
    /// Shader binding of shader that will be applied for rendering to the view
    view_render_shader: ?BindingId = null,
    /// Shader binding of the shader that will be applied when the view gets drawn to screen or to another texture
    texture_render_shader: ?BindingId = null,
    /// If not null, this view is rendered to another view instead of the screen
    target_view_id: ?Index = null,
    /// This indicates if the view is a direct render target or not.
    /// Usually if you have a view that acts only as target for other views and has no primer rendering on it
    /// this can be set to false. If false, no sprite or shape or other render data will be rendered to this view.
    is_render_target: bool = true,

    /// Sorted list of active layer ids of this View. This is maintained by the system, do not change.
    ordered_active_layer: ?utils.DynArray(Index) = null,

    // Overall screen projection used when rendering to screen
    pub var screen_projection: api.Projection = .{};
    // Overall screen shader used when rendering to screen and no other shader has been defined
    pub var screen_shader_binding: ?BindingId = null;

    var fbo_target_mapping: utils.DynArray(utils.BitSet) = undefined;
    var screen_target_mapping: utils.BitSet = undefined;
    // var active_views_to_fbo: utils.DynIndexArray = undefined;
    // var active_views_to_screen: utils.DynIndexArray = undefined;
    var eventDispatch: utils.EventDispatch(ViewChangeEvent) = undefined;

    pub fn componentTypeInit() !void {
        eventDispatch = utils.EventDispatch(ViewChangeEvent).new(firefly.api.COMPONENT_ALLOC);
        fbo_target_mapping = utils.DynArray(utils.BitSet).newWithRegisterSize(api.COMPONENT_ALLOC, 10);
        screen_target_mapping = utils.BitSet.new(api.COMPONENT_ALLOC);
        Layer.Subscription.subscribe(onLayerAction);
    }

    pub fn componentTypeDeinit() void {
        Layer.Subscription.unsubscribe(onLayerAction);
        var next = fbo_target_mapping.slots.nextSetBit(0);
        while (next) |i| {
            next = fbo_target_mapping.slots.nextSetBit(i + 1);
            if (fbo_target_mapping.get(i)) |s| s.deinit();
        }
        fbo_target_mapping.deinit();
        fbo_target_mapping = undefined;
        screen_target_mapping.deinit();
        screen_target_mapping = undefined;
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
        api.Logger.info("Set fullscreen, screen: {d} {d}", .{
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

        self.projection.position[0] = @min(self.projection.position[0], _bounds[0] + _bounds[2] - self.projection.width);
        self.projection.position[1] = @min(self.projection.position[1], _bounds[1] + _bounds[3] - self.projection.height);
        self.projection.position[0] = @max(self.projection.position[0], _bounds[0]);
        self.projection.position[1] = @max(self.projection.position[1], _bounds[1]);
    }

    pub fn activation(view: *View, active: bool) void {
        if (active) {
            addViewMapping(view);
            view.render_texture_binding = firefly.api.rendering.createRenderTexture(&view.projection) catch |err| {
                api.Logger.errWith("Failed to load RenderTexture for View: {any}", .{view}, err);
                return;
            };
        } else {
            removeViewMapping(view);
            if (view.render_texture_binding) |b| {
                firefly.api.rendering.disposeRenderTexture(b.id);
                view.render_texture_binding = null;
            }
        }
    }

    pub fn transform_world_position(self: *View, window_position: Vector2f, apply_zoom: bool) Vector2f {
        return if (apply_zoom)
            (window_position - self.position) / @as(Vector2f, @splat(self.projection.zoom))
        else
            (window_position - self.position);
    }

    pub fn onLayerAction(event: api.ComponentEvent) void {
        switch (event.event_type) {
            .ACTIVATED => addLayerMapping(Layer.Component.byId(event.c_id.?)),
            .DEACTIVATING => removeLayerMapping(Layer.Component.byId(event.c_id.?)),
            else => {},
        }
    }

    fn addViewMapping(view: *View) void {
        if (view.target_view_id) |target_id| {
            if (!fbo_target_mapping.slots.isSet(target_id))
                _ = fbo_target_mapping.set(utils.BitSet.new(api.COMPONENT_ALLOC), target_id);

            if (fbo_target_mapping.get(target_id)) |map|
                map.set(view.id);
        } else {
            _ = screen_target_mapping.set(view.id);
        }
    }

    fn removeViewMapping(view: *View) void {
        if (view.target_view_id) |target_id| {
            if (fbo_target_mapping.get(target_id)) |map|
                map.setValue(view.id, false);
        }

        screen_target_mapping.setValue(view.id, false);
    }

    fn addLayerMapping(layer: *const Layer) void {
        var view: *View = View.Component.byId(layer.view_id);
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
        var view: *View = Component.byId(layer.view_id);
        if (view.ordered_active_layer) |*l| {
            l.delete(layer.order);
        }
    }
};

//////////////////////////////////////////////////////////////
//// Layer api.Component
//////////////////////////////////////////////////////////////

pub const Layer = struct {
    pub const Component = api.Component.Mixin(Layer);
    pub const Naming = api.Component.NameMappingMixin(Layer);
    pub const Activation = api.Component.ActivationMixin(Layer);
    pub const Subscription = api.Component.SubscriptionMixin(Layer);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    view_id: Index,
    order: usize = 0,
    offset: ?Vector2f = null,
    parallax: ?Vector2f = null,
    shader_binding: ?BindingId = null,

    pub fn setViewByName(self: *Layer, view_name: String) void {
        self.view_id = View.Naming.byName(view_name).id;
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
    pub const Component = api.EntityComponentMixin(EView);

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
    pub const Component = api.EntityComponentMixin(ETransform);

    id: Index = UNDEF_INDEX,
    position: PosF = .{ 0, 0 },
    pivot: ?PosF = null,
    scale: ?PosF = null,
    rotation: ?Float = null,

    pub fn add(entity_id: Index, c: ETransform) void {
        Component.new(entity_id, c);
    }

    pub fn move(self: *ETransform, x: Float, y: Float) void {
        self.position[0] += x;
        self.position[1] += y;
    }

    pub fn moveTo(self: *ETransform, x: Float, y: Float) void {
        self.position[0] = x;
        self.position[1] = y;
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
            return &ETransform.Component.byId(id).position[0];
        }
        pub fn YPos(id: Index) *Float {
            return &ETransform.Component.byId(id).position[1];
        }
        pub fn XScale(id: Index) *Float {
            return &ETransform.Component.byId(id).getScale()[1];
        }
        pub fn YScale(id: Index) *Float {
            return &ETransform.Component.byId(id).getScale()[1];
        }
        pub fn Rotation(id: Index) *Float {
            return ETransform.Component.byId(id).getRotation();
        }
    };
};

//////////////////////////////////////////////////////////////
//// Scene Component
//////////////////////////////////////////////////////////////

pub const Scene = struct {
    pub const Component = api.Component.Mixin(Scene);
    pub const Naming = api.Component.NameMappingMixin(Scene);
    pub const Activation = api.Component.ActivationMixin(Scene);
    pub const Subscription = api.Component.SubscriptionMixin(Scene);
    pub const CallContext = api.Component.CallContextMixin(Scene);
    pub const init_attributes = true;

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    delete_after_run: bool = false,
    scheduler: ?*api.FrameScheduler = null,

    init_function: ?api.CallFunction = null,
    dispose_function: ?api.CallFunction = null,
    update_action: api.CallFunction,
    callback: ?api.CallFunction = null,
    call_context: api.CallContext = undefined,

    _active: bool = false,

    pub fn componentTypeInit() !void {
        firefly.api.subscribeUpdate(update);
    }

    pub fn componentTypeDeinit() void {
        firefly.api.unsubscribeUpdate(update);
    }

    pub fn withUpdateAction(self: *Scene, action: api.CallFunction) *Scene {
        self.update_action = action;
        return self;
    }

    pub fn withCallback(self: *Scene, callback: api.CallFunction) *Scene {
        self.callback = callback;
        return self;
    }

    pub fn withScheduler(self: *Scene, scheduler: api.UpdateScheduler) *Scene {
        self.scheduler = scheduler;
        return self;
    }

    pub fn activation(self: *Scene, active: bool) void {
        if (active) {
            defer self._active = true;
            if (self._active)
                return;

            if (self.init_function) |f|
                f(&self.call_context);
        } else {
            defer self._active = false;
            if (!self._active)
                return;

            if (self.dispose_function) |f|
                f(&self.call_context);
        }
    }

    pub fn run(self: *Scene) void {
        Scene.Activation.activate(self.id);
    }

    pub fn stop(self: *Scene) void {
        Scene.Activation.deactivate(self.id);
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
        var next = Activation.nextId(0);
        while (next) |i| {
            next = Activation.nextId(i + 1);
            var scene = Component.byId(i);
            if (scene.scheduler) |s| {
                if (!s.needsUpdate())
                    continue;
            }

            scene.update_action(&scene.call_context);
            if (scene.call_context.result == .Running)
                continue;

            scene.stop();
            if (scene.callback) |call|
                call(&scene.call_context);

            if (scene.delete_after_run)
                Component.dispose(scene.id);
        }
    }
};

//////////////////////////////////////////////////////////////
//// ViewRenderer System
//////////////////////////////////////////////////////////////

pub const ViewRenderer = struct {
    pub const System = api.SystemMixin(ViewRenderer);
    var VIEW_RENDER_EVENT = api.ViewRenderEvent{};

    pub fn render(event: api.RenderEvent) void {
        if (event.type != firefly.api.RenderEventType.RENDER)
            return;

        if (View.screen_shader_binding) |sb|
            firefly.api.rendering.putShaderStack(sb);

        if (View.screen_target_mapping.nextSetBit(0) == null) {

            // In this case we have only the screen, no FBO. Start render to screen
            firefly.api.rendering.startRendering(null, &View.screen_projection);

            // Assemble view render event and notify all renderer to render to the screen
            VIEW_RENDER_EVENT.view_id = null;
            VIEW_RENDER_EVENT.layer_id = null;
            VIEW_RENDER_EVENT.projection = &View.screen_projection;
            firefly.api.renderView(VIEW_RENDER_EVENT);

            firefly.api.rendering.endRendering();
        } else {

            // In this case we have a render pipeline where we first render all to FBOs and than all FBOs to screen.
            // 1. render objects to all FBOs that are direct render targets
            var next = View.Activation.nextId(0);
            while (next) |id| {
                next = View.Activation.nextId(id + 1);
                const view = View.Component.byId(id);
                if (view.is_render_target)
                    renderToFBO(view);
            }

            // 2. render all FBO that has not screen as target but another FBO
            next = View.fbo_target_mapping.slots.nextSetBit(0);
            while (next) |i| {
                next = View.fbo_target_mapping.slots.nextSetBit(i + 1);
                const target_view: *View = View.Component.byId(i);
                var sources = View.fbo_target_mapping.get(i).?;

                // start render to target view
                if (target_view.render_texture_binding) |b| {
                    firefly.api.rendering.startRendering(b.id, &target_view.projection);

                    var next_source = sources.nextSetBit(0);
                    while (next_source) |s_id| {
                        next_source = sources.nextSetBit(s_id + 1);
                        const source_view: *View = View.Component.byId(s_id);

                        // set shader of source View for view texture rendering
                        if (source_view.texture_render_shader) |sb|
                            firefly.api.rendering.putShaderStack(sb);

                        firefly.api.rendering.renderTexture(
                            source_view.render_texture_binding.?.id,
                            source_view.position,
                            source_view.pivot,
                            source_view.scale,
                            source_view.rotation,
                            source_view.tint_color,
                            source_view.blend_mode,
                            source_view.projection.flip_x,
                            source_view.projection.flip_y,
                        );

                        //rest shader if needed
                        if (source_view.texture_render_shader != null)
                            firefly.api.rendering.popShaderStack();
                    }

                    firefly.api.rendering.endRendering();
                }
            }

            // 3. render all FBO to screen that has screen as target
            // activate render to screen
            firefly.api.rendering.startRendering(null, &View.screen_projection);
            // render all FBO as textures to the screen
            next = View.screen_target_mapping.nextSetBit(0);
            while (next) |i| {
                next = View.screen_target_mapping.nextSetBit(i + 1);
                const view: *View = View.Component.byId(i);
                if (view.render_texture_binding) |b| {

                    // set shader for view texture rendering
                    if (view.texture_render_shader) |sb|
                        firefly.api.rendering.putShaderStack(sb);

                    firefly.api.rendering.renderTexture(
                        b.id,
                        view.position,
                        view.pivot,
                        view.scale,
                        view.rotation,
                        view.tint_color,
                        view.blend_mode,
                        view.projection.flip_x,
                        view.projection.flip_y,
                    );

                    //rest shader if needed
                    if (view.texture_render_shader != null)
                        firefly.api.rendering.popShaderStack();
                }
            }

            // reset shader
            if (View.screen_shader_binding != null)
                firefly.api.rendering.popShaderStack();

            // end rendering to screen
            firefly.api.rendering.endRendering();
        }

        if (View.screen_shader_binding != null)
            firefly.api.rendering.popShaderStack();
    }

    fn renderToFBO(view: *View) void {
        // Given View represents an FBO to render to
        if (view.render_texture_binding) |b| {

            // start rendering to View (FBO)
            // set default shader for render to this FBO if available
            if (view.view_render_shader) |sb|
                firefly.api.rendering.putShaderStack(sb);

            // Activate rendering to this FBO
            firefly.api.rendering.startRendering(b.id, &view.projection);

            // Emit render events for all layers of the view in order to render to FBO
            if (view.ordered_active_layer != null) {
                var it = view.ordered_active_layer.?.slots.nextSetBit(0);
                while (it) |layer_id| {
                    it = view.ordered_active_layer.?.slots.nextSetBit(layer_id + 1);
                    const layer: *const Layer = Layer.Component.byId(layer_id);

                    // Apply layer shader to render engine if set
                    if (layer.shader_binding) |sb|
                        firefly.api.rendering.putShaderStack(sb);

                    // Add layer offset to render engine
                    if (layer.offset) |o|
                        firefly.api.rendering.addOffset(o);

                    // Assemble and send layer render event
                    VIEW_RENDER_EVENT.view_id = view.id;
                    VIEW_RENDER_EVENT.layer_id = layer_id;
                    VIEW_RENDER_EVENT.projection = &view.projection;
                    firefly.api.renderView(VIEW_RENDER_EVENT);

                    // remove layer offset form render engine
                    if (layer.offset) |o|
                        firefly.api.rendering.addOffset(o * @as(Vector2f, @splat(-1)));

                    // remove layer shader to render engine if set
                    if (layer.shader_binding != null)
                        firefly.api.rendering.popShaderStack();
                }
            } else {
                // we have no layer so only one render call for this view
                VIEW_RENDER_EVENT.view_id = view.id;
                VIEW_RENDER_EVENT.layer_id = null;
                VIEW_RENDER_EVENT.projection = &view.projection;
                firefly.api.renderView(VIEW_RENDER_EVENT);
            }
            // reset shader
            if (view.view_render_shader != null)
                firefly.api.rendering.popShaderStack();
            // end rendering to FBO
            firefly.api.rendering.endRendering();
        }
    }
};

//////////////////////////////////////////////////////////////
////  Window Resolution Adaption
//////////////////////////////////////////////////////////////

pub const WindowResolutionChangeListener = *const fn (view_id: Index) void;
pub const WindowResolutionAdaption = struct {
    var adaption_initialized: bool = false;

    var center_camera: bool = true;
    var main_view_id: Index = undefined;
    var _game_width: Float = 0;
    var _game_height: Float = 0;
    var _game_screen_ratio: Float = 0;

    var _listener: ?WindowResolutionChangeListener = null;

    pub fn init(main_view_name: String, width: usize, height: usize, listener: ?WindowResolutionChangeListener) void {
        _game_width = utils.usize_f32(width);
        _game_height = utils.usize_f32(height);
        _game_screen_ratio = _game_height / _game_width;
        main_view_id = View.Naming.byName(main_view_name).?.id;
        api.subscribeUpdate(updateResizing);
        adaption_initialized = true;
        _listener = listener;
    }

    pub fn setWindowResolutionChangeListener(listener: ?WindowResolutionChangeListener) void {
        _listener = listener;
    }

    fn deinit() void {
        if (adaption_initialized)
            api.unsubscribeUpdate(updateResizing);
        adaption_initialized = false;
    }

    pub fn adapt() void {
        _update();
    }

    fn updateResizing(_: api.UpdateEvent) void {
        if (firefly.api.window.isWindowResized())
            _update();
    }

    fn _update() void {
        // adapt main view to actual window in relation to the original proportions
        const width = utils.cint_float(firefly.api.window.getScreenWidth());
        const height = utils.cint_float(firefly.api.window.getScreenHeight());
        if (width <= 0 or height <= 0)
            return;

        var view = View.Component.byId(main_view_id);
        const target_ratio = height / width;
        const fit_to_width = target_ratio > _game_screen_ratio;

        var w: Float = 0;
        var h: Float = 0;
        if (fit_to_width) {
            view.scale[0] = width / _game_width;
            view.scale[1] = width / _game_width;
            w = _game_width;
            h = @ceil(_game_height / _game_screen_ratio * target_ratio);
        } else {
            view.scale[0] = height / _game_height;
            view.scale[1] = height / _game_height;
            w = @ceil(_game_width / target_ratio * _game_screen_ratio);
            h = _game_height;
        }

        if (center_camera) {
            view.position[0] = (w - _game_width) / 2 * view.scale[0];
            view.position[1] = (h - _game_height) / 2 * view.scale[1];
        }

        if (_listener) |l| l(main_view_id);
    }
};
