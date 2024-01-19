const std = @import("std");
pub const utils = @import("../utils/utils.zig"); // TODO better way for import package?
pub const component = @import("component.zig");
pub const system = @import("system.zig");
pub const Allocator = std.mem.Allocator;

pub const FFAPIError = error{
    GenericError,
    SingletonAlreadyInitialized,
    ComponentInitError,
    GraphicsInitError,
    GraphicsError,
};

pub const ActionType = enum {
    CREATED,
    ACTIVATED,
    DEACTIVATED,
    DISPOSED,
};

// module initialization
var INIT = false;
pub var COMPONENT_ALLOC: Allocator = undefined;
pub var ENTITY_ALLOC: Allocator = undefined;
pub var ALLOC: Allocator = undefined;

pub fn moduleInit(allocator: Allocator) !void {
    defer INIT = true;
    if (INIT) {
        return;
    }
    COMPONENT_ALLOC = allocator;
    ENTITY_ALLOC = allocator;
    ALLOC = allocator;
    try utils.aspect.aspectInit(allocator);
    try component.componentInit(allocator);
}

pub fn moduleInitAlloc(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    defer INIT = true;
    if (INIT) {
        return;
    }
    COMPONENT_ALLOC = component_allocator;
    ENTITY_ALLOC = entity_allocator;
    ALLOC = allocator;
    try utils.aspect.aspectInit(allocator);
    try component.componentInit(allocator);
}

pub fn moduleDeinit() void {
    defer INIT = false;
    if (!INIT) {
        return;
    }
    utils.aspect.aspectDeinit();
    component.componentDeinit();
}

test {
    std.testing.refAllDecls(@import("api/api.zig"));
    std.testing.refAllDecls(@import("system.zig"));
    std.testing.refAllDecls(@import("component.zig"));
    std.testing.refAllDecls(@import("ExampleComponent.zig"));
}
