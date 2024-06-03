const std = @import("std");
const firefly = @import("firefly/firefly.zig");

const String = firefly.utils.String;
const Index = firefly.utils.Index;
const StringBuffer = firefly.utils.StringBuffer;
const DynArray = firefly.utils.DynArray;

test {
    std.testing.refAllDecls(@import("firefly/utils/testing.zig"));
}

const init_context = firefly.api.InitContext{
    .allocator = std.testing.allocator,
    .entity_allocator = std.testing.allocator,
    .component_allocator = std.testing.allocator,
};

test "init firefly" {
    try firefly.init(init_context);
    defer firefly.deinit();
}

test "Attributes" {
    try firefly.init(init_context);
    defer firefly.deinit();

    var attrs1 = firefly.api.CallAttributes{};
    defer attrs1.deinit();

    attrs1.setProperty("param1", "value1");
    attrs1.setProperty("param2", "value2");
    attrs1.setProperty("param3", "value3");
    attrs1.setProperty("param4", "value4");

    try std.testing.expectEqualStrings("value2", attrs1.getProperty("param2").?);
    try std.testing.expect(attrs1.properties.?.unmanaged.size == 4);

    attrs1.deleteProperty("param1");
    try std.testing.expect(attrs1.properties.?.unmanaged.size == 3);
}

test "Tasks" {
    try firefly.init(init_context);
    defer firefly.deinit();

    var attrs1 = firefly.api.CallAttributes{};
    defer attrs1.deinit();
    attrs1.setProperty("attr1", "value1");
    attrs1.setProperty("attr2", "value2");

    var attrs2 = firefly.api.CallAttributes{};
    defer attrs2.deinit();
    attrs2.setProperty("attr3", "value3");
    attrs2.setProperty("attr2", "Override");

    var task: *firefly.api.Task = firefly.api.Task.new(.{
        .name = "Task1",
        .function = task1,
        .callback = callback1,
        .blocking = false,
        .attributes = attrs1,
    });

    task.runWith(&attrs2);

    std.time.sleep(2 * std.time.ns_per_s);
}

fn task1(attrs: *firefly.api.CallAttributes) void {
    std.debug.print("\nTask 1 running: attrs: {?any}\n", .{attrs});
    std.time.sleep(1 * std.time.ns_per_s);
}

fn callback1(attrs: *firefly.api.CallAttributes) void {
    std.debug.print("\nTask {} executed\n", .{attrs});
}

test "CCondition" {
    try firefly.init(init_context);
    defer firefly.deinit();

    _ = firefly.api.CCondition.new(.{
        .name = "Condition1",
        .condition = .{ .f = condition1 },
    });

    _ = firefly.api.CCondition.new(.{
        .name = "Condition2",
        .condition = .{ .f = condition2 },
    });

    _ = firefly.api.CCondition.newANDByName("Condition1 AND Condition2", "Condition1", "Condition2");
    _ = firefly.api.CCondition.newORByName("Condition1 OR Condition2", "Condition1", "Condition2");

    try std.testing.expect(firefly.api.CCondition.checkByName("Condition1", null));
    try std.testing.expect(!firefly.api.CCondition.checkByName("Condition2", null));
    try std.testing.expect(!firefly.api.CCondition.checkByName("Condition1 AND Condition2", null));
    try std.testing.expect(firefly.api.CCondition.checkByName("Condition1 OR Condition2", null));
}

fn condition1(_: ?*firefly.api.CallAttributes) bool {
    return true;
}
fn condition2(_: ?*firefly.api.CallAttributes) bool {
    return false;
}

test "Trigger" {
    try firefly.init(init_context);
    defer firefly.deinit();

    var attrs1 = firefly.api.CallAttributes{ .c1_id = 300 };
    defer attrs1.deinit();
    attrs1.setProperty("attr1", "value1");
    attrs1.setProperty("attr2", "value2");

    const task_id = firefly.api.Task.new(.{
        .name = "Task1",
        .function = task1,
    }).id;

    const c_id = firefly.api.CCondition.new(.{
        .name = "TestCondition",
        .condition = .{ .f = triggerCondition },
    }).id;

    _ = firefly.api.Trigger.new(.{
        .name = "testTrigger",
        .condition_ref = c_id,
        .attributes = attrs1,
        .task_ref = task_id,
    }).activate();

    const UPDATE_EVENT = firefly.api.UpdateEvent{};
    firefly.api.update(UPDATE_EVENT);
    firefly.api.update(UPDATE_EVENT);
    firefly.api.update(UPDATE_EVENT);
}

fn triggerCondition(_: ?*firefly.api.CallAttributes) bool {
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
        objects1 = DynArray(Object1).new(std.testing.allocator);
    }
    fn deinit() void {
        objects1.deinit();
    }

    pub fn new(object1: Object1) *Object1 {
        var result: *Object1 = objects1.addAndGet(object1).ref;
        result.list = firefly.utils.DynIndexArray.new(std.testing.allocator, 5);
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
        objects2 = DynArray(Object2).new(std.testing.allocator);
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

//////////////////////////////////////////////////////////////////////////
////Repl tests
//////////////////////////////////////////////////////////////////////////

test "zim mem String vs heap Strings" {
    const zigMemString: String = getNoneHeapString();
    const heapString: String = std.testing.allocator.dupe(u8, "This is a String on heap mem and has therefore to be freed right?") catch unreachable;
    defer std.testing.allocator.free(heapString);

    try std.testing.expectEqualStrings(
        "This is a String on none heap mem and has not to be freed right?",
        zigMemString,
    );

    try std.testing.expectEqualStrings(
        "This is a String on heap mem and has therefore to be freed right?",
        heapString,
    );

    // But how can we check later on if String lives on heap and has to be freed or not?
}

fn getNoneHeapString() String {
    return "This is a String on none heap mem and has not to be freed right?";
}
