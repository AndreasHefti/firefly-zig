const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;
const BitSet = utils.BitSet;
const Index = utils.Index;
const UNDEF_INDEX = std.math.maxInt(usize);

pub const DynArrayError = error{IllegalSlotAccess};

pub const DynIndexArray = struct {
    items: []Index,
    size_pointer: usize,
    grow_size: usize,
    allocator: Allocator,

    pub fn format(
        self: DynIndexArray,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("DynIndexArray[ ", .{});
        for (self.items) |i| {
            if (i != UNDEF_INDEX)
                try writer.print("{d},", .{i});
        }
        try writer.print(" ]", .{});
    }

    pub fn new(allocator: Allocator, grow_size: usize) DynIndexArray {
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
        const res = self.items[at];
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

    pub fn clear(self: *DynIndexArray) void {
        self.size_pointer = 0;
    }

    fn ensureCapacity(self: *DynIndexArray, index: usize) void {
        while (self.items.len < index) {
            growOne(self);
        }
    }

    fn growOne(self: *DynIndexArray) void {
        if (self.items.len == 0) {
            self.items = self.allocator.alloc(Index, self.grow_size) catch unreachable;
        } else {
            if (self.allocator.resize(self.items, self.items.len + self.grow_size)) {
                self.items.len = self.items.len + self.grow_size;
            } else {
                const new_memory = self.allocator.alloc(Index, self.items.len + self.grow_size) catch unreachable;
                @memcpy(new_memory[0..self.items.len], self.items);
                self.allocator.free(self.items);
                self.items = new_memory;
            }
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

                const n = self.array.get(self.index);
                self.index = self.array.slots.nextSetBit(self.index + 1) orelse UNDEF_INDEX;
                return n;
            }
        };

        //null_value: ?T = undefined,
        register: Register(T) = undefined,
        slots: BitSet = undefined,

        pub fn new(allocator: Allocator) Self {
            return Self{
                .register = Register(T).new(allocator),
                .slots = BitSet.newEmpty(allocator, 128),
            };
        }

        pub fn newWithRegisterSize(allocator: Allocator, register_size: usize) Self {
            return Self{
                .register = Register(T).newWithRegisterSize(allocator, register_size),
                .slots = BitSet.newEmpty(allocator, register_size),
            };
        }

        pub fn deinit(self: *Self) void {
            // if (self.slots.nextSetBit(0) != null)
            //     @panic("Dynarray still has data!");

            self.register.deinit();
            self.slots.deinit();
        }

        pub fn capacity(self: Self) usize {
            return self.register.size();
        }

        pub fn size(self: Self) usize {
            var i: usize = 0;
            var next = self.slots.nextSetBit(0);
            while (next) |n| {
                i += 1;
                next = self.slots.nextSetBit(n + 1);
            }
            return i;
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

        pub fn addAndGet(self: *Self, t: T) struct { i: usize, ref: *T } {
            const index = add(self, t);
            return .{ .i = index, .ref = get(self, index).? };
        }

        pub fn remove(self: *Self, t: *T) void {
            var next = self.slots.nextSetBit(0);
            while (next) |i| {
                if (self.get(i)) |e| {
                    if (std.meta.eql(t, e)) {
                        delete(self, i);
                        return;
                    }
                }
                next = self.slots.nextSetBit(i + 1);
            }
        }

        pub fn set(self: *Self, t: T, index: usize) *T {
            self.register.set(t, index);
            self.slots.set(index);
            return self.register.get(index);
        }

        pub fn inBounds(self: *Self, index: usize) bool {
            return index < self.slots.unmanaged.bit_length and self.register.inBounds(index);
        }

        pub fn exists(self: *Self, index: usize) bool {
            return inBounds(self, index) and self.slots.isSet(index);
        }

        pub fn get(self: *Self, index: usize) ?*T {
            if (exists(self, index)) {
                return self.register.get(index);
            }
            return null;
        }

        pub fn delete(self: *Self, index: usize) void {
            if (exists(self, index))
                self.slots.setValue(index, false);
        }

        pub fn clear(self: *Self) void {
            self.slots.clear();
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
        pub fn new(allocator: Allocator) Self {
            return Self{
                ._allocator = allocator,
            };
        }

        pub fn newWithRegisterSize(allocator: Allocator, register_size: usize) Self {
            return Self{
                ._allocator = allocator,
                .array_size = register_size,
            };
        }

        /// Deinitialize with `deinit` or use `toOwnedSlice`.
        pub fn newArraySize(allocator: Allocator, array_size: usize) Self {
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
            if (self._num_arrays <= 0)
                return false;

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

pub const DynIndexMap = struct {
    mapping: std.AutoHashMap(Index, DynIndexArray) = undefined,
    grow_size: usize = 5,

    pub fn new(allocator: Allocator) DynIndexMap {
        return .{
            .mapping = std.AutoHashMap(Index, DynIndexArray).init(allocator),
        };
    }

    pub fn deinit(self: *DynIndexMap) void {
        self.clear();
        self.mapping.deinit();
        self.mapping = undefined;
    }

    pub fn map(self: *DynIndexMap, index: Index, id: Index) void {
        if (!self.mapping.contains(index))
            self.mapping.put(
                index,
                DynIndexArray.new(self.mapping.allocator, self.grow_size),
            ) catch unreachable;

        if (self.mapping.getEntry(index)) |e| e.value_ptr.add(id);
    }

    pub fn remove(self: *DynIndexMap, index: Index, id: Index) void {
        if (self.mapping.getEntry(index)) |e| e.value_ptr.removeFirst(id);
    }

    pub fn removeAll(self: *DynIndexMap, index: Index) void {
        if (self.mapping.getEntry(index)) |e| e.value_ptr.deinit();
        _ = self.mapping.remove(index);
    }

    pub fn clear(self: *DynIndexMap) void {
        var i = self.mapping.valueIterator();
        while (i.next()) |e| e.deinit();
        self.mapping.clearAndFree();
    }

    pub fn format(
        self: DynIndexMap,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("DynIndexMap[", .{});
        var i = self.mapping.iterator();
        while (i.next()) |e| {
            try writer.print(" {d}=", .{e.key_ptr.*});
            for (0..e.value_ptr.size_pointer) |vi| {
                try writer.print("{d}", .{e.value_ptr.items[vi]});
                if (vi < e.value_ptr.size_pointer - 1)
                    try writer.print(",", .{});
            }
        }
        try writer.print(" ]", .{});
    }
};
