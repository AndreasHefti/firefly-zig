const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const test_dep = @import("../examples/HelloTileSet.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const game = firefly.game;

const View = firefly.graphics.View;
const EView = firefly.graphics.EView;
const TileSet = firefly.game.TileSet;

const String = utils.String;

/// This loads a tile set from given JSON data and makes an Entity for each defined
/// tile in the set with contact and animation if defined and draws all to the screen.
/// If there is a contact mask, the mask is displayed together with the tile in red shape.
pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Tiled Tile Set", init);
}

fn init() void {
    // we need to initialize the Tiled integration tasks fist
    firefly.game.initTiledIntegration();

    const viewId = View.Component.newActive(.{
        .name = "TestView",
        .position = .{ 0, 0 },
        .projection = .{
            .width = 600,
            .height = 400,
        },
    });

    firefly.api.Task.runTaskByNameWith(
        firefly.game.Tasks.JSON_LOAD_TILED_TILE_SET,
        firefly.api.CallContext.new(
            null,
            .{
                .{ firefly.game.TaskAttributes.JSON_RESOURCE_TILE_SET_FILE, "resources/tiled/tileset1616.json" },
            },
        ),
    );

    var tile_set: *TileSet = TileSet.Naming.byName("TestTileSet").?;
    TileSet.Activation.activate(tile_set.id);

    var next = tile_set.tile_templates.slots.nextSetBit(0);
    var x: usize = 50;
    var y: usize = 50;
    while (next) |i| {
        if (tile_set.tile_templates.get(i)) |tile_template| {
            test_dep.createTile(
                tile_set,
                tile_template,
                firefly.utils.usize_f32(x),
                firefly.utils.usize_f32(y),
                viewId,
            );
            x += 50;
            if (x > 500) {
                x = 50;
                y += 50;
            }
        }
        next = tile_set.tile_templates.slots.nextSetBit(i + 1);
    }

    // and convert the tiled tile set to an in-house JSON tile set
    convertAndSaveTiledTileSet() catch |err| api.handleUnknownError(err);
}

fn convertAndSaveTiledTileSet() !void {
    const dest_file = "zig-out/tileset1616";
    const encryption_pwd = "passwordpasswordpasswordpassword";
    const tiled_tile_set = try game.json.parseJSONFromFile(
        "resources/tiled/tileset1616.json",
        null,
        game.json.TiledTileSet,
    );

    const tile_set = game.json.convertTiledTileSet(tiled_tile_set);
    const json = std.json.Stringify.valueAlloc(
        api.LOAD_ALLOC,
        tile_set,
        .{ .emit_null_optional_fields = false, .whitespace = .minified },
    ) catch |err| {
        api.Logger.err("Failed to stringify json for tiled tile set", .{});
        return err;
    };

    try api.writeToFile(dest_file, json, encryption_pwd);
}
