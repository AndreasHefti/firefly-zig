const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;

const String = firefly.utils.String;
const Easing = firefly.utils.Easing;
const Float = firefly.utils.Float;
const Index = firefly.utils.Index;
const Byte = firefly.utils.Byte;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_NAME = firefly.utils.NO_NAME;

//////////////////////////////////////////////////////////////
//// animation init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.Component.register(Animation, "Animation");
    api.Component.Subtype.register(Animation, EasedValueIntegrator, "EasedValueIntegrator");
    api.Component.Subtype.register(Animation, EasedColorIntegrator, "EasedColorIntegrator");
    api.Component.Subtype.register(Animation, IndexFrameIntegrator, "IndexFrameIntegrator");
    api.Component.Subtype.register(Animation, BezierSplineIntegrator, "BezierSplineIntegrator");
    api.Entity.registerComponent(EAnimation, "EAnimation");
    api.System.register(AnimationSystem);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Animation Component
//////////////////////////////////////////////////////////////

pub const Animation = struct {
    pub const Component = api.Component.Mixin(Animation);
    pub const Naming = api.Component.NameMappingMixin(Animation);
    pub const Activation = api.Component.ActivationMixin(Animation);
    pub const Subscription = api.Component.SubscriptionMixin(Animation);
    pub const Subtypes = api.Component.SubTypingMixin(Animation);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    // animation settings
    duration: usize = 0,
    looping: bool = false,
    inverse_on_loop: bool = false,
    reset_on_finish: bool = true,
    active_on_init: bool = true,

    // callbacks
    loop_callback: ?*const fn (usize) void = null,
    finish_callback: ?*const fn () void = null,

    // internal state
    _suspending: bool = false,
    _t_normalized: Float = 0,
    _inverted: bool = false,
    _loop_count: usize = 0,
    _integrator_ref: IntegratorRef = undefined,

    pub fn construct(self: *Animation) void {
        if (self.active_on_init)
            Animation.Activation.activate(self.id);
    }

    pub fn new(
        animation: Animation,
        integrator: anytype,
        component_id: ?Index,
    ) void {
        const i_type = @TypeOf(integrator);
        const aid = i_type.Component.createSubtype(animation, integrator).id;
        if (component_id) |cid|
            Component.byId(aid).initForComponent(cid);
    }

    pub fn resetById(id: Index) void {
        Component.byId(id).reset();
    }

    pub fn reset(self: *Animation) void {
        self._loop_count = 0;
        self._t_normalized = 0.0;
        if (self.active_on_init) {
            Animation.Activation.activate(self.id);
        } else {
            Animation.Activation.deactivate(self.id);
        }
    }

    pub fn suspendById(id: Index) void {
        Component.byId(id).suspendIt();
    }

    pub fn suspendIt(self: *Animation) void {
        self._suspending = true;
    }

    pub fn initForComponent(self: *Animation, c_id: Index) void {
        self._integrator_ref.init(self.id, c_id);
    }

    fn update(self: *Animation) void {
        self._t_normalized += 1.0 * firefly.utils.usize_f32(api.Timer.d_time) / firefly.utils.usize_f32(self.duration);
        if (self._t_normalized >= 1.0) {
            self._t_normalized = 0.0;
            if (self._suspending or !self.looping) {
                finish(self);
                return;
            } else {
                if (self.inverse_on_loop)
                    self._inverted = !self._inverted;
                if (!self._inverted) {
                    self._loop_count += 1;
                    if (self.loop_callback) |c| {
                        c(self._loop_count);
                    }
                }
            }
        }

        self._integrator_ref.integrate(self);
    }

    fn finish(self: *Animation) void {
        if (self.reset_on_finish)
            reset(self);
        if (self.finish_callback) |c|
            c();
        Animation.Activation.deactivate(self.id);
    }
};

pub const IntegratorRef = struct {
    init: *const fn (animation_id: Index, component_id: Index) void,
    integrate: *const fn (animation: *Animation) void,
};

// //////////////////////////////////////////////////////////////
// //// Animation System
// //////////////////////////////////////////////////////////////

pub const AnimationSystem = struct {
    pub const System = api.SystemMixin(AnimationSystem);

    pub fn update(_: api.UpdateEvent) void {
        Animation.Activation.process(Animation.update);
    }
};

//////////////////////////////////////////////////////////////
//// EAnimation Entity Component
//////////////////////////////////////////////////////////////

pub const EAnimation = struct {
    pub const Component = api.EntityComponentMixin(EAnimation);

    id: Index = UNDEF_INDEX,
    animations: utils.BitSet = undefined,

    pub fn construct(self: *EAnimation) void {
        self.animations = utils.BitSet.new(firefly.api.ENTITY_ALLOC);
    }

    pub fn build(a: EAnimation) EAnimationBuilder {
        return EAnimationBuilder.new(a);
    }

    pub fn add(entity_id: Index, animation: Animation, integrator: anytype) void {
        const i_type = @TypeOf(integrator);
        const a_id = i_type.Component.createSubtype(animation, integrator).id;
        const exists = Component.byId(entity_id);
        if (exists) |c| {
            c.animations.set(a_id);
            //Animation.Component.byId(a_id).initForComponent(entity_id);
        } else {
            Component.new(entity_id, .{});
            if (Component.byId(entity_id)) |c| {
                c.animations.set(a_id);
                //Animation.Component.byId(a_id).initForComponent(entity_id);
            }
        }
    }

    pub fn activation(self: *EAnimation, active: bool) void {
        if (!initialized) return;

        var next = self.animations.nextSetBit(0);
        while (next) |i| {
            if (active) {
                Animation.Component.byId(i).initForComponent(self.id);
                Animation.resetById(i);
            } else {
                Animation.Activation.deactivate(i);
            }
            next = self.animations.nextSetBit(i + 1);
        }
    }

    pub fn destruct(self: *EAnimation) void {
        if (initialized) {
            var next = self.animations.nextSetBit(0);
            while (next) |i| {
                Animation.Component.dispose(i);
                next = self.animations.nextSetBit(i + 1);
            }
        }

        self.animations.deinit();
        self.animations = undefined;
    }
};

pub const EAnimationBuilder = struct {
    component: EAnimation,
    animations: utils.BitSet,

    pub fn new(component: EAnimation) EAnimationBuilder {
        return .{
            .component = component,
            .animations = utils.BitSet.new(api.ALLOC),
        };
    }

    pub fn addAnimation(
        self: EAnimationBuilder,
        animation: Animation,
        integrator: anytype,
    ) EAnimationBuilder {
        var builder = self;
        const i_type = @TypeOf(integrator);

        const a_id = i_type.Component.createSubtype(animation, integrator).id;
        builder.animations.set(a_id);
        return builder;
    }

    pub fn buildForEntity(self: EAnimationBuilder, entity_id: Index) void {
        var builder = self;
        EAnimation.Component.new(entity_id, self.component);

        var next = builder.animations.nextSetBit(0);
        while (next) |i| {
            next = builder.animations.nextSetBit(i + 1);
            Animation.Component.byId(i).initForComponent(entity_id);
        }
        builder.animations.deinit();
    }
};

//////////////////////////////////////////////////////////////
//// Eased Value Animation Integrator
//////////////////////////////////////////////////////////////

pub const EasedValueIntegrator = struct {
    pub const Component = api.Component.SubTypeMixin(Animation, EasedValueIntegrator);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    start_value: Float = 0.0,
    end_value: Float = 0.0,
    easing: Easing = Easing.Linear,
    property_ref: ?*const fn (Index) *Float = null,
    _property: *Float = undefined,
    _easing_v: Float = 0,

    pub fn construct(self: *EasedValueIntegrator) void {
        Animation.Component.byId(self.id)._integrator_ref = IntegratorRef{
            .init = EasedValueIntegrator.init,
            .integrate = EasedValueIntegrator.integrate,
        };
    }

    fn init(animation_id: Index, component_id: Index) void {
        var self = Component.byId(animation_id);
        if (self.property_ref) |p_ref|
            self._property = p_ref(component_id);

        self._easing_v = self.end_value - self.start_value;
        self._property.* = self.start_value;
    }

    fn integrate(animation: *Animation) void {
        var self = Component.byId(animation.id);
        self._property.* = @mulAdd(
            Float,
            if (animation._inverted) -self._easing_v else self._easing_v,
            self.easing.f(animation._t_normalized),
            if (animation._inverted) self.end_value else self.start_value,
        );
    }
};

//////////////////////////////////////////////////////////////
//// Color Value Animation
//////////////////////////////////////////////////////////////

pub const EasedColorIntegrator = struct {
    pub const Component = api.Component.SubTypeMixin(Animation, EasedColorIntegrator);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    start_value: utils.Color = .{ 0, 0, 0, 255 },
    end_value: utils.Color = .{ 0, 0, 0, 255 },
    easing: Easing = Easing.Linear,
    property_ref: ?*const fn (Index) *utils.Color = null,
    _property: *utils.Color = undefined,

    _norm_range: @Vector(4, Float) = .{ 0, 0, 0, 0 },

    pub fn construct(self: *EasedColorIntegrator) void {
        Animation.Component.byId(self.id)._integrator_ref = IntegratorRef{
            .init = EasedColorIntegrator.init,
            .integrate = EasedColorIntegrator.integrate,
        };
    }

    pub fn init(animation_id: Index, component_id: Index) void {
        var self = EasedColorIntegrator.Component.byId(animation_id);
        if (self.property_ref) |i|
            self._property = i(component_id);

        self._norm_range = .{
            @floatFromInt(self.end_value[0] - self.start_value[0]),
            @floatFromInt(self.end_value[1] - self.start_value[1]),
            @floatFromInt(self.end_value[2] - self.start_value[2]),
            @floatFromInt(self.end_value[3] - self.start_value[3]),
        };

        self._property.*[0] = self.start_value[0];
        self._property.*[1] = self.start_value[1];
        self._property.*[2] = self.start_value[2];
        self._property.*[3] = self.start_value[3];
    }

    pub fn integrate(animation: *Animation) void {
        var self = Component.byId(animation.id);
        const v_normalized: Float = self.easing.f(animation._t_normalized);

        for (0..4) |slot| {
            if (self._norm_range[slot] != 0)
                _integrate(self, v_normalized, animation._inverted, slot);
        }
    }

    inline fn _integrate(self: *EasedColorIntegrator, v_normalized: Float, inv: bool, slot: usize) void {
        self._property.*[slot] = @intFromFloat(@mulAdd(
            Float,
            if (inv) -self._norm_range[slot] else self._norm_range[slot],
            v_normalized,
            @floatFromInt(if (inv) self.end_value[slot] else self.start_value[slot]),
        ));
    }
};

//////////////////////////////////////////////////////////////
//// Index Frame Animation Integrator
//////////////////////////////////////////////////////////////

pub const IndexFrame = struct {
    sprite_id: Index = UNDEF_INDEX,
    duration: usize = 0,
};

pub const IndexFrameList = struct {
    frames: utils.DynArray(IndexFrame) = undefined,
    _state_pointer: Index = 0,
    _duration: usize = 0,

    pub fn new() IndexFrameList {
        return IndexFrameList{
            .frames = utils.DynArray(IndexFrame).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10),
        };
    }

    pub fn deinit(self: *IndexFrameList) void {
        self.frames.deinit();
        self.frames = undefined;
        self._state_pointer = 0;
        self._duration = 0;
    }

    pub fn withFrame(self: *IndexFrameList, sprite_id: Index, frame_duration: usize) *IndexFrameList {
        _ = self.frames.add(.{ .sprite_id = sprite_id, .duration = frame_duration });
        self._duration += frame_duration;
        return self;
    }

    pub fn getAt(self: *IndexFrameList, t_normalized: Float, invert: bool) Index {
        const t: usize = firefly.utils.f32_usize(t_normalized * firefly.utils.usize_f32(self._duration));
        if (invert) {
            var _t: usize = self._duration;
            var _next = self.frames.slots.prevSetBit(self.frames.capacity());
            while (_next) |i| {
                if (self.frames.get(i)) |f| {
                    _t -= f.duration;
                }
                if (_t <= t)
                    return self.frames.get(i).?.sprite_id;
                _next = self.frames.slots.prevSetBit(i - 1);
            }
        } else {
            var _t: usize = 0;
            var _next = self.frames.slots.nextSetBit(0);
            while (_next) |i| {
                if (self.frames.get(i)) |f| {
                    _t += f.duration;
                }
                if (_t >= t)
                    return self.frames.get(i).?.sprite_id;
                _next = self.frames.slots.nextSetBit(i + 1);
            }
        }

        return 0;
    }

    pub fn reset(self: *IndexFrameList) void {
        self._state_pointer = 0;
        self._duration = 0;
    }

    pub fn next(self: *IndexFrameList) ?*IndexFrame {
        const _next = self.frames.slots.nextSetBit(self._state_pointer + 1);
        if (_next) |n| {
            self._state_pointer = n;
            return self.frames.get(n);
        }
        return null;
    }

    pub fn prev(self: *IndexFrameList) ?*IndexFrame {
        const _next = self.frames.slots.prevSetBit(self._state_pointer - 1);
        if (_next) |n| {
            self._state_pointer = n;
            return self.frames.get(n);
        }
        return null;
    }
};

pub const IndexFrameIntegrator = struct {
    pub const Component = api.Component.SubTypeMixin(Animation, IndexFrameIntegrator);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    timeline: IndexFrameList,
    property_ref: ?*const fn (Index) *Index,

    _property: *Index = undefined,

    pub fn construct(self: *IndexFrameIntegrator) void {
        Animation.Component.byId(self.id)._integrator_ref = IntegratorRef{
            .init = IndexFrameIntegrator.init,
            .integrate = IndexFrameIntegrator.integrate,
        };
    }

    pub fn destruct(self: *IndexFrameIntegrator) void {
        self.timeline.deinit();
    }

    pub fn init(animation_id: Index, component_id: Index) void {
        var self = Component.byId(animation_id);
        if (self.property_ref) |ref|
            self._property = ref(component_id);
    }

    pub fn integrate(animation: *Animation) void {
        var self = Component.byId(animation.id);
        self._property.* = self.timeline.getAt(
            animation._t_normalized,
            animation._inverted,
        );
    }
};

//////////////////////////////////////////////////////////////
//// Bezier Spline Animation Integrator
//////////////////////////////////////////////////////////////

pub const BezierSplineIntegrator = struct {
    pub const Component = api.Component.SubTypeMixin(Animation, BezierSplineIntegrator);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    spline_duration: usize = 0,
    bezier_spline: utils.DynArray(utils.BezierSplineSegment) = undefined,
    _current_segment: ?*utils.BezierSplineSegment = null,

    property_ref_x: ?*const fn (Index) *Float,
    property_ref_y: ?*const fn (Index) *Float,
    property_ref_a: ?*const fn (Index) *Float,

    _property_x: *Float = undefined,
    _property_y: *Float = undefined,
    _property_a: *Float = undefined,

    pub fn construct(self: *BezierSplineIntegrator) void {
        Animation.Component.byId(self.id)._integrator_ref = IntegratorRef{
            .init = BezierSplineIntegrator.init,
            .integrate = BezierSplineIntegrator.integrate,
        };
        self.bezier_spline = utils.DynArray(utils.BezierSplineSegment).new(api.COMPONENT_ALLOC);
    }

    pub fn destruct(self: *BezierSplineIntegrator) void {
        self.bezier_spline.deinit();
    }

    pub fn addSegment(self: *BezierSplineIntegrator, segment: utils.BezierSplineSegment) void {
        _ = self.bezier_spline.add(segment);
        self.spline_duration += segment.duration;
        calcRanges(self);
    }

    fn calcRanges(self: *BezierSplineIntegrator) void {
        var last: Float = 0;
        var next = self.bezier_spline.slots.nextSetBit(0);
        while (next) |i| {
            next = self.bezier_spline.slots.nextSetBit(i + 1);
            if (self.bezier_spline.get(i)) |segment| {
                const from = last;
                last += 1 * utils.usize_f32(segment.duration) / utils.usize_f32(self.spline_duration);
                segment.normalized_time_range = .{ from, last };
            }
        }
    }

    pub fn init(animation_id: Index, component_id: Index) void {
        var self = Component.byId(animation_id);
        if (self.property_ref_x) |i|
            self._property_x = i(component_id);
        if (self.property_ref_y) |i|
            self._property_y = i(component_id);
        if (self.property_ref_a) |i|
            self._property_a = i(component_id);
        Animation.Component.byId(animation_id).duration = self.spline_duration;
    }

    pub fn integrate(a: *Animation) void {
        const self = Component.byId(a.id);
        const norm_time: Float = if (a._inverted) 1 - a._t_normalized else a._t_normalized;
        setCurrentSegment(self, norm_time);

        if (self._current_segment) |s| {
            const segment_norm_time = utils.transformRange(
                norm_time,
                if (a._inverted) s.normalized_time_range[1] else s.normalized_time_range[0],
                if (a._inverted) s.normalized_time_range[0] else s.normalized_time_range[1],
                0,
                1,
            );
            const pos = s.bezier.fp(s.easing.f(segment_norm_time), a._inverted);
            self._property_x.* = pos[0];
            self._property_y.* = pos[1];
            self._property_a.* = std.math.radiansToDegrees(s.bezier.fax(s.easing.f(segment_norm_time), a._inverted));
        }
    }

    fn setCurrentSegment(self: *BezierSplineIntegrator, time: Float) void {
        if (self._current_segment) |segment| {
            if (segment.normalized_time_range[0] <= time and segment.normalized_time_range[1] > time)
                return;
        }
        // find current segment
        var next = self.bezier_spline.slots.nextSetBit(0);
        while (next) |i| {
            next = self.bezier_spline.slots.nextSetBit(i + 1);
            if (self.bezier_spline.get(i)) |s| {
                if (s.normalized_time_range[0] <= time and s.normalized_time_range[1] > time) {
                    self._current_segment = s;
                    return;
                }
            }
        }
    }
};
