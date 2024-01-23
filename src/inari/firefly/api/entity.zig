const std = @import("std");
const api = @import("api.zig");

const Allocator = std.mem.Allocator;
const firefly = api.firefly;
const component = firefly.api.component;
const ComponentPool = firefly.api.component.ComponentPool;
const AspectGroup = firefly.utils.aspect.AspectGroup;
const aspect = firefly.utils.aspect;
const Kind = aspect.Kind;
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
    ENTITY_COMPONENT_TYPE_ASPECT_GROUP = try aspect.newAspectGroup("ENTITY_COMPONENT_TYPE_ASPECT_GROUP");
    pool = component.ComponentPool(Entity).init(null_value, true, true);
    // TODO
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
    pool.deinit();
    aspect.disposeAspectGroup("ENTITY_COMPONENT_TYPE_ASPECT_GROUP");
    pool = undefined;
    ENTITY_COMPONENT_TYPE_ASPECT_GROUP = undefined;
    // TODO
}

// type references
pub const Entity = @This();
pub const EventType = component.CompLifecycleEvent(Entity);
pub const EventListener = *const fn (EventType) void;

// type fields
pub const null_value = Entity{};
pub var ENTITY_COMPONENT_TYPE_ASPECT_GROUP: *AspectGroup = undefined;
pub var pool: *ComponentPool(Entity) = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
kind: Kind = undefined,
