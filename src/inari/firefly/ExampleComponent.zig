const std = @import("std");
const firefly = @import("firefly.zig");

const component = firefly.api.component;
const ComponentPool = firefly.api.component.ComponentPool;
const CompLifecycleEvent = component.CompLifecycleEvent;
const Aspect = firefly.utils.aspect.Aspect;
const String = firefly.utils.String;
const FFAPIError = firefly.FFAPIError;
const Color = firefly.utils.geom.Color;
const PosF = firefly.utils.geom.PosF;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_NAME = firefly.utils.NO_NAME;
const ExampleComponent = @This();

// component type fields
pub const null_value = ExampleComponent{};
pub const component_name = "ExampleComponent";
pub const pool = ComponentPool(ExampleComponent);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (ExampleComponent) *ExampleComponent = undefined;
pub var dispose: *const fn (usize) void = undefined;
pub var byId: *const fn (usize) *ExampleComponent = undefined;
pub var byName: *const fn (String) ?*ExampleComponent = undefined;
pub var activateById: *const fn (usize, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var subscribe: *const fn (component.EventListener) void = undefined;
pub var unsubscribe: *const fn (component.EventListener) void = undefined;

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
    std.debug.print("\n**************** onDispose: {d}\n", .{index});
}

// Testing
test "initialization" {
    std.debug.print("\n", .{});
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    component.registerComponent(ExampleComponent);

    var newC = ExampleComponent.new(ExampleComponent{
        .color = Color{ 1, 2, 3, 255 },
        .position = PosF{ 10, 20 },
    });
    var newCPtr = ExampleComponent.byId(newC.index);
    try std.testing.expectEqual(newC, newCPtr);
    try std.testing.expectEqual(newC.*, newCPtr.*);
    try std.testing.expectEqual(@as(String, "ExampleComponent"), ExampleComponent.pool.c_aspect.name);
}

test "create/dispose component" {
    std.debug.print("\n", .{});

    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    component.registerComponent(ExampleComponent);

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

    var otherCPtr = ExampleComponent.byId(cPtr.index);

    try std.testing.expect(otherCPtr.index == 0);
    try std.testing.expect(otherCPtr.color[0] == 0);
    try std.testing.expect(otherCPtr.color[1] == 0);
    try std.testing.expect(otherCPtr.color[2] == 0);
    try std.testing.expect(otherCPtr.color[3] == 255);
    try std.testing.expect(otherCPtr.position[0] == 111);
    try std.testing.expect(otherCPtr.position[1] == 10);

    otherCPtr.color[0] = 255;

    try std.testing.expect(cPtr.color[0] == 255);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 111);
    try std.testing.expect(cPtr.position[1] == 10);

    ExampleComponent.dispose(otherCPtr.index);

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
    component.registerComponent(ExampleComponent);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });

    var c2 = ExampleComponent.new(.{
        .name = "c2",
        .color = Color{ 2, 0, 0, 255 },
        .position = PosF{ 20, 20 },
    });

    var _c2 = ExampleComponent.pool.byName("c2");
    var _c1_ = ExampleComponent.pool.byName(c1.name);

    try std.testing.expect(_c2 != null);
    try std.testing.expectEqual(c2, _c2.?);
    try std.testing.expect(_c1_ == null);
}

test "event propagation" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    component.registerComponent(ExampleComponent);

    // also triggers auto init
    ExampleComponent.subscribe(testListener);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    c1.activate(true);
    c1.activate(false);
}

fn testListener(event: component.Event) void {
    std.debug.print("\n received: {any}\n", .{event});
}

test "get poll and process" {
    std.debug.print("\n", .{});

    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    component.registerComponent(ExampleComponent);

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

    var compId = component.ComponentId{
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
    std.debug.print("\n process {any}\n", .{c});
}

fn processOneUnknown(c: anytype) void {
    std.debug.print("\n process {any}\n", .{c});
}

// test "generic pool access" {
//     std.debug.print("\n", .{});

//     try firefly.moduleInitDebug(std.testing.allocator);
//     defer firefly.moduleDeinit();
//     ExampleComponent.init();

//     var aspect = with(ExampleComponent{
//         .color = Color{ 0, 5, 0, 255 },
//         .position = PosF{ 40, 70 },
//     });
//     _ = aspect;
// }

// pub fn with(c: anytype) *Aspect {
//     const T = @TypeOf(c);
//     _ = component.ComponentPool(T).register(@as(T, c));
//     return T.pool.c_aspect;
// }
