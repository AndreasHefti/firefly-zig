const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

const StringBuffer = utils.StringBuffer;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.reorderSystems(&firefly.Engine.CoreSystems.DEFAULT_SYSTEM_ORDER);
    firefly.Engine.printState();

    const max_index: usize = 10000;
    var bitset = utils.BitSet.new(firefly.api.ALLOC);
    bitset.set(max_index);
    std.debug.print("*********************** bitset: {d} needs {d}\n", .{
        max_index,
        (bitset.unmanaged.bit_length + (@bitSizeOf(utils.BitSet.MaskInt) - 1)) / @bitSizeOf(utils.BitSet.MaskInt),
    });
}
