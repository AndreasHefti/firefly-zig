const std = @import("std");
const Allocator = std.mem.Allocator;

// TODO make modules
pub const utils = @import("../utils/utils.zig");
//pub const utils = @import("utils");
pub const api = @import("api/api.zig");
pub const graphics = @import("graphics/graphics.zig");

// pub const component = api.Component;
// pub const system = api.system;
// pub const rendering_api = api.rendering_api;

//pub const Asset = @import("Asset.zig");
//pub const Entity = @import("Entity.zig");

//pub var RENDER_API: rendering_api.RenderAPI() = undefined;
var initialized = false;
pub fn moduleInitDebug(allocator: Allocator) !void {
    defer initialized = true;
    if (initialized)
        return;

    //RENDER_API = try rendering_api.createDebugRenderAPI(ALLOC);
    try initModules(allocator, allocator, allocator);
}

pub fn moduleInitAlloc(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    defer initialized = true;
    if (initialized)
        return;

    // TODO init default rendering_api impl here when available
    //RENDER_API = try rendering_api.createDebugRenderAPI(ALLOC);
    try initModules(component_allocator, entity_allocator, allocator);
}

fn initModules(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    // init root modules
    try utils.aspect.init(allocator);
    try api.init(component_allocator, entity_allocator, allocator);
    try graphics.init(component_allocator, entity_allocator, allocator);
}

pub fn moduleDeinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    graphics.deinit();
    api.deinit();
    utils.aspect.deinit();
}

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(@import("ExampleComponent.zig"));
}

test "Firefly init" {
    try moduleInitDebug(std.testing.allocator);
    defer moduleDeinit();
    var sb = utils.StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    utils.aspect.print(&sb);
    api.Component.print(&sb);

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

    try std.testing.expectEqualStrings(output, sb.toString());
}
