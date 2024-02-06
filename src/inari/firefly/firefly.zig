const std = @import("std");
const Allocator = std.mem.Allocator;

// TODO make modules
pub const utils = @import("../utils/utils.zig");
//pub const utils = @import("utils");
pub const api = @import("api/api.zig");
pub const graphics = @import("graphics/graphics.zig");

//pub var RENDER_API: rendering_api.RenderAPI() = undefined;
var initialized = false;

pub fn moduleInitDebug(allocator: Allocator) !void {
    defer initialized = true;
    if (initialized)
        return;

    try initModules(allocator, allocator, allocator);
}

pub fn moduleInitAlloc(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    defer initialized = true;
    if (initialized)
        return;

    try initModules(component_allocator, entity_allocator, allocator);
}

fn initModules(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    // init root modules
    try graphics.init(component_allocator, entity_allocator, allocator);
}

pub fn moduleDeinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    graphics.deinit();
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
        \\    Aspect[System|1]
        \\    Aspect[Entity|2]
        \\  Group[Asset|1]:
        \\    Aspect[Texture|0]
        \\    Aspect[SpriteSet|1]
        \\    Aspect[Sprite|2]
        \\    Aspect[Shader|3]
        \\  Group[ENTITY_COMPONENT_ASPECT_GROUP|2]:
        \\
        \\Components:
        \\  Asset size: 0
        \\  System size: 0
        \\  Entity size: 0
    ;

    try std.testing.expectEqualStrings(output, sb.toString());
}
