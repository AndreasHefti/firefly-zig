const std = @import("std");
const firefly = @import("firefly.zig");

const component = firefly.component;
const ComponentPool = firefly.component.ComponentPool;
const String = firefly.utils.String;
const FFAPIError = firefly.FFAPIError;
const Color = firefly.utils.geom.Color;
const PosF = firefly.utils.geom.PosF;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

// private type fields
var initialized: bool = false;

// type fields
pub const ExampleComponent = @This();
pub const null_value = ExampleComponent{};
pub const pool = ComponentPool(ExampleComponent);

// struct fields
index: usize = UNDEF_INDEX,
color: Color = Color{ 0, 0, 0, 255 },
position: PosF = PosF{ 0, 0 },

// constructor destructor
fn init() void {
    defer initialized = true;
    if (initialized) return;
    component.registerComponentType(&ExampleComponent);
}

pub fn deinit() void {
    defer initialized = false;
    if (initialized) pool.deinit();
}

// type functions
pub fn get(index: usize) *ExampleComponent {
    return pool.items.get(index);
}

pub fn new(c: ExampleComponent) *ExampleComponent {
    if (!initialized) init();
    return pool.reg(c);
}

// methods
pub fn activate(self: ExampleComponent, active: bool) void {
    if (active) {
        pool.activate(self.index);
    } else {
        pool.deactivate(self.index);
    }
}

pub fn clear(self: *ExampleComponent) void {
    pool.clear(self.index);
    self.index = UNDEF_INDEX;
    self.color = Color{ 0, 0, 0, 255 };
    self.position = PosF{ 0, 0 };
}

// Testing
test "initialization" {
    std.debug.print("\n", .{});
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();

    ExampleComponent.init();
}

test "auto-initialization" {
    std.debug.print("\n", .{});
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();

    // not initialized yet... gives null values every time
    var c = ExampleComponent.get(100);
    try std.testing.expectEqual(null_value, c.*);

    // new triggers auto initialization
    var newC = ExampleComponent.new(ExampleComponent{
        .color = Color{ 1, 2, 3, 255 },
        .position = PosF{ 10, 20 },
    });
    var newCPtr = ExampleComponent.get(newC.index);
    try std.testing.expectEqual(newC, newCPtr);
    try std.testing.expectEqual(newC.*, newCPtr.*);
}

test "create/dispose component" {
    std.debug.print("\n", .{});

    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();

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

    var otherCPtr = ExampleComponent.get(cPtr.index);

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

    otherCPtr.clear();

    try std.testing.expect(cPtr.color[0] == 0);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 0);
    try std.testing.expect(cPtr.position[1] == 0);

    try std.testing.expect(ExampleComponent.pool.count() == 0);
    try std.testing.expect(ExampleComponent.pool.activeCount() == 0);
}
