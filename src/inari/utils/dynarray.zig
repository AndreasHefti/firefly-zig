const std = @import("std");
const Allocator = std.mem.Allocator;
const BitSet = @import("bitset.zig").BitSet;
const utils = @import("utils.zig");
const Index = utils.Index;
const UNDEF_INDEX = std.math.maxInt(usize);

pub const DynArrayError = error{IllegalSlotAccess};

pub const DynIndexArray = struct {
    items: []Index,
    size_pointer: usize,
    grow_size: usize,
    allocator: Allocator,

    pub fn init(allocator: Allocator, grow_size: usize) DynIndexArray {
        return DynIndexArray{
            .items = &[_]Index{},
            .size_pointer = 0,
            .grow_size = grow_size,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DynIndexArray) void {
        self.allocator.free(self.items);
        self.items = &[_]Index{};
        self.size_pointer = 0;
    }

    pub fn add(self: *DynIndexArray, index: Index) void {
        ensureCapacity(self, self.size_pointer + 1);
        self.items[self.size_pointer] = index;
        self.size_pointer += 1;
    }

    pub fn set(self: *DynIndexArray, at: usize, index: Index) void {
        ensureCapacity(self, index);
        self.items[at] = index;
        if (self.size_pointer < at) {
            self.size_pointer = at + 1;
        }
    }

    pub fn get(self: *DynIndexArray, at: usize) Index {
        if (at > self.size_pointer) {
            return UNDEF_INDEX;
        }
        return self.items[at];
    }

    pub fn removeAt(self: *DynIndexArray, at: usize) Index {
        if (at > self.size_pointer) {
            return UNDEF_INDEX;
        }
        var res = self.items[at];
        for (at..self.size_pointer - 1) |i| {
            self.items[i] = self.items[i + 1];
        }
        self.size_pointer -= 1;
        self.items[self.size_pointer] = UNDEF_INDEX;
        return res;
    }

    pub fn removeFirst(self: *DynIndexArray, index: Index) void {
        for (0..self.size_pointer) |i| {
            if (self.items[i] == index) {
                _ = removeAt(self, i);
                return;
            }
        }
    }

    fn ensureCapacity(self: *DynIndexArray, index: usize) void {
        while (self.items.len < index) {
            growOne(self);
        }
    }

    fn growOne(self: *DynIndexArray) void {
        const old_mem = self.items;
        if (!self.allocator.resize(old_mem, self.items.len + self.grow_size)) {
            const new_memory = self.allocator.alloc(Index, self.items.len + self.grow_size) catch unreachable;
            @memcpy(new_memory[0..self.items.len], self.items);
            self.allocator.free(self.items);
            self.items = new_memory;
        }
        for (self.size_pointer..self.items.len) |i| {
            self.items[i] = UNDEF_INDEX;
        }
    }
};

pub fn DynArray(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Iterator = struct {
            array: *DynArray(T) = undefined,
            index: usize = UNDEF_INDEX,

            pub fn next(self: *Iterator) ?*T {
                if (self.index == UNDEF_INDEX)
                    return null;

                var n = self.array.get(self.index);
                self.index = self.array.slots.nextSetBit(self.index + 1) orelse UNDEF_INDEX;
                return n;
            }
        };

        null_value: ?T = undefined,
        register: Register(T) = undefined,
        slots: BitSet = undefined,

        pub fn init(allocator: Allocator, comptime null_value: ?T) !Self {
            return Self{
                .null_value = null_value,
                .register = Register(T).init(allocator),
                .slots = try BitSet.initEmpty(allocator, 128),
            };
        }

        pub fn initWithRegisterSize(allocator: Allocator, register_size: usize, comptime null_value: ?T) !Self {
            return Self{
                .null_value = null_value,
                .register = Register(T).initWithRegisterSize(allocator, register_size),
                .slots = try BitSet.initEmpty(allocator, 128),
            };
        }

        pub fn deinit(self: *Self) void {
            self.register.deinit();
            self.slots.deinit();
        }

        pub fn size(self: Self) usize {
            return self.register.size();
        }

        pub fn nextFreeSlot(self: *Self) usize {
            return self.slots.nextClearBit(0);
        }

        pub fn add(self: *Self, t: T) usize {
            const index = self.slots.nextClearBit(0);
            self.register.set(t, index);
            self.slots.set(index);
            return index;
        }

        pub fn remove(self: *Self, t: T) void {
            var i: usize = 0;
            while (self.slots.nextSetBit(i)) |next| {
                if (std.meta.eql(t, self.get(next).*)) {
                    reset(self, i);
                    return;
                }
                i = next + 1;
            }
        }

        pub fn set(self: *Self, t: T, index: usize) void {
            self.register.set(t, index);
            self.slots.set(index);
        }

        pub fn inBounds(self: *Self, index: usize) bool {
            return index < self.slots.unmanaged.bit_length and self.register.inBounds(index);
        }

        pub fn exists(self: *Self, index: usize) bool {
            return inBounds(self, index) and self.slots.isSet(index);
        }

        pub fn getIfExists(self: *Self, index: usize) ?*T {
            if (exists(self, index)) {
                return self.register.get(index);
            }
            return null;
        }

        pub fn get(self: *Self, index: usize) *T {
            if (exists(self, index)) {
                return self.register.get(index);
            } else if (self.null_value != null) {
                return &self.null_value.?;
            } else {
                @panic("Illegal array access");
            }
        }

        pub fn reset(self: *Self, index: usize) void {
            if (exists(self, index)) {
                if (self.null_value) |nv| {
                    self.register.set(nv, index);
                }
                self.slots.setValue(index, false);
            }
        }

        pub fn clear(self: *Self) void {
            var next = self.slots.nextSetBit(0);
            while (next) |i| {
                self.reset(i);
                self.slots.setValue(i, false);
                next = self.slots.nextSetBit(i + 1);
            }
        }

        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .array = self,
                .index = self.slots.nextSetBit(0) orelse UNDEF_INDEX,
            };
        }
    };
}

pub fn Register(comptime T: type) type {
    return struct {
        const Self = @This();
        const SliceOfSlice = [][]T;

        /// The register of a DynArray is a slice of slices(T) pointing to the used arrays
        register: SliceOfSlice = undefined,
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
        pub fn init(allocator: Allocator) Self {
            return Self{
                ._allocator = allocator,
            };
        }

        pub fn initWithRegisterSize(allocator: Allocator, register_size: usize) Self {
            return Self{
                ._allocator = allocator,
                .array_size = register_size,
            };
        }

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn initArraySize(allocator: Allocator, array_size: usize) Self {
            return Self{
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

test "DynIndexArray initialize" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.init(allocator, 10);
    defer array.deinit();

    try testing.expect(array.items.len == 0);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 0);
}

test "DynIndexArray grow one" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.init(allocator, 10);
    defer array.deinit();

    array.add(1);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 1);
    try testing.expect(array.items[0] == 1);

    array.add(2);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 2);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);

    array.set(4, 5);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 5);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == UNDEF_INDEX);
    try testing.expect(array.items[3] == UNDEF_INDEX);
    try testing.expect(array.items[4] == 5);
    try testing.expect(array.items[5] == UNDEF_INDEX);

    array.add(6);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 6);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == UNDEF_INDEX);
    try testing.expect(array.items[3] == UNDEF_INDEX);
    try testing.expect(array.items[4] == 5);
    try testing.expect(array.items[5] == 6);
    try testing.expect(array.items[6] == UNDEF_INDEX);
}

test "DynIndexArray remove" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.init(allocator, 10);
    defer array.deinit();

    array.add(1);
    array.add(2);
    array.add(3);
    array.add(4);
    array.add(5);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 5);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == 3);
    try testing.expect(array.items[3] == 4);
    try testing.expect(array.items[4] == 5);
    try testing.expect(array.items[5] == UNDEF_INDEX);

    array.removeFirst(3);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 4);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == 4);
    try testing.expect(array.items[3] == 5);
    try testing.expect(array.items[4] == UNDEF_INDEX);
}

test "DynIndexArray grow" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.init(allocator, 2);
    defer array.deinit();

    array.add(1);
    array.add(2);
    array.add(3);
    array.add(4);
    array.add(5);

    try testing.expect(array.items.len == 6);
    try testing.expect(array.grow_size == 2);
    try testing.expect(array.size_pointer == 5);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == 3);
    try testing.expect(array.items[3] == 4);
    try testing.expect(array.items[4] == 5);
    try testing.expect(array.items[5] == UNDEF_INDEX);
}

test "DynArray initialize" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = try DynArray(i32).init(allocator, -1);
    defer dyn_array.deinit();
    try testing.expect(dyn_array.size() == 0);
    dyn_array.set(1, 0);
    try testing.expect(dyn_array.size() == dyn_array.register.array_size);
    try testing.expect(dyn_array.get(0).* == 1);
    try testing.expect(dyn_array.get(1).* == -1);
    try testing.expect(dyn_array.get(2).* == -1);
}

test "DynArray scale up" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = try DynArray(i32).init(allocator, -1);
    defer dyn_array.deinit();

    dyn_array.set(100, 0);

    try testing.expect(dyn_array.size() == dyn_array.register.array_size);

    dyn_array.set(200, 200000);

    try testing.expect(dyn_array.size() == 200000 + dyn_array.register.array_size);
    try testing.expect(200 == dyn_array.get(200000).*);
    try testing.expect(-1 == dyn_array.get(200001).*);
}

test "DynArray consistency checks" {
    var dyn_array = try DynArray(i32).init(std.testing.allocator, -1);
    defer dyn_array.deinit();

    try std.testing.expect(-1 == dyn_array.null_value);
    dyn_array.set(100, 0);
    dyn_array.set(100, 100);
    try std.testing.expect(dyn_array.exists(0));
    try std.testing.expect(dyn_array.exists(100));
    try std.testing.expect(!dyn_array.exists(101));
    try std.testing.expect(!dyn_array.exists(2000));
}

test "DynArray use u16 as index" {
    var dyn_array = try DynArray(i32).init(std.testing.allocator, -1);
    defer dyn_array.deinit();

    const index1: u16 = 0;

    dyn_array.set(0, index1);
}
