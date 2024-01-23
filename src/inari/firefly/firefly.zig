const std = @import("std");
pub const utils = @import("../utils/utils.zig"); // TODO better way for import package?
pub const api = @import("api/api.zig");
pub const component = api.component;
pub const system = api.system;
pub const asset = api.asset;
pub const graphics = api.graphics;

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
    try initModules();
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
    try initModules();
}

fn initModules() !void {
    try utils.aspect.init(ALLOC);
    system.System.init();
    try component.init();
    try asset.init();
}

pub fn moduleDeinit() void {
    defer INIT = false;
    if (!INIT) {
        return;
    }
    GRAPHICS.deinit();
    system.System.deinit();
    component.deinit();
    utils.aspect.deinit();
}

test {
    std.testing.refAllDecls(@import("api/api.zig"));
    std.testing.refAllDecls(@import("ExampleComponent.zig"));
}

test "init" {
    try moduleInitDebug(std.testing.allocator);
    defer moduleDeinit();
    try utils.aspect.print(std.io.getStdErr().writer());
}
