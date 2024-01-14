const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// Event dispatcher implemented as type based singleton
fn EventDispatch(comptime E: type) type {
    return struct {
        const Self = @This();
        var initialized = false;

        const Listener = *const fn (E) void;

        var listeners: ArrayList(Listener) = undefined;

        pub fn init(allocator: Allocator) void {
            if (!initialized) {
                listeners = ArrayList(Listener).init(allocator);
                initialized = true;
            }
        }

        pub fn deinit() void {
            if (initialized) {
                listeners.deinit();
                listeners = undefined;
                initialized = false;
            }
        }

        pub fn register(listener: Listener) !void {
            checkInit();
            try listeners.append(listener);
        }

        pub fn unregister(listener: Listener) void {
            checkInit();
            for (0..listeners.items.len) |i| {
                if (listeners.items[i] == listener) {
                    listeners.swapRemove(i);
                    return;
                }
            }
        }

        pub fn notify(event: E) void {
            checkInit();
            for (0..listeners.items.len) |i| {
                listeners.items[i](event);
            }
        }

        fn checkInit() void {
            if (!initialized) {
                @panic("EventDispatch of type not initialized.");
            }
        }
    };
}

test "Events and Listeners" {
    EventDispatch([]const u8).init(std.testing.allocator);
    defer EventDispatch([]const u8).deinit();

    try EventDispatch([]const u8).register(testlistener1);
    try EventDispatch([]const u8).register(testlistener2);

    EventDispatch([]const u8).notify("hallo1");

    EventDispatch([]const u8).notify("hallo2");
}

fn testlistener1(event: []const u8) void {
    std.debug.print("\n  testlistener1 event: {s}\n", .{event});
}

fn testlistener2(event: []const u8) void {
    std.debug.print("  testlistener2 event: {s}\n", .{event});
}
