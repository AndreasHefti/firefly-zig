const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

const StringBuffer = utils.StringBuffer;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.reorderSystems(&firefly.Engine.CoreSystems.DEFAULT_SYSTEM_ORDER);
    firefly.Engine.printState();

    var arena_allocator = firefly.api.ArenaAlloc.new();
    defer arena_allocator.deinit();

    const alloc = arena_allocator.allocator();

    const tuples = testArrayListAlloc(alloc);
    for (0..tuples.len) |i| {
        std.debug.print("*********** tuple: {s} {s}\n", .{ tuples[i].name, tuples[i].value });
    }

    const text = "fbvfbebebfeb ovfj pqeovpeovje povjpoevjpwoejv peovj wvpjwoej vpejvpweovjpweovjpeovjwpeovjwpeovjpoej vpewov jpow";
    const pwd = "passwordpasswordpasswordpassword";

    const cypher = firefly.api.encrypt(text, pwd.*, firefly.api.ALLOC);
    defer firefly.api.ALLOC.free(cypher);
    const text2 = firefly.api.decrypt(cypher, pwd.*, firefly.api.ALLOC);
    defer firefly.api.ALLOC.free(text2);

    std.debug.print("*********** encrypted {s}\n", .{cypher});
    std.debug.print("*********** decrypted {s}\n", .{text2});
}

const Tuple = struct {
    name: utils.String,
    value: utils.String,
};

fn testArrayListAlloc(arena: std.mem.Allocator) []const Tuple {
    var list = std.ArrayList(Tuple).init(arena);
    defer list.deinit();

    var new1 = list.addOne() catch unreachable;
    new1.name = utils.NamePool.alloc("name1").?;
    new1.value = utils.NamePool.alloc("val1").?;

    var new2 = list.addOne() catch unreachable;
    new2.name = utils.NamePool.alloc("name2").?;
    new2.value = utils.NamePool.alloc("val2").?;

    var new3 = list.addOne() catch unreachable;
    new3.name = utils.NamePool.alloc("name3").?;
    new3.value = utils.NamePool.alloc("val3").?;

    return list.toOwnedSlice() catch unreachable;
}
