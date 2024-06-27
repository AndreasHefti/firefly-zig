const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const game = firefly.game;
const api = firefly.api;
const graphics = firefly.graphics;

const String = utils.String;
const Index = utils.Index;

const view_name = "TestView";
const zoom = 4;
const tile_width: usize = 16;
const tile_height: usize = 16;
const room_tile_width: usize = 20;
const room_tile_height: usize = 10;
const room_pixel_width: usize = tile_width * room_tile_width;
const room_pixel_height: usize = tile_height * room_tile_height;
const screen_width: usize = 400;
const screen_height: usize = 300;
const layer1: String = "Background";
const layer2: String = "Foreground";
const start_scene_name = "StartScene";
const end_scene_name = "EndScene";

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(
        screen_width,
        screen_height,
        60,
        "Hello Room",
        init,
    );
}

const speed = 2;
var pivot: utils.PosF = .{ 0, 0 };

fn init() void {

    // view with two layer
    var view = graphics.View.new(.{
        .name = view_name,
        .position = .{ 0, 0 },
        .projection = .{
            .width = screen_width,
            .height = screen_height,
            .zoom = zoom,
        },
    });

    _ = view.withControlOf(game.SimplePivotCamera{
        .name = "Camera1",
        .pixel_perfect = false,
        .snap_to_bounds = .{ 0, 0, room_pixel_width, room_pixel_height },
        .pivot = &pivot,
        .velocity_relative_to_pivot = .{ 0.5, 0.5 },
        .enable_parallax = true,
    });

    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_UP, api.InputButtonType.UP);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_DOWN, api.InputButtonType.DOWN);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_LEFT, api.InputButtonType.LEFT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_RIGHT, api.InputButtonType.RIGHT);

    // crate start and end scene
    // _ = graphics.Scene.new(.{
    //     .name = start_scene_name,
    //     .update_action = startSceneAction,
    //     .scheduler = api.Timer.getScheduler(20)
    // });
    // _ = graphics.Scene.new(.{
    //     .name = end_scene_name,
    //     .update_action = endSceneAction,
    //     .scheduler = api.Timer.getScheduler(20)
    // });

    // create new Room
    var room = game.Room.new(.{
        .name = "Test Room1",
        .bounds = .{ 0, 0, room_pixel_width, room_pixel_height },
    })
        .withLoadTaskByName(game.JSONTasks.LOAD_TILE_SET, .{
        .{ game.TaskAttributes.FILE_RESOURCE, "resources/example_tileset.json" },
    })
        .withLoadTaskByName(game.JSONTasks.LOAD_TILE_MAPPING, .{
        .{ game.TaskAttributes.FILE_RESOURCE, "resources/example_tilemap1.json" },
        .{ game.TaskAttributes.ATTR_VIEW_NAME, view_name },
    });

    room.start();
    firefly.Engine.subscribeUpdate(pivot_control);
}

fn pivot_control(_: firefly.api.UpdateEvent) void {
    if (firefly.api.input.checkButtonPressed(api.InputButtonType.UP))
        pivot[1] -= speed;
    if (firefly.api.input.checkButtonPressed(api.InputButtonType.DOWN))
        pivot[1] += speed;
    if (firefly.api.input.checkButtonPressed(api.InputButtonType.LEFT))
        pivot[0] -= speed;
    if (firefly.api.input.checkButtonPressed(api.InputButtonType.RIGHT))
        pivot[0] += speed;
}

var start_scene_init = false;
fn startSceneAction(_: Index) api.ActionResult {
    // if (!start_scene_init) {
    //     // create overlay entity
    //     api.Entity.new(.{})
    //         .withComponent(graphics.ETransform{
    //             .
    //         })

    // }
}

fn endSceneAction(_: Index) api.ActionResult {}
