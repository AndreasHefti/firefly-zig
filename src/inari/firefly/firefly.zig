const std = @import("std");
pub const utils = @import("../utils/utils.zig"); // TODO better way for import package?
pub const component = @import("component.zig");
pub const system = @import("system.zig");
pub const graphics = @import("api/graphics.zig");

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

pub var GRAPHICS: graphics.GraphicsAPI() = undefined;

pub fn moduleInitDebug(allocator: Allocator) !void {
    defer INIT = true;
    if (INIT) {
        return;
    }
    COMPONENT_ALLOC = allocator;
    ENTITY_ALLOC = allocator;
    ALLOC = allocator;
    GRAPHICS = try graphics.createDebugGraphics(ALLOC);
    try utils.aspect.aspectInit(allocator);
    system.System.init();
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
    // TODO init default graphics impl here when available
    GRAPHICS = try graphics.createDebugGraphics(ALLOC);
    try utils.aspect.aspectInit(allocator);
    system.System.init();
    try component.componentInit(allocator);
}

pub fn moduleDeinit() void {
    defer INIT = false;
    if (!INIT) {
        return;
    }
    GRAPHICS.deinit();
    system.System.deinit();
    component.componentDeinit();
    utils.aspect.aspectDeinit();
}

test {
    std.testing.refAllDecls(@import("api/api.zig"));
    std.testing.refAllDecls(@import("system.zig"));
    std.testing.refAllDecls(@import("component.zig"));
    std.testing.refAllDecls(@import("ExampleComponent.zig"));
}
