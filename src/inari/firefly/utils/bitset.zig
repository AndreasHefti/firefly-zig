const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const DynamicBitSetUnmanaged = std.bit_set.DynamicBitSetUnmanaged;
const IteratorOptions = std.bit_set.IteratorOptions;
const Range = std.bit_set.Range;

pub const BitSet = struct {
    const Self = @This();

    /// The integer type used to represent a mask in this bit set
    pub const MaskInt = usize;

    /// The integer type used to shift a mask in this bit set
    pub const ShiftInt = std.math.Log2Int(MaskInt);

    /// The allocator used by this bit set
    allocator: Allocator,

    /// The number of valid items in this bit set
    unmanaged: DynamicBitSetUnmanaged = .{},

    pub fn new(allocator: Allocator) Self {
        return newEmpty(allocator, 64);
    }

    /// Creates a bit set with no elements present.
    pub fn newEmpty(allocator: Allocator, bit_length: usize) Self {
        return Self{
            .unmanaged = DynamicBitSetUnmanaged.initEmpty(allocator, bit_length) catch unreachable,
            .allocator = allocator,
        };
    }

    /// Creates a bit set with all elements present.
    pub fn newFull(allocator: Allocator, bit_length: usize) Self {
        return Self{
            .unmanaged = DynamicBitSetUnmanaged.initFull(allocator, bit_length) catch unreachable,
            .allocator = allocator,
        };
    }

    /// Resizes to a new length.  If the new length is larger
    /// than the old length, fills any added bits with `fill`.
    pub fn resize(self: *@This(), new_len: usize, value: bool) void {
        self.unmanaged.resize(self.allocator, new_len, value) catch unreachable;
    }

    /// deinitialize the array and releases its memory.
    /// The passed allocator must be the same one used for
    /// init* or resize in the past.
    pub fn deinit(self: *Self) void {
        self.unmanaged.deinit(self.allocator);
    }

    /// Creates a duplicate of this bit set, using the new allocator.
    pub fn clone(self: *const Self, new_allocator: Allocator) !Self {
        return Self{
            .unmanaged = try self.unmanaged.clone(new_allocator),
            .allocator = new_allocator,
        };
    }

    /// Returns the number of bits in this bit set
    pub inline fn capacity(self: Self) usize {
        return self.unmanaged.capacity();
    }

    pub fn clearAndFree(self: *Self) void {
        self.unmanaged.resize(self.allocator, 0, false) catch unreachable;
    }

    pub fn clear(self: *Self) void {
        self.unmanaged.setRangeValue(.{ .start = 0, .end = self.unmanaged.bit_length }, false);
    }

    pub fn fill(self: *Self) void {
        self.unmanaged.setRangeValue(.{ .start = 0, .end = self.unmanaged.bit_length }, true);
    }

    pub inline fn lengthOfMaskArray(self: Self) usize {
        return (self.unmanaged.bit_length + (@bitSizeOf(MaskInt) - 1)) / @bitSizeOf(MaskInt);
    }

    pub inline fn maskLength() usize {
        return @bitSizeOf(MaskInt);
    }

    pub fn nextSetBit(self: Self, index: usize) ?usize {
        const c = self.unmanaged.capacity();
        if (index >= c)
            return null;

        var i = index;
        var is_set = self.unmanaged.isSet(i);
        while (!is_set) {
            i += 1;
            if (i >= c) return null;
            is_set = self.unmanaged.isSet(i);
        }
        return i;
    }

    pub fn prevSetBit(self: Self, index: usize) ?usize {
        if (index >= self.unmanaged.capacity())
            return null;

        var i = index;
        var is_set = self.unmanaged.isSet(i);
        while (!is_set) {
            i -= 1;
            if (i >= 0) return null;
            is_set = self.unmanaged.isSet(i);
        }
        return i;
    }

    pub fn nextClearBit(self: Self, index: usize) usize {
        const c = self.unmanaged.capacity();
        if (index >= c)
            return c;

        var i = index;
        var is_clear = !self.unmanaged.isSet(i);
        while (!is_clear) {
            i += 1;
            if (i >= c) return c;
            is_clear = !self.unmanaged.isSet(i);
        }

        return i;
    }

    pub fn setAnd(self: *BitSet, other: *BitSet) void {
        const self_num_masks = self.unmanaged.numMasks(self.bit_length);
        const other_num_masks = other.unmanaged.numMasks(other.bit_length);
        const min_num_masks = @min(self_num_masks, other_num_masks);
        for (self.masks[0..min_num_masks], 0..) |*mask, i| {
            mask.* &= other.masks[i];
        }
    }

    pub fn setOr(self: *BitSet, other: *BitSet) void {
        const self_num_masks = self.unmanaged.numMasks(self.bit_length);
        const other_num_masks = other.unmanaged.numMasks(other.bit_length);
        const min_num_masks = @min(self_num_masks, other_num_masks);
        for (self.masks[0..min_num_masks], 0..) |*mask, i| {
            mask.* |= other.masks[i];
        }
    }

    /// Returns true if the bit at the specified index
    /// is present in the set, false otherwise.
    pub fn isSet(self: Self, index: usize) bool {
        if (index >= self.unmanaged.bit_length)
            return false;
        return self.unmanaged.isSet(index);
    }

    /// Returns the total number of set bits in this bit set.
    pub fn count(self: Self) usize {
        return self.unmanaged.count();
    }

    /// Changes the value of the specified bit of the bit
    /// set to match the passed boolean.
    pub fn setValue(self: *Self, index: usize, value: bool) void {
        ensureCapacity(self, index);
        self.unmanaged.setValue(index, value);
    }

    /// Adds a specific bit to the bit set
    pub fn set(self: *Self, index: usize) void {
        ensureCapacity(self, index);
        self.unmanaged.set(index);
    }

    /// Changes the value of all bits in the specified range to
    /// match the passed boolean.
    pub fn setRangeValue(self: *Self, range: Range, value: bool) void {
        ensureCapacity(self, range.end);
        self.unmanaged.setRangeValue(range, value);
    }

    /// Removes a specific bit from the bit set
    pub fn unset(self: *Self, index: usize) void {
        ensureCapacity(self, index);
        self.unmanaged.unset(index);
    }

    /// Flips a specific bit in the bit set
    pub fn toggle(self: *Self, index: usize) void {
        ensureCapacity(self, index);
        self.unmanaged.toggle(index);
    }

    /// Flips all bits in this bit set which are present
    /// in the toggles bit set.  Both sets must have the
    /// same bit_length.
    pub fn toggleSet(self: *Self, toggles: Self) void {
        self.unmanaged.toggleSet(toggles.unmanaged);
    }

    /// Flips every bit in the bit set.
    pub fn toggleAll(self: *Self) void {
        self.unmanaged.toggleAll();
    }

    /// Performs a union of two bit sets, and stores the
    /// result in the first one.  Bits in the result are
    /// set if the corresponding bits were set in either input.
    /// The two sets must both be the same bit_length.
    pub fn setUnion(self: *Self, other: Self) void {
        self.unmanaged.setUnion(other.unmanaged);
    }

    /// Performs an intersection of two bit sets, and stores
    /// the result in the first one.  Bits in the result are
    /// set if the corresponding bits were set in both inputs.
    /// The two sets must both be the same bit_length.
    pub fn setIntersection(self: *Self, other: Self) void {
        self.unmanaged.setIntersection(other.unmanaged);
    }

    /// Finds the index of the first set bit.
    /// If no bits are set, returns null.
    pub fn findFirstSet(self: Self) ?usize {
        return self.unmanaged.findFirstSet();
    }

    /// Finds the index of the first set bit, and unsets it.
    /// If no bits are set, returns null.
    pub fn toggleFirstSet(self: *Self) ?usize {
        return self.unmanaged.toggleFirstSet();
    }

    /// Returns true iff every corresponding bit in both
    /// bit sets are the same.
    pub fn eql(self: Self, other: Self) bool {
        return self.unmanaged.eql(other.unmanaged);
    }

    /// Iterates through the items in the set, according to the options.
    /// The default options (.{}) will iterate indices of set bits in
    /// ascending order.  Modifications to the underlying bit set may
    /// or may not be observed by the iterator.  Resizing the underlying
    /// bit set invalidates the iterator.
    pub fn iterator(self: *const Self, comptime options: IteratorOptions) Iterator(options) {
        return self.unmanaged.iterator(options);
    }

    pub const Iterator = DynamicBitSetUnmanaged.Iterator;

    fn ensureCapacity(self: *Self, size: usize) void {
        const c = self.unmanaged.capacity();
        if (c <= size) {
            const newC = if (c * 2 > size) c * 2 else size + 1;
            self.unmanaged.resize(self.allocator, newC, false) catch |err| {
                std.log.err("Failed to increase capacity: {}", .{err});
            };
        }
    }
};
