const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
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
const Allocator = std.mem.Allocator;
const Float = utils.Float;
const Vector2f = utils.Vector2f;
const PosF = utils.PosF;
const ContactBounds = firefly.physics.ContactBounds;
const ContactConstraint = firefly.physics.ContactConstraint;
const Index = utils.Index;
const ETile = firefly.graphics.ETile;
const TileGrid = firefly.graphics.TileGrid;
const WindowFlag = firefly.api.WindowFlag;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.startWindow(.{
        .width = 800,
        .height = 600,
        .fps = 60,
        .title = "Hello Contact",
        .flags = &[_]WindowFlag{WindowFlag.FLAG_WINDOW_RESIZABLE},
    }, init);
}

fn init() void {
    firefly.physics.ContactSystem.activate();
    Texture.new(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    const sprite = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    var x: Float = 10;
    _ = Entity.new(.{})
        .withControl(control, null, true)
        .withComponent(ETransform{ .position = .{ x, 0 } })
        .withComponent(ESprite{ .template_id = sprite.id })
        .withComponent(EMovement{ .gravity = .{ 2, firefly.physics.Gravity }, .mass = 1, .mass_factor = 0.3, .integrator = firefly.physics.EulerIntegrator })
        .withComponent(EContactScan{ .collision_resolver = DebugCollisionResolver })
        .withConstraint(.{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } }, .full_scan = true })
        .withComponent(EShape{ .shape_type = ShapeType.RECTANGLE, .fill = false, .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 33, 33 }), .color = .{ 0, 0, 255, 255 } })
        .activate();
    x += 50;

    _ = Entity.new(.{})
        .withComponent(ETransform{ .position = .{ x, 200 } })
        .withComponent(ESprite{ .template_id = sprite.id })
        .withComponent(EContact{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } } })
        .activate();

    // tile grid
    const tile = Entity.new(.{ .name = "TestEntity" })
        .withComponent(ETransform{})
        .withComponent(ETile{ .sprite_template_id = sprite.id })
        .withComponent(EContact{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } } })
        .activate();

    var tile_grid: *TileGrid = TileGrid.new(.{
        .name = "TileGrid1",
        .world_position = PosF{ 50, 300 },
        .dimensions = .{ 10, 3, 32, 32 },
    }).activate();

    for (0..3) |y| {
        for (0..10) |_x|
            tile_grid._grid[y][_x] = tile.id;
    }
}

fn control(entity_id: Index, _: Index) void {
    const scan = EContactScan.byId(entity_id) orelse return;
    const shape = EShape.byId(entity_id) orelse return;

    if (scan.hasAnyContact()) {
        shape.color[0] = 255;
        shape.color[2] = 0;
    } else {
        shape.color[0] = 0;
        shape.color[2] = 255;
    }
}
