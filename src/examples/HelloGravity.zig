const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EMovement = firefly.physics.EMovement;
const Allocator = std.mem.Allocator;
const Float = utils.Float;
const Vector2f = utils.Vector2f;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(800, 600, 60, "Hello Gravity", init);
}

fn init() void {
    Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    var x: Float = 10;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .mass = 1 })
        .activate();

    x += 50;

    // TODO VerletIntegrator seems not to do right here
    // _ = Entity.newAnd(.{})
    //     .with(ETransform{ .position = .{ x, 0 } })
    //     .with(ESprite{ .template_id = sprite_id })
    //     .with(EMovement{ .mass = 1, .integrator = firefly.physics.VerletIntegrator })
    //     .activate();

    // x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .mass = 1, .integrator = firefly.physics.EulerIntegrator })
        .activate();

    x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .mass = 1, .mass_factor = 0.2 })
        .activate();

    x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .mass = 1, .mass_factor = 0.2, .integrator = firefly.physics.EulerIntegrator })
        .activate();
    x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .mass = 1, .mass_factor = 0.2, .max_velocity_south = 50 })
        .activate();

    x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .mass = 1, .mass_factor = 0.2, .max_velocity_south = 50, .integrator = firefly.physics.EulerIntegrator })
        .activate();

    x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .mass = 1, .mass_factor = 0.2, .max_velocity_south = 100 })
        .activate();

    x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .mass = 1, .mass_factor = 0.2, .max_velocity_south = 100, .integrator = firefly.physics.EulerIntegrator })
        .activate();

    x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .gravity = Vector2f{ 2, firefly.physics.Gravity }, .mass = 1, .mass_factor = 0.2, .integrator = firefly.physics.EulerIntegrator })
        .activate();

    x += 50;

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .activate();
}
