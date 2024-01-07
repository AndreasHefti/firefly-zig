const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn DynArray(comptime T: type) type {
    return struct {
        const Self = @This();
        const SliceOfSlice = [][]T;

        items: SliceOfSlice,

        _array_size: usize = 100,
        _num_arrays: usize = 0,
        _allocator: Allocator,

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = undefined,
                ._allocator = allocator,
            };
        }

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn initArraySize(allocator: Allocator, array_size: usize) Self {
            return Self{
                .items = undefined,
                ._array_size = array_size,
                ._allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            for (0..self._num_arrays) |ix| {
                self._allocator.free(self.items[ix]);
            }
            if (self._num_arrays > 0) {
                self._allocator.free(self.items);
            }
        }

        pub fn size(self: Self) usize {
            return self._num_arrays * self._array_size;
        }

        pub fn set(self: *Self, t: T, index: usize) void {
            ensureCapacity(self, index);
            self.items[index / self._array_size][index % self._array_size] = t;
        }

        pub fn get(self: *Self, index: usize) *T {
            // TODO check index consystency
            const y = index / self._array_size;
            const x = index % self._array_size;
            return &self.items[y][x];
        }

        fn ensureCapacity(self: *Self, n: usize) void {
            if (self._num_arrays == 0) {
                appendArray(self) catch |e|
                    std.log.err("Failed to allocate new array silce: {any}", .{e});
            }
            var offset = n / self._array_size;
            while (offset >= self._num_arrays) {
                appendArray(self) catch |e|
                    std.log.err("Failed to allocate new array silce: {any}", .{e});
                offset = n / self._array_size;
            }
        }

        fn appendArray(self: *Self) !void {

            // allocate new array with one more slot
            var new_items = try self._allocator.alloc([]T, self._num_arrays + 1);

            // copy old array slices
            for (0..self._num_arrays) |ix| {
                new_items[ix] = self.items[ix];
            }

            // allocate new array and refer slice within new slot
            const new_array = try self._allocator.alloc(T, self._array_size);
            new_items[self._num_arrays] = new_array;

            // free old slot slice
            if (self._num_arrays != 0) {
                self._allocator.free(self.items);
            }

            // and finally reference items to new items and increment num_arrays
            self.items = new_items;
            self._num_arrays += 1;
        }
    };
}

pub fn testArrayList(allocator: Allocator) !void {
    const TTest = struct {
        name: []const u8,
        index: usize,
    };

    const stdout = std.io.getStdOut().writer();

    var dyn_array = DynArray(TTest).init(allocator);
    defer dyn_array.deinit();

    try stdout.print("dyn_array initial {}\n", .{dyn_array.size()});

    dyn_array.set(TTest{ .name = "test1", .index = 1 }, 0);

    try stdout.print("dyn_array initial {}\n", .{dyn_array.size()});

    dyn_array.set(TTest{ .name = "test2", .index = 1 }, 2000);

    try stdout.print("dyn_array initial {}\n", .{dyn_array.size()});
    //try stdout.print("dyn_array {any}\n", .{dyn_array});
}

test "initilize" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = DynArray(i32).init(allocator);
    defer dyn_array.deinit();

    try testing.expect(dyn_array.size() == 0);
    dyn_array.set(1, 0);
    try testing.expect(dyn_array.size() == dyn_array._array_size);
}
