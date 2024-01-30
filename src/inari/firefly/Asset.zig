const std = @import("std");
const firefly = @import("firefly.zig");

const Allocator = std.mem.Allocator;
const component = firefly.api.component;
const ComponentPool = firefly.api.component.ComponentPool;
const AspectGroup = firefly.utils.aspect.AspectGroup;
const aspect = firefly.utils.aspect;
const Aspect = aspect.Aspect;
const String = firefly.utils.String;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_NAME = firefly.utils.NO_NAME;
const BindingIndex = firefly.api.BindingIndex;
const Asset = @This();

// type aspects
var initialized = false;
pub var ASSET_TYPE_ASPECT_GROUP: *AspectGroup = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    ASSET_TYPE_ASPECT_GROUP = try aspect.newAspectGroup(component_name);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    aspect.disposeAspectGroup(component_name);
    ASSET_TYPE_ASPECT_GROUP = undefined;
    pool.deinit();
}

// type fields
pub const null_value = Asset{};
pub const component_name = "Asset";
pub const pool = ComponentPool(Asset);

// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Asset) *Asset = undefined;
pub var byId: *const fn (usize) *Asset = undefined;
pub var byName: *const fn (String) ?*Asset = undefined;
pub var activateById: *const fn (usize, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (usize) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (component.EventListener) void = undefined;
pub var unsubscribe: *const fn (component.EventListener) void = undefined;

// struct fields
index: usize = UNDEF_INDEX,
asset_type: *Aspect = undefined,
name: String = NO_NAME,
resource_id: usize = UNDEF_INDEX,
binding_by_index: *const fn (self: *Asset, index: usize) BindingIndex = undefined,
binding_by_name: *const fn (self: *Asset, name: String) BindingIndex = undefined,

pub fn binding(self: *Asset) BindingIndex {
    return self.binding_by_index(self, 0);
}

pub fn bindingByName(self: *Asset, name: String) BindingIndex {
    return self.binding_by_name(self, name);
}

pub fn bindingByIndex(self: *Asset, index: usize) BindingIndex {
    return self.binding_by_index(self, index);
}
