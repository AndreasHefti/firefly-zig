const std = @import("std");

const Allocator = std.mem.Allocator;
const trait = std.meta.trait;

const api = @import("api.zig");
const DynArray = api.utils.dynarray.DynArray;
const ArrayList = std.ArrayList;
const Component = api.Component;
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
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields of a System
id: Index = UNDEF_INDEX,
name: String = NO_NAME,
info: String = NO_NAME,
// struct function references of a System
onInit: ?*const fn () void = null,
onActivation: ?*const fn (bool) void = null,
onDispose: ?*const fn () void = null,

pub fn onNew(id: Index) void {
    if (System.get(id).onInit) |onInit| {
        onInit();
    }
}

pub fn onActivation(id: Index, active: bool) void {
    if (System.get(id).onActivation) |onAct| {
        onAct(active);
    }
}

pub fn onDispose(id: Index) void {
    if (System.get(id).onDispose) |onDisp| {
        onDisp();
    }
}
