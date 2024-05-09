const std = @import("std");
const firefly = @import("firefly/firefly.zig");

const Index = firefly.utils.Index;

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
    std.debug.print("\nTask 1 running: id: .{?d}, attrs: {?any}\n", .{ id, attrs });
    std.time.sleep(1 * std.time.ns_per_s);
}

fn callback1(id: Index) void {
    std.debug.print("\nTask {} executed\n", .{id});
}
