const std = @import("std");

const Allocator = std.mem.Allocator;
const trait = std.meta.trait;

const api = @import("api.zig");
//const DynArray = api.utils.dynarray.DynArray;
//const ArrayList = std.ArrayList;
const Component = api.Component;
const ComponentEvent = Component.ComponentEvent;
const UpdateEvent = api.UpdateEvent;
const UpdateListener = api.UpdateListener;
const RenderEvent = api.RenderEvent;
const RenderListener = api.RenderListener;
const UpdateScheduler = api.Timer.UpdateScheduler;
const Engine = api.Engine;
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
onEntityEvent: ?Component.EventListener = null,
entity_accept_kind: ?Kind = null,
entity_dismiss_kind: ?Kind = null,
// update handling
onUpdateEvent: ?UpdateListener = null,
update_scheduler: ?UpdateScheduler = null,
// renderer handling
onRenderEvent: ?RenderListener = null,

pub fn construct(self: *System) void {
    if (self.onConstruct) |onConstruct| {
        onConstruct();
    }
    if (self.onEntityEvent) |onEntityEvent| {
        Entity.subscribe(onEntityEvent);
    }
}

pub fn activation(self: *System, active: bool) void {
    if (self.onActivation) |onActivation| {
        onActivation(active);
    }
    if (active) {
        if (self.onUpdateEvent) |onUpdateEvent| {
            Engine.subscribeUpdate(onUpdateEvent);
        }
        if (self.onRenderEvent) |onRenderEvent| {
            Engine.subscribeRender(onRenderEvent);
        }
    } else {
        if (self.onUpdateEvent) |onUpdateEvent| {
            Engine.unsubscribeUpdate(onUpdateEvent);
        }
        if (self.onRenderEvent) |onRenderEvent| {
            Engine.unsubscribeRender(onRenderEvent);
        }
    }
}

pub fn acceptEntity(self: *System, event: *const ComponentEvent) bool {
    const e_kind = &Entity.byId(event.c_id).kind;
    if (self.entity_accept_kind) |*ak| {
        if (!ak.isKindOf(e_kind)) return false;
    }
    if (self.entity_dismiss_kind) |*dk| {
        if (!dk.isNotKindOf(e_kind)) return false;
    }
    return true;
}

pub fn needsUpdate(self: *System) bool {
    if (self.update_scheduler) |us| {
        return us.needs_update;
    }
    return true;
}

pub fn destruct(self: *System) void {
    if (self.onDestruct) |onDestruct| {
        onDestruct();
    }
    if (self.onEntityEvent) |onEntityEvent| {
        Entity.unsubscribe(onEntityEvent);
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
