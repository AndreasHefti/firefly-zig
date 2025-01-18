const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

const StringBuffer = utils.StringBuffer;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.reorderSystems(&firefly.Engine.CoreSystems.DEFAULT_SYSTEM_ORDER);
    firefly.Engine.printState();

    // var bitset = utils.BitSet.new(firefly.api.ALLOC);
    // defer bitset.deinit();

    // var bitset_new = utils.BitSet.new(firefly.api.ALLOC);
    // defer bitset_new.deinit();

    // bitset.set(2);
    // bitset.set(3);
    // bitset.set(12);
    // bitset.set(120);
    // bitset.set(1200);
    // bitset.set(12000);
    // bitset.set(120000);

    // bitset_new.setOrUnion(&bitset);

    // std.debug.print("************** bitset: {any}\n", .{bitset});
    // std.debug.print("************** bitset_new: {any}\n", .{bitset_new});
}
