const std = @import("std");
const inari = @import("../../inari.zig");
const state = @import("state.zig");

const utils = inari.utils;
const firefly = inari.firefly;
const Float = utils.Float;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const State = state.State;
pub const StateEngine = state.StateEngine;
pub const EState = state.EState;

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init(_: firefly.api.InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    // TODO
    state.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // TODO
    state.deinit();
}
