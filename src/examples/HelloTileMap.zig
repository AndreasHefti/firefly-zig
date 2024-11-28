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
const view_name: String = "TestView";
const layer1: String = "Background";
const layer2: String = "Foreground";

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(room_pixel_width, room_pixel_height, 60, "Hello Tile Map", init);
}

fn init() void {
    firefly.game.initJSONIntegration();

    // view, layer are auto-created by tile mapping if not present
    _ = graphics.View.Component.new(.{
        .name = view_name,
        .position = .{ 0, 0 },
        .projection = .{
            .width = room_pixel_width,
            .height = room_pixel_height,
            .zoom = zoom,
        },
    });

    // load atlas and create tile set with task
    firefly.api.Task.runTaskByNameWith(
        firefly.game.Tasks.JSON_LOAD_TILE_SET,
        firefly.api.CallContext.new(
            null,
            .{
                .{ game.TaskAttributes.JSON_RESOURCE_TILE_SET_FILE, "resources/example_tileset.json" },
            },
        ),
    );

    // load tile mapping from json
    firefly.api.Task.runTaskByNameWith(
        firefly.game.Tasks.JSON_LOAD_TILE_MAPPING,
        firefly.api.CallContext.new(
            null,
            .{
                .{ game.TaskAttributes.JSON_RESOURCE_TILE_MAP_FILE, "resources/example_tilemap1.json" },
                .{ game.TaskAttributes.VIEW_NAME, view_name },
            },
        ),
    );

    // activate
    game.TileMapping.Activation.activateByName("TileMapRoom1");
}
