const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const game = firefly.game;

const String = utils.String;

const zoom = 4;
const tile_width: usize = 16;
const tile_height: usize = 16;
const room_tile_width = 20;
const room_tile_height = 10;
const room_pixel_width = tile_width * room_tile_width * zoom;
const room_pixel_height = tile_height * room_tile_height * zoom;
const layer1: String = "Background";
const layer2: String = "Foreground";

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(
        room_pixel_width,
        room_pixel_height,
        60,
        "Hello Tile Map",
        init,
    );
}

fn init() void {
    // view with two layer
    const view_id = graphics.View.new(.{
        .name = "TestView",
        .position = .{ 0, 0 },
        .projection = .{
            .width = room_pixel_width,
            .height = room_pixel_height,
            .zoom = zoom,
        },
    }).id;

    const layer1_id = graphics.Layer.new(.{
        .name = layer1,
        .view_id = view_id,
        .order = 1,
    }).id;
    const layer2_id = graphics.Layer.new(.{
        .name = layer2,
        .view_id = view_id,
        .order = 2,
    }).id;

    // load atlas and create tile set with task
    var attributes = firefly.api.Attributes.new();
    defer attributes.deinit();
    attributes.set(firefly.game.TaskAttributes.FILE_RESOURCE, "resources/example_tileset.json");
    firefly.api.Task.runTaskByNameWith(
        firefly.game.JSONTasks.LOAD_TILE_SET,
        null,
        attributes,
    );

    // load tile mapping from json
    attributes.set(firefly.game.TaskAttributes.FILE_RESOURCE, "resources/example_tilemap1.json");
    firefly.api.Task.runTaskByNameWith(
        firefly.game.JSONTasks.LOAD_TILE_MAPPING,
        null,
        attributes,
    );

    // activate
    graphics.Layer.activateById(layer1_id, true);
    graphics.Layer.activateById(layer2_id, true);
    graphics.View.activateById(view_id, true);
    game.TileMapping.activateByName("TileMapping", true);
}
