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

    api.System(AnimationSystem).createSystem(
        firefly.Engine.CoreSystems.AnimationSystem.name,
        "Updates all active animations",
        true,
    );
    AnimationSystem.registerAnimationType(EasedValueIntegration);
    AnimationSystem.registerAnimationType(EasedColorIntegration);
    AnimationSystem.registerAnimationType(IndexFrameIntegration);
    api.EComponent.registerEntityComponent(EAnimation);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    api.System(AnimationSystem).disposeSystem();
}

//////////////////////////////////////////////////////////////
//// Animation API
//////////////////////////////////////////////////////////////

pub const IAnimation = struct {
    id: Index = UNDEF_INDEX,
    name: ?String = null,

    animation: *anyopaque = undefined,

    fn_activate: *const fn (Index, bool) void = undefined,
    fn_suspend_it: *const fn (Index) void = undefined,
    fn_set_loop_callback: *const fn (Index, *const fn (usize) void) void = undefined,
    fn_set_finish_callback: *const fn (Index, *const fn () void) void = undefined,
    fn_reset: *const fn (Index) void = undefined,
    fn_dispose: *const fn (Index) void = undefined,
};

const AnimationTypeReference = struct {
    _update_all: *const fn () void = undefined,
    _deinit: *const fn () void = undefined,
};

pub fn Animation(comptime Integration: type) type {
    return struct {
        const Self = @This();

        // type state
        var initialized = false;
        var animations: utils.DynArray(Self) = undefined;

        // object properties
        duration: usize = 0,
        looping: bool = false,
        inverse_on_loop: bool = false,
        reset_on_finish: bool = true,
        active_on_init: bool = true,
        integration: Integration = undefined,

        // callbacks
        loop_callback: ?*const fn (usize) void = null,
        finish_callback: ?*const fn () void = null,

        // internal state
        _active: bool = false,
        _suspending: bool = false,
        _t_normalized: Float = 0,
        _inverted: bool = false,
        _loop_count: usize = 0,

        fn init() AnimationTypeReference {
            defer Self.initialized = true;
            if (Self.initialized)
                @panic("Animation Type already initialized: " ++ @typeName(Integration));

            animations = utils.DynArray(Self).new(firefly.api.COMPONENT_ALLOC);
            return AnimationTypeReference{
                ._update_all = Self.updateAll,
                ._deinit = Self.deinit,
            };
        }

        fn deinit() void {
            defer Self.initialized = false;
            if (!Self.initialized)
                return;

            var next = animations.slots.nextSetBit(0);
            while (next) |i| {
                dispose(i);
                next = animations.slots.nextSetBit(i + 1);
            }
            animations.clear();
            animations.deinit();
        }

        pub fn new(
            duration: usize,
            looping: bool,
            inverse_on_loop: bool,
            reset_on_finish: bool,
            loop_callback: ?*const fn (usize) void,
            finish_callback: ?*const fn () void,
            integration: Integration,
        ) IAnimation {
            const _new = Self{
                .duration = duration,
                .looping = looping,
                .inverse_on_loop = inverse_on_loop,
                .reset_on_finish = reset_on_finish,
                .loop_callback = loop_callback,
                .finish_callback = finish_callback,
                .integration = integration,
            };
            const index = animations.add(_new);

            const self = animations.get(index).?;
            return IAnimation{
                .id = index,
                .animation = self,
                .fn_activate = activate,
                .fn_suspend_it = suspendIt,
                .fn_set_loop_callback = withLoopCallback,
                .fn_set_finish_callback = withFinishCallback,
                .fn_reset = reset,
                .fn_dispose = dispose,
            };
        }

        pub fn activate(index: Index, active: bool) void {
            if (animations.get(index)) |a| a._active = active;
        }

        pub fn reset(index: Index) void {
            if (animations.get(index)) |a| {
                a.resetIntegration();
                a._active = a.active_on_init;
            }
        }

        pub fn suspendIt(index: Index) void {
            if (animations.get(index)) |a| a._suspending = true;
        }

        fn updateAll() void {
            var next = animations.slots.nextSetBit(0);
            while (next) |i| {
                if (animations.get(i)) |a|
                    if (a._active) a.update();

                next = animations.slots.nextSetBit(i + 1);
            }
        }

        fn update(self: *Self) void {
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

            Integration.integrate(self);
        }

        fn finish(self: *Self) void {
            self._active = false;
            if (self.reset_on_finish) resetIntegration(self);
            if (self.finish_callback) |c| c();
        }

        fn resetIntegration(self: *Self) void {
            self._loop_count = 0;
            self._t_normalized = 0.0;
        }

        pub fn integrateAt(self: *Self, t: Float) void {
            self._t_normalized = t;
            Integration.integrate(self);
        }

        pub fn withFinishCallback(index: Index, finish_callback: ?*const fn () void) void {
            if (animations.get(index)) |a| a.finish_callback = finish_callback;
        }

        pub fn withLoopCallback(index: Index, loop_callback: ?*const fn (usize) void) void {
            if (animations.get(index)) |a| a.loop_callback = loop_callback;
        }

        pub fn dispose(index: Index) void {
            if (@hasDecl(Integration, "dispose"))
                animations.get(index).?.integration.dispose();
            animations.delete(index);
        }
    };
}

fn AnimationResolver(comptime Integration: type) type {
    return struct {
        pub fn get(animation_interface: *IAnimation) *Animation(Integration) {
            return @alignCast(@ptrCast(animation_interface.animation));
        }

        pub fn byName(name: String) ?*Animation(Integration) {
            var a = Animation(Integration);
            var next = a.animations.slots.nextSetBit(0);
            while (next) |i| {
                const a_ptr: *IAnimation = a.animations.get(i);
                if (std.mem.eql(u8, a_ptr.name, name)) {
                    return get(a_ptr);
                }
                next = a.animations.slots.nextSetBit(i + 1);
            }
            return null;
        }
    };
}

//////////////////////////////////////////////////////////////
//// EAnimation Entity Component
//////////////////////////////////////////////////////////////

pub const EAnimation = struct {
    pub usingnamespace api.EComponent.Trait(@This(), "EAnimation");

    id: Index = UNDEF_INDEX,
    animations: utils.BitSet = undefined,

    pub fn construct(self: *EAnimation) void {
        self.animations = utils.BitSet.new(firefly.api.ENTITY_ALLOC);
    }

    pub const AnimationTemplate = struct {
        duration: usize,
        looping: bool = false,
        inverse_on_loop: bool = false,
        reset_on_finish: bool = true,
        active_on_init: bool = true,
        loop_callback: ?*const fn (usize) void = null,
        finish_callback: ?*const fn () void = null,
    };

    pub fn withAnimation(
        self: *EAnimation,
        animation: AnimationTemplate,
        integration: anytype,
    ) *EAnimation {
        var i = integration;
        i.init(self.id);
        self.animations.set(AnimationSystem.animation_refs.add(Animation(@TypeOf(integration)).new(
            animation.duration,
            animation.looping,
            animation.inverse_on_loop,
            animation.reset_on_finish,
            animation.loop_callback,
            animation.finish_callback,
            i,
        )));
        return self;
    }

    pub fn activation(self: *EAnimation, active: bool) void {
        var next = self.animations.nextSetBit(0);
        while (next) |i| {
            if (active) {
                AnimationSystem.resetById(i);
            } else {
                AnimationSystem.activateById(i, false);
            }
            next = self.animations.nextSetBit(i + 1);
        }
    }

    pub fn destruct(self: *EAnimation) void {
        var next = self.animations.nextSetBit(0);
        while (next) |i| {
            AnimationSystem.disposeAnimation(i);
            next = self.animations.nextSetBit(i + 1);
        }

        self.animations.deinit();
        self.animations = undefined;
    }
};

//////////////////////////////////////////////////////////////
//// Animation Integration System
//////////////////////////////////////////////////////////////

pub const AnimationSystem = struct {
    var animation_type_refs: utils.DynArray(AnimationTypeReference) = undefined;
    var animation_refs: utils.DynArray(IAnimation) = undefined;

    pub fn systemInit() void {
        animation_type_refs = utils.DynArray(AnimationTypeReference).newWithRegisterSize(
            firefly.api.COMPONENT_ALLOC,
            10,
        );

        animation_refs = utils.DynArray(IAnimation).new(firefly.api.COMPONENT_ALLOC);
    }

    pub fn systemDeinit() void {
        var next = animation_refs.slots.nextSetBit(0);
        while (next) |i| {
            if (animation_refs.get(i)) |ar| ar.fn_dispose(i);
            next = animation_refs.slots.nextSetBit(i + 1);
        }
        animation_refs.clear();
        animation_refs.deinit();
        animation_refs = undefined;

        next = animation_type_refs.slots.nextSetBit(0);
        while (next) |i| {
            if (animation_type_refs.get(i)) |ar| ar._deinit();
            next = animation_type_refs.slots.nextSetBit(i + 1);
        }
        animation_type_refs.clear();
        animation_type_refs.deinit();
        animation_type_refs = undefined;
    }

    pub fn systemActivation(active: bool) void {
        if (active)
            firefly.Engine.subscribeUpdate(update)
        else
            firefly.Engine.unsubscribeUpdate(update);
    }

    pub fn activateById(id: Index, active: bool) void {
        if (initialized)
            if (animation_refs.get(id)) |ar| ar.fn_activate(id, active);
    }

    pub fn resetById(id: Index) void {
        if (initialized)
            if (animation_refs.get(id)) |ar| ar.fn_reset(id);
    }

    pub fn suspendById(id: Index) void {
        if (initialized)
            if (animation_refs.get(id)) |ar| ar.fn_suspend_it(id);
    }

    pub fn setLoopCallbackById(id: Index, callback: *const fn (usize) void) void {
        if (initialized)
            if (animation_refs.get(id)) |ar| ar.fn_set_loop_callback(id, callback);
    }

    pub fn setFinishCallbackById(id: Index, callback: *const fn (Index) void) void {
        if (initialized)
            if (animation_refs.get(id)) |ar| ar.fn_set_finish_callback(id, callback);
    }

    pub fn registerAnimationType(comptime Integration: type) void {
        _ = animation_type_refs.add(Animation(Integration).init());
    }

    fn disposeAnimation(id: Index) void {
        if (initialized) {
            if (animation_refs.get(id)) |ar| ar.fn_dispose(id);
            animation_refs.delete(id);
        }
    }

    fn update(_: api.UpdateEvent) void {
        var next = animation_type_refs.slots.nextSetBit(0);
        while (next) |i| {
            if (animation_type_refs.get(i)) |ar| ar._update_all();
            next = animation_type_refs.slots.nextSetBit(i + 1);
        }
    }
};

//////////////////////////////////////////////////////////////
//// Eased Value Animation
//////////////////////////////////////////////////////////////

pub const EasedValueIntegration = struct {
    pub const resolver = AnimationResolver(EasedValueIntegration);

    start_value: Float = 0.0,
    end_value: Float = 0.0,
    easing: Easing = Easing.Linear,
    property_ref: ?*const fn (Index) *Float = null,
    _property: *Float = undefined,

    _easing_v: Float = 0,

    pub fn init(self: *EasedValueIntegration, id: Index) void {
        if (self.property_ref) |i|
            self._property = i(id);

        self._easing_v = self.end_value - self.start_value;
        self._property.* = self.start_value;
    }

    pub fn integrate(a: *Animation(EasedValueIntegration)) void {
        const self = a.integration;
        self._property.* = @mulAdd(
            Float,
            if (a._inverted) -self._easing_v else self._easing_v,
            self.easing.f(a._t_normalized),
            if (a._inverted) self.end_value else self.start_value,
        );
    }
};

//////////////////////////////////////////////////////////////
//// Color Value Animation
//////////////////////////////////////////////////////////////

pub const EasedColorIntegration = struct {
    pub const resolver = AnimationResolver(EasedColorIntegration);

    start_value: utils.Color = .{ 0, 0, 0, 255 },
    end_value: utils.Color = .{ 0, 0, 0, 255 },
    easing: Easing = Easing.Linear,
    property_ref: ?*const fn (Index) *utils.Color = null,
    _property: *utils.Color = undefined,

    _norm_range: @Vector(4, Float) = .{ 0, 0, 0, 0 },

    pub fn init(self: *EasedColorIntegration, id: Index) void {
        if (self.property_ref) |i|
            self._property = i(id);

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

    pub fn integrate(a: *Animation(EasedColorIntegration)) void {
        const self = a.integration;
        const v_normalized: Float = self.easing.f(a._t_normalized);

        for (0..4) |slot| {
            if (self._norm_range[slot] != 0)
                _integrate(self, v_normalized, a._inverted, slot);
        }
    }

    inline fn _integrate(self: EasedColorIntegration, v_normalized: Float, inv: bool, slot: usize) void {
        self._property.*[slot] = @intFromFloat(@mulAdd(
            Float,
            if (inv) -self._norm_range[slot] else self._norm_range[slot],
            v_normalized,
            @floatFromInt(if (inv) self.end_value[slot] else self.start_value[slot]),
        ));
    }
};

//////////////////////////////////////////////////////////////
//// Index Frame Animation
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

pub const IndexFrameIntegration = struct {
    pub const resolver = AnimationResolver(IndexFrameIntegration);

    timeline: IndexFrameList,
    property_ref: ?*const fn (Index) *Index,

    _property: *Index = undefined,

    pub fn init(self: *IndexFrameIntegration, id: Index) void {
        if (self.property_ref) |ref| {
            self._property = ref(id);
        }
    }

    pub fn integrate(a: *Animation(IndexFrameIntegration)) void {
        a.integration._property.* = a.integration.timeline.getAt(
            a._t_normalized,
            a._inverted,
        );
    }

    pub fn dispose(self: *IndexFrameIntegration) void {
        self.timeline.deinit();
    }
};

//////////////////////////////////////////////////////////////
//// Bezier Curve Animation
//////////////////////////////////////////////////////////////

pub const BezierCurveIntegration = struct {
    pub const resolver = AnimationResolver(BezierCurveIntegration);

    bezier_function: utils.CubicBezierFunction = undefined,
    easing: Easing = Easing.Linear,
    property_ref_x: ?*const fn (Index) *Float,
    property_ref_y: ?*const fn (Index) *Float,
    property_ref_a: ?*const fn (Index) *Float,

    _property_x: *Float = undefined,
    _property_y: *Float = undefined,
    _property_a: *Float = undefined,

    pub fn init(self: *BezierCurveIntegration, id: Index) void {
        if (self.property_ref_x) |i| {
            self._property_x = i(id);
        }
        if (self.property_ref_y) |i| {
            self._property_y = i(id);
        }
        if (self.property_ref_a) |i| {
            self._property_a = i(id);
        }
    }

    pub fn integrate(a: *Animation(BezierCurveIntegration)) void {
        const pos = a.integration.bezier_function.fp(a.easing(a._t_normalized), a._inverted);
        a.integration._property_x.* = pos[0];
        a.integration._property_y.* = pos[1];
        a.integration._property_a.* = std.math.radiansToDegrees(
            Float,
            a.integration.bezier_function.fax(
                a.easing(a._t_normalized),
                a._inverted,
            ),
        );
    }
};
