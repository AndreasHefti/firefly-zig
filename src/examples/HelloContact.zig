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
//const DebugCollisionResolver = firefly.physics.DebugCollisionResolver;
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
    }, init, null);
}

fn init() void {
    firefly.physics.ContactSystem.System.activate();
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
        firefly.api.EControl{ .update = control },                                            ETransform{ .position = .{ x, 0 } }, ESprite{ .template_id = sprite_id },
        EMovement{
            .gravity_vector = .{ 2, firefly.physics.EARTH_GRAVITY },
            .mass = 1,
            .integrator = firefly.physics.EulerIntegrator,
        },
        EShape{
            .shape_type = ShapeType.RECTANGLE,
            .fill = false,
            .vertices = firefly.api.allocFloatArray([_]Float{ 0, 0, 33, 33 }),
            .color = .{ 0, 0, 255, 255 },
        },
        EContactScan{ .collision_resolver = firefly.physics.getDebugCollisionResolver().id },
        ContactConstraint{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } }, .full_scan = true },
    });

    x += 50;

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ x, 200 } },
        ESprite{ .template_id = sprite_id },
        EContact{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } } },
    });

    // tile grid
    const tile_id = Entity.newActive(.{ .name = "TestEntity" }, .{
        ETransform{},
        ETile{ .sprite_template_id = sprite_id },
        EContact{ .bounds = .{ .rect = .{ 0, 0, 32, 32 } } },
    });

    var tile_grid = TileGrid.Component.newAndGet(.{
        .name = "TileGrid1",
        .world_position = PosF{ 50, 300 },
        .dimensions = .{ 10, 3, 32, 32 },
    });
    TileGrid.Activation.activate(tile_grid.id);

    for (0..3) |y| {
        for (0..10) |_x|
            tile_grid._grid[y][_x] = tile_id;
    }
}

fn control(ctx: *firefly.api.CallContext) void {
    const scan = EContactScan.Component.byId(ctx.caller_id);
    const shape = EShape.Component.byId(ctx.caller_id);

    if (scan.hasAnyContact()) {
        shape.color[0] = 255;
        shape.color[2] = 0;
    } else {
        shape.color[0] = 0;
        shape.color[2] = 255;
    }
}
