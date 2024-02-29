const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const Animation = firefly.physics.Animation;
const EasedValueIntegration = firefly.physics.EasedValueIntegration;
const StringBuffer = utils.StringBuffer;
const IAnimation = firefly.physics.IAnimation;

const Float = utils.Float;

test "EasedValueIntegration" {
    try inari.firefly.initTesting();
    defer inari.firefly.deinit();

    // The animated value
    var value: Float = 0.0;

    // creating an animation gives you a animation interface with opaque integration type back.
    // Most functions are exposed to the opaque interface and systems or components can work with the interface
    var animation_interface: *IAnimation = Animation(EasedValueIntegration).new(
        5000,
        true,
        true,
        true,
        EasedValueIntegration{
            .start_value = 0.0,
            .end_value = 100.0,
            .easing = utils.Easing_Linear,
            .property_ref = &value,
        },
    );
    // If one need the concrete animation struct, one can explicit cast is by using the getAnimation
    // function provided by the corresponding integration type.
    var animation: *Animation(EasedValueIntegration) = EasedValueIntegration.getAnimation(animation_interface);

    try std.testing.expect(value == 0.0);
    for (0..100) |i| {
        const t: Float = utils.usize_f32(i);
        const t_n = 1.0 / 100.0 * t;
        animation.integrateAt(t_n);
        try std.testing.expect(@round(value) == t);
    }
}
