const std = @import("std");
const inari = @import("../../inari.zig");
const animation = @import("animation.zig");
const utils = inari.utils;
const firefly = inari.firefly;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const EasedValueIntegration = animation.EasedValueIntegration;
pub const IAnimation = animation.IAnimation;
pub const Animation = animation.Animation;
pub const EAnimation = animation.EAnimation;
pub const AnimationSystem = animation.AnimationSystem;

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init(_: firefly.api.InitMode) !void {
    defer initialized = true;
    if (initialized)
        return;

    animation.init();
    // TODO

}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    animation.deinit();
    // TODO
}
