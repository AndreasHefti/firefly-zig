const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const api = firefly.api;

const Easing = utils.Easing;
const Float = utils.Float;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;

const Timer = api.Timer;
const Kind = utils.Kind;
const Entity = api.Entity;
const EComponent = api.EComponent;
const EntityEventSubscription = api.EntityEventSubscription;
const System = api.System;
const ComponentEvent = api.ComponentEvent;
const ActionType = api.Component.ActionType;
const UpdateEvent = api.UpdateEvent;
const Engine = firefly.Engine;
const BitSet = utils.BitSet;
const StringHashMap = std.StringHashMap;
const DynArray = utils.DynArray;
const String = utils.String;
const SpriteSetAsset = firefly.graphics.SpriteSetAsset;
const SpriteSet = firefly.graphics.SpriteSet;

//////////////////////////////////////////////////////////////
//// animation init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    IndexFrame.init();
    System(AnimationIntegration).createSystem(
        "AnimationIntegration",
        "Updates all active animations",
        true,
    );
    AnimationIntegration.registerAnimationType(EasedValueIntegration);
    EComponent.registerEntityComponent(EAnimation);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    IndexFrame.deinit();
    System(AnimationIntegration).disposeSystem();
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
        var animations: DynArray(Self) = undefined;

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

            animations = DynArray(Self).new(api.COMPONENT_ALLOC) catch undefined;
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
                animations.delete(i);
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
            var _new = Self{
                .duration = duration,
                .looping = looping,
                .inverse_on_loop = inverse_on_loop,
                .reset_on_finish = reset_on_finish,
                .loop_callback = loop_callback,
                .finish_callback = finish_callback,
                .integration = integration,
            };
            var index = animations.add(_new);

            var self = animations.get(index).?;
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
                if (animations.get(i)) |a| {
                    if (a._active) a.update();
                }
                next = animations.slots.nextSetBit(i + 1);
            }
        }

        fn update(self: *Self) void {
            self._t_normalized += 1.0 * utils.usize_f32(Timer.time_elapsed) / utils.usize_f32(self.duration);
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
    pub usingnamespace EComponent.Trait(@This(), "EAnimation");

    id: Index = UNDEF_INDEX,
    animations: BitSet = undefined,

    pub fn construct(self: *EAnimation) void {
        self.animations = BitSet.new(api.ENTITY_ALLOC) catch unreachable;
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
        self.animations.set(AnimationIntegration.animation_refs.add(Animation(@TypeOf(integration)).new(
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

    pub fn withAnimationAnd(
        self: *EAnimation,
        animation: AnimationTemplate,
        integration: anytype,
    ) *Entity {
        var i = integration;
        i.init(self.id);
        self.animations.set(AnimationIntegration.animation_refs.add(Animation(@TypeOf(integration)).new(
            animation.duration,
            animation.looping,
            animation.inverse_on_loop,
            animation.reset_on_finish,
            animation.loop_callback,
            animation.finish_callback,
            i,
        )));
        return Entity.byId(self.id);
    }

    pub fn activation(self: *EAnimation, active: bool) void {
        var next = self.animations.nextSetBit(0);
        while (next) |i| {
            if (active) {
                AnimationIntegration.resetById(i);
            } else {
                AnimationIntegration.activateById(i, false);
            }
            next = self.animations.nextSetBit(i + 1);
        }
    }

    pub fn destruct(self: *EAnimation) void {
        var next = self.animations.nextSetBit(0);
        while (next) |i| {
            AnimationIntegration.disposeAnimation(i);
            next = self.animations.nextSetBit(i + 1);
        }

        self.animations.deinit();
        self.animations = undefined;
    }
};

//////////////////////////////////////////////////////////////
//// Animation Integration System
//////////////////////////////////////////////////////////////

pub const AnimationIntegration = struct {
    const sys_name = "AnimationSystem ";

    var animation_type_refs: DynArray(AnimationTypeReference) = undefined;
    var animation_refs: DynArray(IAnimation) = undefined;

    pub fn systemInit() void {
        animation_type_refs = DynArray(AnimationTypeReference).newWithRegisterSize(
            api.ALLOC,
            10,
        ) catch unreachable;

        animation_refs = DynArray(IAnimation).new(api.COMPONENT_ALLOC) catch unreachable;
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
            Engine.subscribeUpdate(update)
        else
            Engine.unsubscribeUpdate(update);
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

    fn update(_: UpdateEvent) void {
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

    pub fn init(self: *EasedValueIntegration, id: Index) void {
        if (self.property_ref) |i| {
            self._property = i(id);
        }
    }

    pub fn integrate(a: *Animation(EasedValueIntegration)) void {
        if (a._inverted)
            a.integration._property.* = @mulAdd(
                Float,
                a.integration.start_value - a.integration.end_value,
                a.integration.easing.f(a._t_normalized),
                a.integration.end_value,
            )
        else
            a.integration._property.* = @mulAdd(
                Float,
                a.integration.end_value - a.integration.start_value,
                a.integration.easing.f(a._t_normalized),
                a.integration.start_value,
            );
    }
};

//////////////////////////////////////////////////////////////
//// Index Frame Animation
//////////////////////////////////////////////////////////////

pub const IndexFrame = struct {
    var frames: DynArray(IndexFrame) = undefined;

    index: Index = UNDEF_INDEX,
    duration: usize = 0,

    fn init() void {
        frames = DynArray(IndexFrame).new(api.COMPONENT_ALLOC) catch unreachable;
    }

    fn deinit() void {
        frames.deinit();
        frames = undefined;
    }

    pub fn createFromSpriteSet(name: String, duration: usize) IndexFrameList {
        const asset: *api.Asset = api.Asset.byName(name);
        api.Asset.activate(asset.id, true);
        const sprite_set: SpriteSet = asset.getResource(SpriteSetAsset);
        var result = IndexFrameList.new();

        for (sprite_set.sprites_indices.items) |spi| {
            var index = frames.add(IndexFrame{
                .index = sprite_set.byListIndex(spi).texture_binding,
                .duration = duration,
            });
            result.indices.set(index);
        }
        return result;
    }

    pub fn createListFromArrayData(data: []usize) IndexFrameList {
        if (@mod(data.len, 2) != 0)
            @panic("data must have even length");

        var result = IndexFrameList.new();
        var i: usize = 0;
        while (i < data.len) {
            var index = frames.add(IndexFrame{
                .index = data[i],
                .duration = data[i + 1],
            });
            result.indices.set(index);
            i = i + 2;
        }
        return result;
    }
};

pub const IndexFrameList = struct {
    indices: BitSet = undefined,
    _state_pointer: Index = 0,
    _duration: usize = UNDEF_INDEX,

    fn new() IndexFrameList {
        return IndexFrameList{ .indices = BitSet.new(api.COMPONENT_ALLOC) catch unreachable };
    }

    fn deinit(self: *IndexFrameList) void {
        var _next = self.indices.nextSetBit(0);
        while (_next) |i| {
            IndexFrame.frames.delete(i);
            _next = self.indices.nextSetBit(i + 1);
        }

        self.indices.deinit();
        self.indices = undefined;
    }

    pub fn duration(self: *IndexFrameList) usize {
        if (self._duration != UNDEF_INDEX)
            return self._duration;

        var d: usize = 0;
        var _next = self.indices.nextSetBit(0);
        while (_next) |i| {
            d += IndexFrame.frames.get(i).duration;
            _next = self.indices.nextSetBit(i + 1);
        }
        self._duration = d;
        return d;
    }

    pub fn getIndexAt(self: *IndexFrameList, t_normalized: Float, invert: bool) Index {
        var d: usize = self.duration();
        var t: usize = utils.f32_usize(t_normalized * utils.usize_f32(d));

        if (invert) {
            var _t: usize = d;
            var _next = self.indices.prevSetBit(self.indices.capacity());
            while (_next) |i| {
                _t -= IndexFrame.frames.get(i).duration;
                if (_t <= t) return i;
                _next = self.indices.prevSetBit(i - 1);
            }
        } else {
            var _t: usize = 0;
            var _next = self.indices.nextSetBit(0);
            while (_next) |i| {
                _t += IndexFrame.frames.get(i).duration;
                if (_t >= t) return i;
                _next = self.indices.nextSetBit(i + 1);
            }
        }

        return 0;
    }

    pub fn reset(self: *IndexFrameList) void {
        self._state_pointer = 0;
        self._duration = UNDEF_INDEX;
    }

    pub fn next(self: *IndexFrameList) ?*IndexFrame {
        var _next = self.indices.nextSetBit(self._state_pointer + 1);
        if (_next) |n| {
            self._state_pointer = n;
            return IndexFrame.frames.get(n);
        }
        return null;
    }

    pub fn prev(self: *IndexFrameList) ?*IndexFrame {
        var _next = self.indices.prevSetBit(self._state_pointer - 1);
        if (_next) |n| {
            self._state_pointer = n;
            return IndexFrame.frames.get(n);
        }
        return null;
    }
};

pub const IndexFrameIntegrator = struct {
    pub const resolver = AnimationResolver(IndexFrameIntegrator);

    timeline: IndexFrameList,
    property_ref: *const fn (Index) void,

    pub fn integrate(a: *Animation(IndexFrameIntegrator)) void {
        a.integration.property_ref(a.integration.timeline.getIndexAt(
            a._t_normalized,
            a._inverted,
        ));
    }
};

//////////////////////////////////////////////////////////////
//// Bezier Curve Animation
//////////////////////////////////////////////////////////////

pub const BezierCurveIntegrator = struct {
    pub const resolver = AnimationResolver(BezierCurveIntegrator);

    bezier_function: utils.CubicBezierFunction = undefined,
    easing: Easing = Easing.Linear,
    property_ref_x: ?*const fn (Index) *Float,
    property_ref_y: ?*const fn (Index) *Float,
    property_ref_a: ?*const fn (Index) *Float,

    _property_x: *Float = undefined,
    _property_y: *Float = undefined,
    _property_a: *Float = undefined,

    pub fn init(self: *BezierCurveIntegrator, id: Index) void {
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

    pub fn integrate(a: *Animation(BezierCurveIntegrator)) void {
        var pos = a.integration.bezier_function.fp(a.easing(a._t_normalized), a._inverted);
        a.integration._property_x = pos[0];
        a.integration._property_y = pos[1];
        a.integration._property_a = std.math.radiansToDegrees(
            Float,
            a.integration.bezier_function.fax(
                a.easing(a._t_normalized),
                a._inverted,
            ),
        );
    }
};
