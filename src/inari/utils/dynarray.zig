const std = @import("std");
const Allocator = std.mem.Allocator;

const DynArrayError = error{IllegalSlotAccess};

pub fn DynArrayUndefined(comptime T: type) type {
    return DynArray(T, undefined);
}

pub fn DynArray(comptime T: type) type {
    return struct {
        const Self = @This();
        const SliceOfSlice = [][]T;

        /// The empty value is used to fill up new allocated arrays or reset slot values
        var _voidval: ?T = null;

        /// The register of a DynArray is a slice of slices(T) pointing to the used arrays
        register: SliceOfSlice,
        /// Defines the size of the array that will be allocated when running out of capacity
        /// Note: This shall not be changed after initialization
        array_size: usize = 100,

        /// Holds the actual number of allocated arrays and is only internally used.
        /// Do not change this value from outside. ewf ewf
        _num_arrays: usize = 0,
        /// Reference to the allocator the DynArray was initialized with
        /// Do not change this value from outside.
        _allocator: Allocator,

        /// Initialization with allocator and an 'empty' that is used to fill and delete slots.
        /// Deinitialize with `deinit`
        pub fn init(allocator: Allocator, comptime void_value: ?T) Self {
            Self._voidval = void_value;
            return Self{
                .register = undefined,
                ._allocator = allocator,
            };
        }

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn initArraySize(allocator: Allocator, array_size: usize) Self {
            return Self{
                .register = undefined,
                .array_size = array_size,
                ._allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            for (0..self._num_arrays) |ix| {
                self._allocator.free(self.register[ix]);
            }
            if (self._num_arrays > 0) {
                self._allocator.free(self.register);
            }
        }

        pub fn size(self: Self) usize {
            return self._num_arrays * self.array_size;
        }

        pub fn set(self: *Self, t: T, index: usize) void {
            ensureCapacity(self, index);
            self.register[index / self.array_size][index % self.array_size] = t;
        }

        pub fn inBounds(self: *Self, index: usize) bool {
            const y = index / self.array_size;
            const x = index % self.array_size;
            return y < self.register.len and x < self.register[y].len;
        }

        pub fn exists(self: *Self, index: usize) bool {
            const y = index / self.array_size;
            const x = index % self.array_size;
            if (y < self.register.len and
                x < self.register[y].len and
                Self._voidval != null and
                self.register[y][x] != Self._voidval)
            {
                return true;
            }
            return false;
        }

        pub fn get(self: *Self, index: usize) *T {
            return &self.register[index / self.array_size][index % self.array_size];
        }

        pub fn reset(self: *Self, index: usize) void {
            const y = index / self.array_size;
            const x = index % self.array_size;
            if (y >= self.register.len or x >= self.register[y].len) {
                return;
            }
            self.register[y][x] = self.empty_value;
        }

        fn ensureCapacity(self: *Self, n: usize) void {
            if (self._num_arrays == 0) {
                appendArray(self) catch |e|
                    std.log.err("Failed to allocate new array slice: {any}", .{e});
            }
            var offset = n / self.array_size;
            while (offset >= self._num_arrays) {
                appendArray(self) catch |e|
                    std.log.err("Failed to allocate new array slice: {any}", .{e});
                offset = n / self.array_size;
            }
        }

        fn appendArray(self: *Self) !void {

            // allocate new array with one more slot
            var new_register = try self._allocator.alloc([]T, self._num_arrays + 1);

            // copy old array slices
            for (0..self._num_arrays) |ix| {
                new_register[ix] = self.register[ix];
            }

            // allocate new array and refer slice within new slot
            const new_array = try self._allocator.alloc(T, self.array_size);
            // fill up new array with empty values
            if (Self._voidval != null) {
                for (0..new_array.len) |i| {
                    new_array[i] = Self._voidval.?;
                }
            }
            new_register[self._num_arrays] = new_array;

            // free old slot slice
            if (self._num_arrays != 0) {
                self._allocator.free(self.register);
            }

            // and finally reference register to new register and increment num_arrays
            self.register = new_register;
            self._num_arrays += 1;
        }
    };
}

test "initialize" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = DynArray(i32).init(allocator, -1);
    defer dyn_array.deinit();

    try testing.expect(dyn_array.size() == 0);
    dyn_array.set(1, 0);
    try testing.expect(dyn_array.size() == dyn_array.array_size);
    try testing.expect(dyn_array.get(0).* == 1);
    try testing.expect(dyn_array.get(1).* == -1);
    try testing.expect(dyn_array.get(2).* == -1);
}

test "scale up" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = DynArray(i32).init(allocator, -1);
    defer dyn_array.deinit();

    dyn_array.set(100, 0);

    try testing.expect(dyn_array.size() == dyn_array.array_size);

    dyn_array.set(200, 200000);

    try testing.expect(dyn_array.size() == 200000 + dyn_array.array_size);
    try testing.expect(200 == dyn_array.get(200000).*);
    try testing.expect(-1 == dyn_array.get(200001).*);
}

test "consistency checks" {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const List = DynArray(i32);
    var dyn_array = List.init(allocator, -1);
    defer dyn_array.deinit();

    try testing.expect(-1 == List._voidval);
    dyn_array.set(100, 0);
    dyn_array.set(100, 100);
    try testing.expect(dyn_array.exists(0));
    try testing.expect(dyn_array.exists(100));
    try testing.expect(!dyn_array.exists(101));
    try testing.expect(!dyn_array.exists(2000));
}
