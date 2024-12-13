const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

const StringBuffer = utils.StringBuffer;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.reorderSystems(&firefly.Engine.CoreSystems.DEFAULT_SYSTEM_ORDER);
    firefly.Engine.printState();

    const text = "fbvfbebebfeb ovfj pqeovpeovje povjpoevjpwoejv peovj wvpjwoej vpejvpweovjpweovjpeovjwpeovjwpeovjpoej vpewov jpow";
    const pwd = "passwordpasswordpasswordpassword";

    const cypher = firefly.api.encrypt(text, pwd.*, firefly.api.ALLOC);
    defer firefly.api.ALLOC.free(cypher);
    const text2 = firefly.api.decrypt(cypher, pwd.*, firefly.api.ALLOC);
    defer firefly.api.ALLOC.free(text2);

    std.debug.print("*********** encrypted {s}\n", .{cypher});
    std.debug.print("*********** decrypted {s}\n", .{text2});
}
