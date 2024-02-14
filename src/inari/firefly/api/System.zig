const std = @import("std");

const Allocator = std.mem.Allocator;
const trait = std.meta.trait;

const api = @import("api.zig");
const DynArray = api.utils.dynarray.DynArray;
const ArrayList = std.ArrayList;
const Component = api.Component;
const ComponentEvent = Component.ComponentEvent;
const UpdateEvent = api.UpdateEvent;
const RenderEvent = api.RenderEvent;
const UpdateScheduler = api.Timer.UpdateScheduler;
const Entity = api.Entity;
const Kind = api.utils.aspect.Kind;
const aspect = api.utils.aspect;
const Aspect = aspect.Aspect;
const AspectGroup = aspect.AspectGroup;
const String = api.utils.String;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;

const System = @This();

// component type fields
pub const NULL_VALUE = System{};
pub const COMPONENT_NAME = "System";
pub const pool = Component.ComponentPool(System);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (System) *System = undefined;
pub var exists: *const fn (Index) bool = undefined;
pub var existsName: *const fn (String) bool = undefined;
pub var get: *const fn (Index) *System = undefined;
pub var byId: *const fn (Index) *const System = undefined;
pub var byName: *const fn (String) *const System = undefined;
pub var activateById: *const fn (Index, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (Index) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
// pub var subscribe: *const fn (Component.EventListener) void = undefined;
// pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields of a System
id: Index = UNDEF_INDEX,
name: String = NO_NAME,
info: String = NO_NAME,
// struct function references of a System
onConstruct: ?*const fn () void = null,
onActivation: ?*const fn (bool) void = null,
onDestruct: ?*const fn () void = null,
// entity handling
onEntityEvent: ?*const fn (*const ComponentEvent) void = null,
entity_accept_kind: ?Kind = null,
entity_dismiss_kind: ?Kind = null,
// update handling
onUpdateEvent: ?*const fn (*const UpdateEvent) void = null,
update_scheduler: ?*const UpdateScheduler = null,
// renderer handling
onRenderEvent: ?*const fn (*const RenderEvent) void = null,

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    Entity.subscribe(onEntityEvent);
    api.Engine.subscribeUpdate(onUpdateEvent);
    api.Engine.subscribeRender(onRenderEvent);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    Entity.unsubscribe(onEntityEvent);
    api.Engine.unsubscribeUpdate(onUpdateEvent);
    api.Engine.unsubscribeRender(onRenderEvent);
}

pub fn construct(self: *System) void {
    if (self.onConstruct) |onConstruct| {
        onConstruct();
    }
}

pub fn activation(self: *System, active: bool) void {
    if (self.onActivation) |onActivation| {
        onActivation(active);
    }
}

pub fn destruct(self: *System) void {
    if (self.onDestruct) |onDestruct| {
        onDestruct();
    }
}

pub fn format(
    self: System,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.print(
        "{s}[ id:{d}, info:{s} ]",
        .{ self.name, self.id, self.info },
    );
}

// TODO  create event dedicated system ref collections that store only system ids of systems that
//       are interested in the particular event and iterate this instead of all.

fn onEntityEvent(event: *const ComponentEvent) void {
    const e_kind = &Entity.byId(event.c_id).kind;
    var i: Index = 0;
    while (System.pool.nextActiveId(i)) |id| {
        var system: *System = System.get(id);
        if (system.onEntityEvent) |onEntity| {
            if (system.entity_accept_kind) |*ak| {
                if (!ak.isKindOf(e_kind)) return;
            }
            if (system.entity_dismiss_kind) |*dk| {
                if (!dk.isNotKindOf(e_kind)) return;
            }
            onEntity(event);
        }
        i = id + 1;
    }
}

fn onUpdateEvent(event: *const UpdateEvent) void {
    var i: Index = 0;
    while (System.pool.nextActiveId(i)) |id| {
        var system: *const System = System.byId(id);
        if (system.onUpdateEvent) |update| {
            if (system.update_scheduler) |us| {
                if (us.needs_update) {
                    update(event);
                }
            } else {
                update(event);
            }
        }
        i = id + 1;
    }
}

fn onRenderEvent(event: *const RenderEvent) void {
    var i: Index = 0;
    while (System.pool.nextActiveId(i)) |id| {
        var system: *const System = System.byId(id);
        if (system.onRenderEvent) |render| {
            render(event);
        }
        i = id + 1;
    }
}
