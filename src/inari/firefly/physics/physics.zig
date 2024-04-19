const std = @import("std");
const inari = @import("../../inari.zig");
const animation = @import("animation.zig");
const movement = @import("movement.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const Float = utils.Float;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const Gravity: Float = 9.8;

pub const EasedValueIntegration = animation.EasedValueIntegration;
pub const IAnimation = animation.IAnimation;
pub const Animation = animation.Animation;
pub const EAnimation = animation.EAnimation;
pub const AnimationIntegration = animation.AnimationIntegration;
pub const EMovement = movement.EMovement;
pub const SimpleStepIntegrator = movement.SimpleStepIntegrator;
pub const VerletIntegrator = movement.VerletIntegrator;
pub const EulerIntegrator = movement.EulerIntegrator;

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init(_: firefly.api.InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    animation.init();
    movement.init();
    // TODO

}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    animation.deinit();
    movement.deinit();
    // TODO
}
