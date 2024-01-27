const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// Event dispatcher implemented as type based singleton
pub fn EventDispatch(comptime E: type) type {
    return struct {
        const Self = @This();
        const Listener = *const fn (E) void;

        listeners: ArrayList(Listener) = undefined,

        pub fn init(allocator: Allocator) Self {
            return Self{
                .listeners = ArrayList(Listener).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.listeners.deinit();
        }

        pub fn register(self: *Self, listener: Listener) void {
            self.listeners.append(listener) catch @panic("Failed to append listener");
        }

        pub fn unregister(self: *Self, listener: Listener) void {
            for (0..self.listeners.items.len) |i| {
                if (self.listeners.items[i] == listener) {
                    _ = self.listeners.swapRemove(i);
                    return;
                }
            }
        }

        pub fn notify(self: *Self, event: E) void {
            for (0..self.listeners.items.len) |i| {
                self.listeners.items[i](event);
            }
        }
    };
}

test "Events and Listeners" {
    var ED = EventDispatch([]const u8).init(std.testing.allocator);
    defer ED.deinit();

    ED.register(testlistener1);
    ED.register(testlistener2);
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
