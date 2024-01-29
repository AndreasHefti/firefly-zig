const std = @import("std");
pub const utils = @import("../utils/utils.zig"); // TODO better way for import package?
pub const api = @import("api/api.zig");
pub const graphics = @import("graphics/graphics.zig");
pub const component = api.component;
pub const system = api.system;
pub const rendering_api = api.rendering_api;

pub const Asset = @import("Asset.zig");
pub const Entity = @import("Entity.zig");

pub const Allocator = std.mem.Allocator;

pub const FFAPIError = error{
    GenericError,
    SingletonAlreadyInitialized,
    ComponentInitError,
    RenderingInitError,
    RenderingError,
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

pub var RENDER_API: rendering_api.RenderAPI() = undefined;

pub fn moduleInitDebug(allocator: Allocator) !void {
    defer INIT = true;
    if (INIT) {
        return;
    }
    COMPONENT_ALLOC = allocator;
    ENTITY_ALLOC = allocator;
    ALLOC = allocator;
    RENDER_API = try rendering_api.createDebugRenderAPI(ALLOC);
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
    // TODO init default rendering_api impl here when available
    RENDER_API = try rendering_api.createDebugRenderAPI(ALLOC);
    try initModules();
}

fn initModules() !void {
    // init root modules
    try utils.aspect.init(ALLOC);
    try api.init();
    try Asset.init();

    // register default components and entity components
    component.registerComponent(Asset);
    component.registerComponent(Entity);

    // init depending modules
    try graphics.init();
}

pub fn moduleDeinit() void {
    defer INIT = false;
    if (!INIT)
        return;

    graphics.deinit();
    RENDER_API.deinit();
    Asset.deinit();
    api.deinit();
    utils.aspect.deinit();
}

test {
    std.testing.refAllDecls(@import("api/api.zig"));
    std.testing.refAllDecls(@import("graphics/graphics.zig"));
    std.testing.refAllDecls(@import("ExampleComponent.zig"));
}

test "init" {
    try moduleInitDebug(std.testing.allocator);
    defer moduleDeinit();
    var sb = utils.StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    //sb.append("\n");
    utils.aspect.print(&sb);
    api.component.print(&sb);

    //try std.io.getStdErr().writer().writeAll(sb.toString());

    var output: utils.String =
        \\Aspects:
        \\  Group[COMPONENT_ASPECT_GROUP|0]:
        \\    Aspect[Asset|0]
        \\    Aspect[Entity|1]
        \\  Group[ENTITY_COMPONENT_ASPECT_GROUP|1]:
        \\  Group[Asset|2]:
        \\    Aspect[Texture|0]
        \\
        \\Components:
        \\  Asset size: 0
        \\  Entity size: 0
    ;
    //try std.io.getStdErr().writer().writeAll(output);

    try std.testing.expectEqualStrings(output, sb.toString());
}
