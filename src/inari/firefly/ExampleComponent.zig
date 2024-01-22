const std = @import("std");
const firefly = @import("firefly.zig");

const component = firefly.api.component;
const ComponentPool = firefly.api.component.ComponentPool;
const String = firefly.utils.String;
const FFAPIError = firefly.FFAPIError;
const Color = firefly.utils.geom.Color;
const PosF = firefly.utils.geom.PosF;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_NAME = firefly.utils.NO_NAME;

// private type fields
var initialized: bool = false;
const ExampleComponent = @This();

// type fields
//pub const ExampleComponentEvent = struct {};
pub const EventType = component.CompLifecycleEvent(ExampleComponent);
pub const EventListener = *const fn (EventType) void;
pub const null_value = ExampleComponent{};
pub var pool: *ComponentPool(ExampleComponent) = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
color: Color = Color{ 0, 0, 0, 255 },
position: PosF = PosF{ 0, 0 },

// constructor destructor
fn init() void {
    defer initialized = true;
    if (initialized) return;
    pool = component.ComponentPool(ExampleComponent).init(null_value, true, true);
}

pub fn deinit() void {
    defer initialized = false;
    if (initialized) pool.deinit();
}

pub fn subscribe(listener: EventListener) void {
    pool.subscribe(listener);
}

pub fn unsubscribe(listener: EventListener) void {
    pool.unsubscribe(listener);
}

// type functions
pub fn get(index: usize) *ExampleComponent {
    return pool.get(index);
}

pub fn new(c: ExampleComponent) *ExampleComponent {
    if (!initialized) init();
    return pool.reg(c);
}

// methods
pub fn activate(self: ExampleComponent, active: bool) void {
    pool.activate(self.index, active);
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

test "name mapping" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();
    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });

    var c2 = ExampleComponent.new(.{
        .name = "c2",
        .color = Color{ 2, 0, 0, 255 },
        .position = PosF{ 20, 20 },
    });

    var _c2 = ExampleComponent.pool.getByName("c2");
    var _c1_ = ExampleComponent.pool.getByName(c1.name);

    try std.testing.expect(_c2 != null);
    try std.testing.expectEqual(c2, _c2.?);
    try std.testing.expect(_c1_ == null);
}

test "event propagation" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();

    ExampleComponent.init();
    ExampleComponent.subscribe(testListener);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    c1.activate(true);
    c1.activate(false);
}

fn testListener(event: EventType) void {
    std.debug.print("\n %%%%%%%%%% event: {any}\n", .{event});
}

test "get poll and process" {
    std.debug.print("\n", .{});

    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();

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

    var ptr = component.CompPoolPtr{
        .aspect = ExampleComponent.pool.c_aspect,
        .address = @intFromPtr(ExampleComponent.pool),
    };
    _ = ptr;

    var compId = component.ComponentId{
        .cTypePtr = ComponentPool(ExampleComponent).typeErasedPtr,
        .cIndex = c3.index,
    };

    processViaIdCast(compId);
}

fn processViaIdCast(id: component.ComponentId) void {
    if (ComponentPool(ExampleComponent).typeCheck(id.cTypePtr.aspect)) {
        var arr = [1]usize{id.cIndex};
        id.cTypePtr.cast(ComponentPool(ExampleComponent)).processIndexed(&arr, processOne);
    }
}

fn process() void {
    ExampleComponent.pool.processAllActive(processOne);
}

fn processOne(c: *ExampleComponent) void {
    std.debug.print("\n process ExampleComponent {any}\n", .{c});
}
