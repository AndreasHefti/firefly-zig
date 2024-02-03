const std = @import("std");

const firefly = @import("firefly.zig");
const api = @import("api/api.zig"); // TODO module
const utils = api.utils;
const Component = api.Component;
const ComponentPool = api.Component.ComponentPool;
const CompLifecycleEvent = Component.CompLifecycleEvent;
const Aspect = utils.aspect.Aspect;
const String = utils.String;
const FFAPIError = FFAPIError;
const Color = utils.geom.Color;
const PosF = utils.geom.PosF;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;
const ExampleComponent = @This();

// component type fields
pub const NULL_VALUE = ExampleComponent{};
pub const COMPONENT_NAME = "ExampleComponent";
pub const pool = ComponentPool(ExampleComponent);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (ExampleComponent) *ExampleComponent = undefined;
pub var exists: *const fn (usize) bool = undefined;
pub var existsName: *const fn (String) bool = undefined;
pub var get: *const fn (usize) *ExampleComponent = undefined;
pub var byId: *const fn (usize) *const ExampleComponent = undefined;
pub var byName: *const fn (String) *const ExampleComponent = undefined;
pub var activateById: *const fn (usize, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (usize) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
color: Color = Color{ 0, 0, 0, 255 },
position: PosF = PosF{ 0, 0 },

// methods
pub fn activate(self: ExampleComponent, active: bool) void {
    pool.activate(self.index, active);
}

pub fn onDispose(index: usize) void {
    std.testing.expect(index != UNDEF_INDEX) catch unreachable;
}

// Testing
test "initialization" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    Component.registerComponent(ExampleComponent);

    var newC = ExampleComponent.new(ExampleComponent{
        .color = Color{ 1, 2, 3, 255 },
        .position = PosF{ 10, 20 },
    });
    var newCPtr = ExampleComponent.byId(newC.index);
    //try std.testing.expectEqual(newC, newCPtr);
    try std.testing.expectEqual(newC.*, newCPtr.*);
    try std.testing.expectEqual(@as(String, "ExampleComponent"), ExampleComponent.pool.c_aspect.name);
}

test "create/dispose component" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    Component.registerComponent(ExampleComponent);

    var cPtr = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });

    try std.testing.expect(cPtr.index == 0);

    try std.testing.expect(ExampleComponent.pool.count() == 1);
    try std.testing.expect(ExampleComponent.pool.activeCount() == 0);

    try std.testing.expect(cPtr.color[0] == 0);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 10);
    try std.testing.expect(cPtr.position[1] == 10);

    cPtr.position[0] = 111;

    try std.testing.expect(cPtr.color[0] == 0);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 111);
    try std.testing.expect(cPtr.position[1] == 10);

    cPtr.activate(true);

    try std.testing.expect(ExampleComponent.pool.count() == 1);
    try std.testing.expect(ExampleComponent.pool.activeCount() == 1);

    var editableCPtr = ExampleComponent.get(cPtr.index);

    try std.testing.expect(editableCPtr.index == 0);
    try std.testing.expect(editableCPtr.color[0] == 0);
    try std.testing.expect(editableCPtr.color[1] == 0);
    try std.testing.expect(editableCPtr.color[2] == 0);
    try std.testing.expect(editableCPtr.color[3] == 255);
    try std.testing.expect(editableCPtr.position[0] == 111);
    try std.testing.expect(editableCPtr.position[1] == 10);

    editableCPtr.color[0] = 255;

    try std.testing.expect(cPtr.color[0] == 255);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 111);
    try std.testing.expect(cPtr.position[1] == 10);

    ExampleComponent.disposeById(editableCPtr.index);

    try std.testing.expect(cPtr.color[0] == 0);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 0);
    try std.testing.expect(cPtr.position[1] == 0);

    try std.testing.expect(ExampleComponent.pool.count() == 0);
    try std.testing.expect(ExampleComponent.pool.activeCount() == 0);
}

test "name mapping" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    Component.registerComponent(ExampleComponent);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    _ = c1;

    var c2 = ExampleComponent.new(.{
        .name = "c2",
        .color = Color{ 2, 0, 0, 255 },
        .position = PosF{ 20, 20 },
    });

    try std.testing.expect(ExampleComponent.existsName("c2"));
    try std.testing.expect(!ExampleComponent.existsName("c1"));

    var _c2 = ExampleComponent.byName("c2");
    var c3 = ExampleComponent.byName("c3"); // c3 doesn't exists so it gives back the NULL VALUE

    try std.testing.expect(_c2.index != NULL_VALUE.index);
    try std.testing.expectEqual(c2.*, _c2.*);
    try std.testing.expect(c3.index == NULL_VALUE.index);
    try std.testing.expectEqual(c3.*, NULL_VALUE);
}

test "event propagation" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    Component.registerComponent(ExampleComponent);

    // also triggers auto init
    ExampleComponent.subscribe(testListener);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    c1.activate(true);
    c1.activate(false);
}

fn testListener(event: Component.Event) void {
    std.debug.print("received: {any}\n", .{event});
}

test "get poll and process" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    Component.registerComponent(ExampleComponent);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    c1.activate(true);

    var c2 = ExampleComponent.new(.{
        .color = Color{ 2, 0, 0, 255 },
        .position = PosF{ 20, 20 },
    });
    _ = c2;

    var c3 = ExampleComponent.new(.{
        .color = Color{ 0, 5, 0, 255 },
        .position = PosF{ 40, 70 },
    });

    process();

    // var ptr = component.CompPoolPtr{
    //     .aspect = ExampleComponent.pool.c_aspect,
    //     .address = @intFromPtr(ExampleComponent.pool),
    // };
    // _ = ptr;

    var compId = Component.ComponentId{
        .aspect = ExampleComponent.type_aspect,
        .index = c3.index,
    };
    _ = compId;

    //component.processById(ExampleComponent, &compId, processOne);

    //processViaIdCast(compId);
}

// fn processViaIdCast(id: component.ComponentId) void {
//     if (ComponentPool(ExampleComponent).typeCheck(id.aspect)) {
//         var arr = [1]usize{id.cIndex};
//         id.cTypePtr.cast(ComponentPool(ExampleComponent)).processIndexed(&arr, processOne);
//     }
// }

fn process() void {
    ExampleComponent.pool.processActive(processOne);
}

fn processOne(c: *ExampleComponent) void {
    std.debug.print("process {any}\n", .{c});
}

fn processOneUnknown(c: anytype) void {
    std.debug.print("process {any}\n", .{c});
}
