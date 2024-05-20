const std = @import("std");
const firefly = @import("firefly/firefly.zig");

const Index = firefly.utils.Index;
const StringBuffer = firefly.utils.StringBuffer;
const DynArray = firefly.utils.DynArray;

test {
    std.testing.refAllDecls(@import("firefly/utils/testing.zig"));
}

test "init firefly" {
    const init_context = firefly.api.InitContext{
        .allocator = std.testing.allocator,
        .entity_allocator = std.testing.allocator,
        .component_allocator = std.testing.allocator,
    };

    try firefly.init(init_context);
    defer firefly.deinit();
}

test "Tasks" {
    const init_context = firefly.api.InitContext{
        .allocator = std.testing.allocator,
        .entity_allocator = std.testing.allocator,
        .component_allocator = std.testing.allocator,
    };

    try firefly.init(init_context);
    defer firefly.deinit();

    var attrs1 = firefly.api.Attributes.new();
    attrs1.set("attr1", "value1");
    attrs1.set("attr2", "value2");

    var attrs2 = firefly.api.Attributes.new();
    attrs2.set("attr3", "value3");
    attrs2.set("attr2", "Override");
    defer attrs2.deinit();

    var task: *firefly.api.Task = firefly.api.Task.newAnd(.{
        .name = "Task1",
        .function = task1,
        .callback = callback1,
        .blocking = false,
        .attributes = attrs1,
    });

    task.runWith(12345, attrs2);

    std.time.sleep(2 * std.time.ns_per_s);
}

fn task1(id: ?Index, attrs: ?firefly.api.Attributes) void {
    std.debug.print("\nTask 1 running: id: {?d}, attrs: {?any}\n", .{ id, attrs });
    std.time.sleep(1 * std.time.ns_per_s);
}

fn callback1(id: Index) void {
    std.debug.print("\nTask {} executed\n", .{id});
}

test "Trigger" {
    const init_context = firefly.api.InitContext{
        .allocator = std.testing.allocator,
        .entity_allocator = std.testing.allocator,
        .component_allocator = std.testing.allocator,
    };

    try firefly.init(init_context);
    defer firefly.deinit();

    var attrs1 = firefly.api.Attributes.new();
    attrs1.set("attr1", "value1");
    attrs1.set("attr2", "value2");

    const task_id = firefly.api.Task.new(.{
        .name = "Task1",
        .function = task1,
    });

    _ = firefly.api.Trigger.newAnd(.{
        .name = "testTrigger",
        .condition = triggerCondition,
        .attributes = attrs1,
        .task_ref = task_id,
        .component_ref = 100,
    }).activate();

    const UPDATE_EVENT = firefly.api.UpdateEvent{};
    firefly.api.update(UPDATE_EVENT);
    firefly.api.update(UPDATE_EVENT);
    firefly.api.update(UPDATE_EVENT);
}

fn triggerCondition(_: Index, _: ?firefly.api.Attributes) bool {
    const count = struct {
        var c: usize = 0;
    };

    count.c += 1;
    return count.c > 2;
}

//////////////////////////////////////////////////////////////////////////
////Builder Pattern
//////////////////////////////////////////////////////////////////////////

const Object1 = struct {
    a1: usize = 0,
    a2: usize = 0,
    list: firefly.utils.DynIndexArray = undefined,
    object: ?*Object2 = null,

    var objects1: DynArray(Object1) = undefined;

    fn init() void {
        objects1 = DynArray(Object1).new(std.testing.allocator) catch unreachable;
    }
    fn deinit() void {
        objects1.deinit();
    }

    pub fn new(object1: Object1) *Object1 {
        var result: *Object1 = objects1.addAndGet(object1).ref;
        result.list = firefly.utils.DynIndexArray.init(std.testing.allocator, 5);
        return result;
    }

    pub fn withItem(self: *Object1, item: usize) *Object1 {
        self.list.add(item);
        return self;
    }

    pub fn withA1(self: *Object1, a1: usize) *Object1 {
        self.a1 = a1;
        return self;
    }

    pub fn withA2(self: *Object1, a2: usize) *Object1 {
        self.a2 = a2;
        return self;
    }

    pub fn withObject2(self: *Object1, object: *Object2) *Object1 {
        self.object = object;
        return self;
    }
};

const Object2 = struct {
    a1: usize = 0,
    a2: usize = 0,

    var objects2: DynArray(Object2) = undefined;

    fn init() void {
        objects2 = DynArray(Object2).new(std.testing.allocator) catch unreachable;
    }
    fn deinit() void {
        objects2.deinit();
    }

    pub fn new(object2: Object2) *Object2 {
        return objects2.addAndGet(object2).ref;
    }

    pub fn withA1(self: *Object2, a1: usize) *Object2 {
        self.a1 = a1;
        return self;
    }

    pub fn withA2(self: *Object2, a2: usize) *Object2 {
        self.a2 = a2;
        return self;
    }
};

test "builder pattern" {
    Object1.init();
    defer Object1.deinit();
    Object2.init();
    defer Object2.deinit();

    const object1: *Object1 = Object1.new(.{})
        .withA1(100)
        .withA2(200)
        .withItem(1)
        .withObject2(Object2.new(.{})
        .withA1(300)
        .withA2(400))
        .withItem(2);
    defer object1.list.deinit();

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    sb.print("{}", .{object1.list});
    try std.testing.expectEqualStrings(
        "DynIndexArray[ 1,2, ]",
        sb.toString(),
    );
}
