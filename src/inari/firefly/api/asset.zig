const std = @import("std");
const api = @import("api.zig");

const Allocator = std.mem.Allocator;
const firefly = api.firefly;
const component = firefly.api.component;
const ComponentPool = firefly.api.component.ComponentPool;
const AspectGroup = firefly.utils.aspect.AspectGroup;
const aspect = firefly.utils.aspect;
const Aspect = aspect.Aspect;
const String = firefly.utils.String;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_NAME = firefly.utils.NO_NAME;

// asset module init/deinit
var initialized: bool = false;

pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;
    ASSET_TYPE_ASPECT_GROUP = try aspect.newAspectGroup("ASSET_TYPE_ASPECT_GROUP");
    pool = component.ComponentPool(Asset).init(null_value, "Asset", true, true);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
    pool.deinit();
    aspect.disposeAspectGroup("ASSET_TYPE_ASPECT_GROUP");
    pool = undefined;
    ASSET_TYPE_ASPECT_GROUP = undefined;
}

// type references
pub const Asset = @This();
pub const EventType = component.CompLifecycleEvent(Asset);
pub const EventListener = *const fn (EventType) void;

// type fields
pub const null_value = Asset{};
pub var ASSET_TYPE_ASPECT_GROUP: *AspectGroup = undefined;
pub var pool: *ComponentPool(Asset) = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
resource: String = NO_NAME,
resource_id: usize = UNDEF_INDEX,
asset_type: *Aspect = undefined,
asset_id: usize = UNDEF_INDEX,
fn_activate: *const fn () bool = undefined,
fn_deactivate: *const fn () void = undefined,

pub fn subscribe(listener: EventListener) void {
    pool.subscribe(listener);
}

pub fn unsubscribe(listener: EventListener) void {
    pool.unsubscribe(listener);
}

// type functions
pub fn byIndex(index: usize) *Asset {
    return pool.get(index);
}

pub fn byName(name: String) *Asset {
    return pool.getByName(name);
}

pub fn new(c: Asset) *Asset {
    return pool.reg(c);
}

pub fn activateByIndex(index: usize, active: bool) void {
    pool.get(index).activate(active);
}

pub fn activateByName(name: String, active: bool) void {
    pool.getByName(name).activate(active);
}

// methods
pub fn activate(self: *Asset, active: bool) void {
    if (active) {
        if (self.fn_activate()) pool.activate(self.index, active);
    } else {
        if (self.fn_deactivate()) pool.activate(self.index, active);
    }
}

pub fn isActive(self: *Asset) bool {
    return pool.isActive(self.index);
}
