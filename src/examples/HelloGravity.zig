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
    _ = Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    var x: Float = 10;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{},
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .integrator = firefly.physics.EulerIntegrator },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .integrator = firefly.physics.VerletIntegrator },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .integrator = firefly.physics.FPSStepIntegrator },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .mass = 1 },
        ETransform{ .position = .{ x, 0 } },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .mass = 1, .integrator = firefly.physics.EulerIntegrator },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .max_velocity_south = 50 },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .max_velocity_south = 50, .integrator = firefly.physics.EulerIntegrator },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .max_velocity_south = 100 },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .max_velocity_south = 100, .integrator = firefly.physics.EulerIntegrator },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
        EMovement{ .gravity_vector = Vector2f{ 2, firefly.physics.EARTH_GRAVITY }, .integrator = firefly.physics.EulerIntegrator },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 0 } },
        ESprite{ .sprite_id = sprite_id },
    });
}
