const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

const StringBuffer = utils.StringBuffer;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.reorderSystems(&firefly.Engine.CoreSystems.DEFAULT_SYSTEM_ORDER);
    firefly.Engine.printState();

    // var array: utils.DynIndexArray = utils.DynIndexArray.new(firefly.api.ALLOC, 30);
    // defer array.deinit();

    // for (0..3500) |i|
    //     array.set(i, i);

    // std.log.info("**************** array: {any}", .{array});
}
