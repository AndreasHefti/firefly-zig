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
const Asset = @This();

// type aspects
pub var ASSET_TYPE_ASPECT_GROUP: *AspectGroup = undefined;
// type fields
pub const null_value = Asset{};
pub const component_name = "Asset";
pub const pool = ComponentPool(Asset);

// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Asset) *Asset = undefined;
pub var dispose: *const fn (usize) void = undefined;
pub var byId: *const fn (usize) *Asset = undefined;
pub var byName: *const fn (String) ?*Asset = undefined;
pub var activateById: *const fn (usize, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var subscribe: *const fn (component.EventListener) void = undefined;
pub var unsubscribe: *const fn (component.EventListener) void = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
resource: String = NO_NAME,
resource_id: usize = UNDEF_INDEX,
asset_type: *Aspect = undefined,
asset_id: usize = UNDEF_INDEX,
load: *const fn (*Asset) bool = undefined,
dispose: *const fn (*Asset) void = undefined,
