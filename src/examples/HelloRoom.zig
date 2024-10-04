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
const scale = 1;
const tile_width: usize = 16;
const tile_height: usize = 16;
const room_tile_width: usize = 20;
const room_tile_height: usize = 10;
const room_pixel_width: usize = tile_width * room_tile_width;
const room_pixel_height: usize = tile_height * room_tile_height;
const screen_width: usize = 600;
const screen_height: usize = 400;
const layer1: String = "Background";
const layer2: String = "Foreground";
const start_scene_name = "enterRoom";
const end_scene_name = "exitRoom";

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

const speed = 1;
var pivot: utils.PosF = .{ 0, 0 };

fn init() void {

    // view component
    // two layers get automatically applied when loading the room tile maps
    // see JSON file: resources/example_tilemap1.json
    const view_id = graphics.View.Component.new(.{
        .name = view_name,
        .position = .{ 0, 0 },
        .scale = .{ scale, scale },
        .pivot = .{ 0, 0 },
        .projection = .{
            .width = screen_width,
            .height = screen_height,
            .zoom = zoom,
        },
    });

    // Room camera control with parallax scrolling according to layer data
    _ = graphics.View.Control.addOf(
        view_id,
        game.SimplePivotCamera{
            .name = "Camera1",
            .pixel_perfect = false,
            .snap_to_bounds = .{ 0, 0, room_pixel_width, room_pixel_height },
            .pivot = &pivot,
            .velocity_relative_to_pivot = .{ 0.5, 0.5 },
            .enable_parallax = true,
        },
        true,
    );

    // Key input for fake player and camera pivot
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_UP, api.InputButtonType.UP);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_DOWN, api.InputButtonType.DOWN);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_LEFT, api.InputButtonType.LEFT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_RIGHT, api.InputButtonType.RIGHT);
    // add Control to view for key input
    // key input is moving the invisible pivot point of the camera when the Room is active
    graphics.View.Control.add(view_id, pivot_control, "KeyControl", false);

    // crate start scene
    _ = graphics.Scene.Component.new(.{
        .name = start_scene_name,
        .update_action = startSceneAction,
        .scheduler = api.Timer.getScheduler(20),
    });

    // load room from file
    api.Task.runTaskByNameWith(
        game.Tasks.JSON_LOAD_ROOM,
        firefly.api.CallContext.new(
            null,
            .{
                .{ game.TaskAttributes.FILE_RESOURCE, "resources/example_room1.json" },
                .{ game.TaskAttributes.VIEW_NAME, view_name },
            },
        ),
    );

    // and just start the Room with no player
    game.Room.startRoom("Room1", "no player", roomLoaded);
}

fn roomLoaded(_: Index) void {
    std.debug.print("Room running", .{});
}

// key input is moving the invisible pivot point of the camera when the Room is active
fn pivot_control(_: *firefly.api.CallContext) void {
    if (firefly.api.input.checkButtonPressed(api.InputButtonType.UP))
        pivot[1] -= speed;
    if (firefly.api.input.checkButtonPressed(api.InputButtonType.DOWN))
        pivot[1] += speed;
    if (firefly.api.input.checkButtonPressed(api.InputButtonType.LEFT))
        pivot[0] -= speed;
    if (firefly.api.input.checkButtonPressed(api.InputButtonType.RIGHT))
        pivot[0] += speed;
}

// rudimentary implementation of an action control for the start scene
// just creates a rectangle shape entity that overlaps the while screen
// with initial black color, fading alpha to 0 with ALPHA blend of the background
// Room view will appear from black screen. When alpha is 0, action successfully  ends
// and pivot control is been activated.
var start_scene_init = false;
var color: *utils.Color = undefined;
fn startSceneAction(ctx: *api.CallContext) void {
    if (!start_scene_init) {
        // create overlay entity
        const entity_id = api.Entity.build(.{ .name = "StartSceneEntity" })
            .withComponent(graphics.ETransform{
            .scale = .{ screen_width, screen_height },
        })
            .withComponent(graphics.EView{
            .view_id = graphics.View.Naming.getId(view_name),
            .layer_id = graphics.Layer.Naming.getId(layer2),
        })
            .withComponent(graphics.EShape{
            .blend_mode = api.BlendMode.ALPHA,
            .color = .{ 0, 0, 0, 255 },
            .shape_type = api.ShapeType.RECTANGLE,
            .fill = true,
            .vertices = api.allocFloatArray([_]utils.Float{ 0, 0, 1, 1 }),
        }).activateGetId();
        color = &graphics.EShape.Component.byId(entity_id).color;
        start_scene_init = true;
    }

    color[3] -= @min(10, color[3]);

    if (color[3] <= 0) {
        api.Entity.Naming.dispose("StartSceneEntity");
        api.Control.Activation.activateByName("KeyControl");
        ctx.result = api.ActionResult.Success;
    } else {
        ctx.result = api.ActionResult.Running;
    }
}
