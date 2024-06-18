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

const JSON_TILE_SET: String =
    \\  {
    \\      "type": "tileset",
    \\      "name": "TestTileSet",
    \\      "texture": {
    \\          "name": "Atlas",
    \\          "file": "resources/atlas1616.png"
    \\      },
    \\      "tile_width": 16,
    \\      "tile_height": 16,
    \\      "tiles": [
    \\          { "name": "full", "props": "0,0|0|0|TERRAIN|0|-" },
    \\          { "name": "slope_1_1", "props": "1,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_2_1", "props": "2,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_3_1", "props": "3,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_4_1", "props": "4,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_5_1", "props": "5,0|0|0|TERRAIN|1|-" },
    \\          { "name": "rect_half_1", "props": "6,0|0|0|TERRAIN|1|-"},
    \\          { "name": "spiky_up", "props": "4,1|0|0|TERRAIN|1|-" },
    \\          { "name": "spike_up", "props": "2,1|0|0|TERRAIN|1|-" },
    \\          { "name": "rect_mini_1", "props": "6,1|0|0|TERRAIN|1|-" },
    \\
    \\          { "name": "circle", "props": "0,1|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_1_2", "props": "1,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_2_2", "props": "2,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_3_2", "props": "3,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_4_2", "props": "4,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_5_2", "props": "5,0|1|0|TERRAIN|1|-" },
    \\          { "name": "rect_half_2", "props": "6,0|0|1|TERRAIN|1|-"},
    \\          { "name": "spiky_down", "props": "4,1|0|1|TERRAIN|1|-" },
    \\          { "name": "spike_down", "props": "2,1|0|1|TERRAIN|1|-" },
    \\          { "name": "rect_mini_2", "props": "6,1|1|0|TERRAIN|1|-" },
    \\
    \\          { "name": "route", "props": "1,1|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_1_3", "props": "1,0|0|1|TERRAIN|1|-" },
    \\          { "name": "slope_2_3", "props": "2,0|0|1|TERRAIN|1|-" },
    \\          { "name": "slope_3_3", "props": "3,0|0|1|TERRAIN|1|-" },
    \\          { "name": "slope_4_3", "props": "4,0|0|1|TERRAIN|1|-" },
    \\          { "name": "slope_5_3", "props": "5,0|0|1|TERRAIN|1|-" },
    \\          { "name": "rect_half_3", "props": "7,0|0|0|TERRAIN|1|-" },
    \\          { "name": "spiky_right", "props": "5,1|0|0|TERRAIN|1|-" },
    \\          { "name": "spike_right", "props": "3,1|0|0|TERRAIN|1|-" },
    \\          { "name": "rect_mini_3", "props": "6,1|1|1|TERRAIN|1|-" },
    \\
    \\          { "name": "tileTemplate", "props": "1,0|0|0|-|0|-", "animation": "1000,1,0,0,0|1000,1,0,1,0|1000,1,0,1,1|1000,1,0,0,1" },
    \\          { "name": "slope_1_4", "props": "1,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_2_4", "props": "2,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_3_4", "props": "3,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_4_4", "props": "4,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_5_4", "props": "5,0|1|1|TERRAIN|1|-" },
    \\          { "name": "rect_half_4", "props": "7,0|1|0|TERRAIN|1|-" },
    \\          { "name": "spiky_left", "props": "5,1|1|0|TERRAIN|1|-" },
    \\          { "name": "spike_left", "props": "3,1|1|0|TERRAIN|1|-" },
    \\          { "name": "rect_mini_4", "props": "6,1|0|1|TERRAIN|1|-" },
    \\
    \\          { "name": "player", "props": "7,1|0|0|TERRAIN|1|-" }
    \\      ]
    \\  }
;

const JSON_TILE_MAPPING =
    \\ {
    \\     "name": "TileMapping",
    \\     "view_name": "TestView",
    \\     "tile_sets": [
    \\         { "code_offset": 1, "resource": { "name": "TestTileSet" }}
    \\     ],
    \\     "layer_mapping": [
    \\         {
    \\             "layer_name": "Background",
    \\             "offset": "0,0",
    \\             "blend_mode": "ALPHA",
    \\             "tint_color": "255,255,255,100",
    \\             "tile_sets_refs": "TestTileSet"
    \\         },
    \\         {
    \\             "layer_name": "Foreground",
    \\             "offset": "0,0",
    \\             "blend_mode": "ALPHA",
    \\             "tint_color": "255,255,255,255",
    \\             "tile_sets_refs": "TestTileSet" 
    \\         }
    \\     ],
    \\     "tile_grids": [
    \\         {
    \\             "name": "Grid1",
    \\             "layer": "Background",
    \\             "position": "0,0",
    \\             "spherical": false,
    \\             "tile_width": 16,
    \\             "tile_height": 16,
    \\             "grid_tile_width": 20,
    \\             "grid_tile_height": 10,
    \\             "codes": "0,0,0,0,0,0,0,0,0,2,32,22,12,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,32,9,9,22,12,0,0,0,0,0,0,0,0,0,0,0,0,0,2,32,39,0,0,29,22,12,0,0,0,0,0,0,0,0,0,0,0,2,32,0,0,19,19,0,0,22,12,0,0,0,0,0,0,0,0,0,2,32,0,0,0,0,0,0,0,0,22,12,0,0,0,0,0,0,0,2,32,0,0,0,0,0,0,0,0,0,0,22,12,0,0,0,0,0,2,32,0,0,0,0,0,0,0,0,0,0,0,0,22,12,0,0,0,2,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,22,12,0,2,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0"
    \\         },
    \\         {
    \\             "name": "Grid2",
    \\             "layer": "Foreground",
    \\             "position": "0,0",
    \\             "spherical": false,
    \\             "tile_width": 16,
    \\             "tile_height": 16,
    \\             "grid_tile_width": 20,
    \\             "grid_tile_height": 10,
    \\             "codes": "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,31,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,1,1,1,0,0,0,13,0,0,0,40,0,0,0,0,0,3,1,1,1,1,1,1,5,0,0,1,14,13,0,1,0,0,0,0,0,0,0,0,0,0,1,1,6,0,0,1,1,1,0,22,1,1,21,21,11,11,0,2,1,1,1,1,1,5,0,0,0,0,0,0,0,0,0,0,0,0,0,23,33,0,1,1,1,6,0,0,3,7,13,0,3,4,14,13,3,13,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1"
    \\         }
    \\     ]
    \\ }
;

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
    attributes.setAttribute(firefly.game.TaskAttributes.JSON_RESOURCE, JSON_TILE_SET);
    firefly.api.Task.runTaskByNameWith(
        firefly.game.JSONTasks.LOAD_TILE_SET,
        null,
        attributes,
    );

    // load tile mapping from json
    attributes.setAttribute(firefly.game.TaskAttributes.JSON_RESOURCE, JSON_TILE_MAPPING);
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
    //_ = tile_mapping.activate();
}
