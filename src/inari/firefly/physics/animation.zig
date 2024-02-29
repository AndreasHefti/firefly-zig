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
const EntityComponent = api.EntityComponent;
const EntityEventSubscription = api.EntityEventSubscription;
const System = api.System;
const ComponentEvent = api.ComponentEvent;
const ActionType = api.Component.ActionType;
const UpdateEvent = api.UpdateEvent;
const Engine = api.Engine;
const BitSet = utils.BitSet;
const StringHashMap = std.StringHashMap;
const DynArray = utils.DynArray;
const String = utils.String;

//////////////////////////////////////////////////////////////
//// animation init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    AnimationSystem.init();
    Animation(EasedValueIntegration).init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    Animation(EasedValueIntegration).deinit();
    AnimationSystem.deinit();
}

//////////////////////////////////////////////////////////////
//// Animation API
//////////////////////////////////////////////////////////////

pub const IAnimation = struct {
    id: Index = UNDEF_INDEX,
    name: String = NO_NAME,

    animation: *anyopaque = undefined,

    fn_activate: *const fn (Index, bool) void = undefined,
    fn_suspend_it: *const fn (Index) void = undefined,
    fn_loop_callback: *const fn (Index, *const fn (usize) void) void = undefined,
    fn_finish_callback: *const fn (Index, *const fn (Index) void) void = undefined,
    fn_dispose: *const fn (Index) void = undefined,

    //update: *const fn (Index, Float) void,

    pub fn activate(self: *IAnimation, active: bool) void {
        self.fn_activate(self.id, active);
    }

    pub fn suspendIt(self: *IAnimation) void {
        self.fn_suspend_it(self.id);
    }

    pub fn setLoopCallback(self: *IAnimation, callback: *const fn (usize) void) void {
        self.fn_loop_callback(self.id, callback);
    }

    pub fn setFinishCallback(self: *IAnimation, callback: *const fn (Index) void) void {
        self.fn_finish_callback(self.id, callback);
    }

    pub fn dispose(self: *IAnimation) void {
        self.fn_dispose(self.id);
        self.id = UNDEF_INDEX;
        self.animation = undefined;
    }
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
        integration: Integration = undefined,

        // callbacks
        loop_callback: ?*const fn (usize) void = null,
        finish_callback: ?*const fn (Index) void = null,

        // object state
        _active: bool = false,
        _suspending: bool = false,
        _t_normalized: Float = 0,
        _inverted: bool = false,
        _loop_count: usize = 0,

        // interface reference
        _interface: IAnimation = undefined,

        fn init() void {
            defer Self.initialized = true;
            if (Self.initialized)
                return;

            animations = DynArray(Self).new(api.COMPONENT_ALLOC, Self{}) catch undefined;
            AnimationSystem.registerAnimationUpdate(updateAll);
        }

        fn deinit() void {
            defer Self.initialized = false;
            if (!Self.initialized)
                return;

            AnimationSystem.unregisterAnimationUpdate(updateAll);
            animations.deinit();
        }

        pub fn new(
            duration: usize,
            looping: bool,
            inverse_on_loop: bool,
            reset_on_finish: bool,
            integration: Integration,
        ) *IAnimation {
            var _new = Self{
                .duration = duration,
                .looping = looping,
                .inverse_on_loop = inverse_on_loop,
                .reset_on_finish = reset_on_finish,
                .integration = integration,
            };
            var index = animations.add(_new);

            var self = animations.get(index);
            self._interface = IAnimation{
                .id = index,
                .animation = self,
                .fn_activate = activate,
                .fn_suspend_it = suspendIt,
                .fn_loop_callback = withLoopCallback,
                .fn_finish_callback = withFinishCallback,
                .fn_dispose = dispose,
            };
            return &self._interface;
        }

        pub fn activate(index: Index, active: bool) void {
            animations.get(index)._active = active;
        }

        pub fn suspendIt(index: Index) void {
            animations.get(index)._suspending = true;
        }

        fn updateAll() void {
            var next = animations.slots.nextSetBit(0);
            while (next) |i| {
                var a_ptr: *Self = animations.get(i);
                if (a_ptr._active)
                    a_ptr.update();

                next = animations.slots.nextSetBit(i + 1);
            }
        }

        fn update(self: *Self) void {
            self._t_normalized += 1.0 * utils.usize_f32(Timer.timeElapsed / self.duration);
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
            if (self.reset_on_finish)
                reset(self);
            if (self.finish_callback) |c| {
                c(self._interface.id);
            }
        }

        fn reset(self: *Self) void {
            self._loop_count = 0;
            self._t_normalized = 0.0;
        }

        pub fn integrateAt(self: *Self, t: Float) void {
            self._t_normalized = t;
            Integration.integrate(self);
        }

        pub fn withFinishCallback(index: Index, finish_callback: ?*const fn (Index) void) void {
            animations.get(index).finish_callback = finish_callback;
        }

        pub fn withLoopCallback(index: Index, loop_callback: ?*const fn (usize) void) void {
            animations.get(index).loop_callback = loop_callback;
        }

        pub fn dispose(index: Index) void {
            animations.reset(index);
        }
    };
}

//////////////////////////////////////////////////////////////
//// EAnimation Entity Component
//////////////////////////////////////////////////////////////

pub const EAnimation = struct {
    pub usingnamespace EntityComponent.API.Adapter(@This(), "EAnimation");

    id: Index = UNDEF_INDEX,
    animations: DynArray(*IAnimation) = undefined,

    pub fn construct(self: *EAnimation) void {
        self.animations = DynArray(*IAnimation).new(api.ENTITY_ALLOC, null) catch unreachable;
    }

    pub fn destruct(self: *EAnimation) void {
        var next = self.animations.slots.nextSetBit(0);
        while (next) |i| {
            self.animations.get(i).dispose();
            next = self.animations.slots.nextSetBit(i + 1);
        }

        self.animations.deinit();
        self.animations = undefined;
    }
};

//////////////////////////////////////////////////////////////
//// Animation System
//////////////////////////////////////////////////////////////
const UpdateRef = *const fn () void;
pub const AnimationSystem = struct {
    const sys_name = "AnimationSystem ";

    var update_refs: DynArray(UpdateRef) = undefined;

    fn init() void {
        update_refs = DynArray(UpdateRef).new(api.ALLOC, null) catch unreachable;
        _ = System.new(System{
            .name = sys_name,
            .info = "Updates all active animations",
            .onActivation = onActivation,
        });
        System.activateByName(sys_name, true);
    }

    fn deinit() void {
        System.disposeByName(sys_name);
        update_refs.deinit();
    }

    fn registerAnimationUpdate(update_ref: UpdateRef) void {
        _ = update_refs.add(update_ref);
    }

    fn unregisterAnimationUpdate(update_ref: UpdateRef) void {
        update_refs.remove(update_ref);
    }

    fn onActivation(active: bool) void {
        if (active) Engine.subscribeUpdate(update) else Engine.unsubscribeUpdate(update);
    }

    fn update(_: UpdateEvent) void {
        var next = update_refs.slots.nextSetBit(0);
        while (next) |i| {
            update_refs.get(i).*();
            next = update_refs.slots.nextSetBit(i + 1);
        }
    }
};

//////////////////////////////////////////////////////////////
//// Eased Value Animation
//////////////////////////////////////////////////////////////

pub const EasedValueIntegration = struct {
    start_value: Float = 0.0,
    end_value: Float = 0.0,
    easing: utils.Easing = utils.Easing_Linear,
    property_ref: *Float,

    pub fn getAnimation(animation_interface: *IAnimation) *Animation(EasedValueIntegration) {
        return @alignCast(@ptrCast(animation_interface.animation));
    }

    pub fn getAnimationByName(name: String) ?*Animation(EasedValueIntegration) {
        var a = Animation(EasedValueIntegration);
        var next = a.animations.slots.nextSetBit(0);
        while (next) |i| {
            const a_ptr: *IAnimation = a.animations.get(i);
            if (std.mem.eql(u8, a_ptr.name, name)) {
                return getAnimation(a_ptr);
            }
            next = a.animations.slots.nextSetBit(i + 1);
        }
        return null;
    }

    pub fn integrate(a: *Animation(EasedValueIntegration)) void {
        if (a._inverted)
            a.integration.property_ref.* = std.math.lerp(
                a.integration.end_value,
                a.integration.start_value,
                a.integration.easing.f(a._t_normalized),
            )
        else
            a.integration.property_ref.* = std.math.lerp(
                a.integration.start_value,
                a.integration.end_value,
                a.integration.easing.f(a._t_normalized),
            );
    }
};
