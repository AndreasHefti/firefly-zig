const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// Event dispatcher implemented as type based singleton
pub fn EventDispatch(comptime E: type) type {
    return struct {
        const Self = @This();
        // ensure type based singleton
        var initialized = false;
        var selfRef: Self = undefined;

        const Listener = *const fn (E) void;

        var listeners: ArrayList(Listener) = undefined;

        pub fn init(allocator: Allocator) void {
            defer initialized = true;

            if (!initialized) {
                listeners = ArrayList(Listener).init(allocator);
            }

            selfRef = Self{};
        }

        pub fn deinit() void {
            defer initialized = false;
            if (initialized) {
                listeners.deinit();
                listeners = undefined;
                selfRef = undefined;
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
                    _ = listeners.swapRemove(i);
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
    const ED = EventDispatch([]const u8);
    ED.init(std.testing.allocator);
    defer ED.deinit();

    try ED.register(testlistener1);
    try ED.register(testlistener2);
    ED.notify("hallo1");
    ED.notify("hallo2");

    ED.unregister(testlistener1);

    ED.notify("hallo3");
}

fn testlistener1(event: []const u8) void {
    std.debug.print("\n  testlistener1 event: {s}\n", .{event});
}

fn testlistener2(event: []const u8) void {
    std.debug.print("  testlistener2 event: {s}\n", .{event});
}
