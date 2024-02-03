const std = @import("std");
const Allocator = std.mem.Allocator;

const api = @import("api.zig"); // TODO module

const Component = api.Component;
const Kind = api.utils.aspect.Kind;
const Aspect = api.utils.aspect.Aspect;
const String = api.utils.String;
const UNDEF_INDEX = api.utils.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;
const Entity = @This();

// component type fields
pub const NULL_VALUE = Entity{};
pub const COMPONENT_NAME = "Entity";
pub const pool = Component.ComponentPool(Entity);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Entity) *Entity = undefined;
pub var exists: *const fn (usize) bool = undefined;
pub var existsName: *const fn (String) bool = undefined;
pub var get: *const fn (usize) *Entity = undefined;
pub var byId: *const fn (usize) *const Entity = undefined;
pub var byName: *const fn (String) *const Entity = undefined;
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
