const std = @import("std");
const Allocator = std.mem.Allocator;

const api = @import("api.zig"); // TODO module
const utils = @import("../../utils/utils.zig");

const Component = api.Component;
const CompLifecycleEvent = Component.CompLifecycleEvent;
const ComponentPool = api.component.ComponentPool;
const AspectGroup = utils.aspect.AspectGroup;
const aspect = utils.aspect;
const Kind = aspect.Kind;
const Aspect = aspect.Aspect;
const String = utils.String;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;
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
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
kind: Kind = undefined,
p_index: usize = UNDEF_INDEX,
c_index: usize = UNDEF_INDEX,

pub fn with(self: *Entity, c: anytype) *Entity {
    const T = @TypeOf(c);
    _ = Component.EntityComponentPool(T).register(@as(T, c));
    self.kind.with(T.type_aspect);
    return self;
}

pub fn onDispose(index: usize) void {
    Component.clearAllEntityComponentsAt(index);
}
