const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const game = firefly.game;

const View = firefly.graphics.View;
const EView = firefly.graphics.EView;

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

    firefly.api.Task.runTaskByNameWith(
        firefly.game.Tasks.JSON_LOAD_TILED_TILE_SET,
        firefly.api.CallContext.new(
            null,
            .{
                .{ firefly.game.TaskAttributes.FILE_RESOURCE, "resources/tiled/tileset1616.json" },
            },
        ),
    );
}
