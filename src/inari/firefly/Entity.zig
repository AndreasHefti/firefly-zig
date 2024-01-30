const std = @import("std");
const firefly = @import("firefly.zig");

const Allocator = std.mem.Allocator;
const component = firefly.api.component;
const CompLifecycleEvent = component.CompLifecycleEvent;
const ComponentPool = firefly.api.component.ComponentPool;
const AspectGroup = firefly.utils.aspect.AspectGroup;
const aspect = firefly.utils.aspect;
const Kind = aspect.Kind;
const Aspect = aspect.Aspect;
const String = firefly.utils.String;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_NAME = firefly.utils.NO_NAME;
const Entity = @This();

// component type fields
pub const null_value = Entity{};
pub const component_name = "Entity";
pub const pool = ComponentPool(Entity);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Entity) *Entity = undefined;
pub var byId: *const fn (usize) *Entity = undefined;
pub var byName: *const fn (String) ?*Entity = undefined;
pub var activateById: *const fn (usize, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (usize) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (component.EventListener) void = undefined;
pub var unsubscribe: *const fn (component.EventListener) void = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
kind: Kind = undefined,
p_index: usize = UNDEF_INDEX,
c_index: usize = UNDEF_INDEX,

pub fn with(self: *Entity, c: anytype) *Entity {
    const T = @TypeOf(c);
    _ = component.EntityComponentPool(T).register(@as(T, c));
    self.kind.with(T.type_aspect);
    return self;
}

pub fn onDispose(index: usize) void {
    component.clearAllEntityComponentsAt(index);
}
