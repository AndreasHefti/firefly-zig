const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

const Texture = firefly.graphics.Texture;
const Sprite = firefly.graphics.Sprite;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const Animation = firefly.physics.Animation;
const BezierSplineIntegrator = firefly.physics.BezierSplineIntegrator;
const EasedValueIntegrator = firefly.physics.EasedValueIntegrator;
const AnimationSystem = firefly.physics.AnimationSystem;
const Allocator = std.mem.Allocator;
const Easing = utils.Easing;
const EShape = firefly.graphics.EShape;
const EMultiplier = firefly.api.EMultiplier;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(800, 600, 60, "Hello Bezier", init);
}

fn init() void {
    _ = Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/atlas1616.png",
        .is_mipmap = false,
    });

    const sprite_id = Sprite.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 3 * 16, 16, 16, 16 },
    });

    const anim_id = BezierSplineIntegrator.Component.createSubtype(Animation{
        .name = "BezierSplineExampleAnimation",
        .looping = true,
        .inverse_on_loop = true,
        .active_on_init = true,
    }, .{
        .property_ref_x = ETransform.Property.XPos,
        .property_ref_y = ETransform.Property.YPos,
        .property_ref_a = ETransform.Property.Rotation,
    });

    var spline = BezierSplineIntegrator.Component.byId(anim_id);
    spline.addSegment(.{
        .duration = 2500,
        .bezier = .{
            .p0 = .{ 50, 200 },
            .p1 = .{ 50, 50 },
            .p2 = .{ 200, 50 },
            .p3 = .{ 200, 200 },
        },
    });
    spline.addSegment(.{
        .duration = 4000,
        .bezier = .{
            .p0 = .{ 200, 200 },
            .p1 = .{ 200, 500 },
            .p2 = .{ 500, 500 },
            .p3 = .{ 500, 200 },
        },
    });

    const entity_id = Entity.new(.{ .name = "TestEntity2" }, .{
        ETransform{
            .position = .{ 0, 0 },
            .pivot = .{ 8, 8 },
            .scale = .{ 2, 2 },
        },
        ESprite{ .sprite_id = sprite_id },
        firefly.physics.EAnimations{},
    });

    if (firefly.physics.EAnimations.Component.byIdOptional(entity_id)) |e_anim|
        e_anim.animations.set(anim_id);

    Entity.Activation.activate(entity_id);

    _ = Entity.newActive(.{ .name = "TestEntity5" }, .{
        ETransform{ .position = .{ 0, 0 } },
        EShape{
            .shape_type = firefly.api.ShapeType.CIRCLE,
            .vertices = firefly.api.allocFloatArray([_]utils.Float{ 50, 200, 1, 50, 50, 1, 200, 50, 1, 200, 200, 1, 200, 500, 1, 500, 500, 1, 500, 200, 1 }),
            .color = .{ 150, 150, 150, 100 },
            .fill = true,
            .thickness = 10,
        },
    });
}
