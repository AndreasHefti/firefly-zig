const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// Event dispatcher implemented as type based singleton
pub fn EventDispatch(comptime E: type) type {
    return struct {
        const Self = @This();

        pub const Listener = *const fn (E) void;

        listeners: ArrayList(Listener) = undefined,

        pub fn new(allocator: Allocator) Self {
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

        pub fn registerPrepend(self: *Self, listener: Listener) void {
            self.listeners.insert(0, listener) catch @panic("Failed to prepend listener");
        }

        pub fn registerInsert(self: *Self, index: usize, listener: Listener) void {
            self.listeners.insert(index, listener) catch @panic("Failed to insert listener");
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
