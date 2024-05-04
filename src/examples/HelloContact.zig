const std = @import("std");
const inari = @import("../inari/inari.zig");
const firefly = inari.firefly;
const utils = inari.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const EShape = firefly.graphics.EShape;
const ShapeType = firefly.api.ShapeType;
const EContact = firefly.physics.EContact;
const EContactScan = firefly.physics.EContactScan;
const DebugCollisionResolver = firefly.physics.DebugCollisionResolver;
const ESprite = firefly.graphics.ESprite;
const EMovement = firefly.physics.EMovement;
const EControl = firefly.api.EControl;
const Allocator = std.mem.Allocator;
const Float = utils.Float;
const Vector2f = utils.Vector2f;
const PosF = utils.PosF;
const ContactBounds = firefly.physics.ContactBounds;
const ContactConstraint = firefly.physics.ContactConstraint;
const Index = utils.Index;
const ETile = firefly.graphics.ETile;
const TileGrid = firefly.graphics.TileGrid;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.CoreSystems.ContactSystem.activate();
    firefly.Engine.CoreSystems.EntityControlSystem.activate();
    firefly.physics.addDummyContactMap(null, null);
    firefly.Engine.start(800, 600, 60, "Hello Contact", init);
}

fn init() void {
    Texture.newAnd(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    const sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    var x: Float = 10;

    _ = Entity.newAnd(.{})
        .with(ETransform{ .position = .{ x, 0 } })
        .with(ESprite{ .template_id = sprite_id })
        .with(EMovement{ .gravity = .{ 2, firefly.physics.Gravity }, .mass = 1, .mass_factor = 0.3, .integrator = firefly.physics.EulerIntegrator })
        .withAnd(EContactScan{ .collision_resolver = DebugCollisionResolver })
        .withConstraintAnd(.{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } }, .full_scan = true })
        .with(EShape{ .shape_type = ShapeType.RECTANGLE, .fill = false, .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 33, 33 }), .color = .{ 0, 0, 255, 255 } })
        .withAnd(EControl{})
        .withControlAnd(control)
        .activate();

    x += 50;

    _ = Entity.newAnd(.{})
        .with(ETransform{ .position = .{ x, 200 } })
        .with(ESprite{ .template_id = sprite_id })
        .with(EContact{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } } })
        .activate();

    // tile grid
    const tile = Entity.newAnd(.{ .name = "TestEntity" })
        .with(ETransform{})
        .with(ETile{ .sprite_template_id = sprite_id })
        .with(EContact{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } } })
        .activate();

    var tile_grid: *TileGrid = TileGrid.newAnd(.{
        .name = "TileGrid1",
        .world_position = PosF{ 50, 300 },
        .dimensions = .{ 10, 3, 32, 32 },
    }).activate();

    for (0..3) |y| {
        for (0..10) |_x|
            tile_grid._grid[y][_x] = tile.id;
    }
}

fn control(id: Index) void {
    if (EContactScan.byId(id)) |scan| {
        if (EShape.byId(id)) |shape| {
            if (scan.hasAnyContact()) {
                shape.color[0] = 255;
                shape.color[2] = 0;
            } else {
                shape.color[0] = 0;
                shape.color[2] = 255;
            }
        }
    }
}
