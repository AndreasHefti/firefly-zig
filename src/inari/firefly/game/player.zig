const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const physics = firefly.physics;
const graphics = firefly.graphics;

//////////////////////////////////////////////////////////////
//// game world init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}
