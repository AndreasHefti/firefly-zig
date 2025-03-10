const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const Sprite = firefly.graphics.Sprite;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const EView = firefly.graphics.EView;
const ESprite = firefly.graphics.ESprite;
const Allocator = std.mem.Allocator;
const ETile = firefly.graphics.ETile;
const BlendMode = firefly.api.BlendMode;
const TileGrid = firefly.graphics.TileGrid;
const PosF = utils.PosF;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Tile Grid", loadWithView);
}

fn loadWithView() void {
    //firefly.api.rendering.setRenderBatch(1, 81920);

    const sprite_id = Sprite.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    _ = Texture.Component.new(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const tile_id = Entity.newActive(.{ .name = "TestEntity" }, .{
        ETransform{},
        ETile{ .sprite_id = sprite_id },
    });

    var tile_grid = TileGrid.Component.newAndGet(.{
        .name = "TileGrid1",
        .world_position = PosF{ 0, 0 },
        .dimensions = .{ 10, 10, 32, 32 },
    });
    TileGrid.Activation.activate(tile_grid.id);

    for (0..10) |y| {
        for (0..10) |x|
            tile_grid._grid[y][x] = tile_id;
    }

    firefly.api.subscribeUpdate(update);
}

fn update(_: firefly.api.UpdateEvent) void {
    if (TileGrid.Naming.byName("TileGrid1")) |grid| {
        grid.world_position[0] += 2;
        grid.world_position[1] += 2;
    }
}
