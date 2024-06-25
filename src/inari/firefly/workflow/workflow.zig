// const std = @import("std");
// const firefly = @import("../firefly.zig");
// const state = @import("state.zig");

// const Float = firefly.utils.Float;

// //////////////////////////////////////////////////////////////
// //// Public API declarations
// //////////////////////////////////////////////////////////////

// pub const State = state.State;
// pub const StateEngine = state.StateEngine;
// pub const EntityStateEngine = state.EntityStateEngine;
// pub const EState = state.EState;

// //////////////////////////////////////////////////////////////
// //// module init
// //////////////////////////////////////////////////////////////

// var initialized = false;

// pub fn init(_: firefly.api.InitContext) !void {
//     defer initialized = true;
//     if (initialized)
//         return;

//     // TODO
//     state.init();
// }

// pub fn deinit() void {
//     defer initialized = false;
//     if (!initialized)
//         return;

//     // TODO
//     state.deinit();
// }
