const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const game = firefly.game;
const api = firefly.api;
const graphics = firefly.graphics;
const physics = firefly.physics;

const String = utils.String;
const Index = utils.Index;

const texture_name = "Atlas";
const view_name = "TestView";
const cam_name = "Camera1";
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
const start_scene_name = "StartScene";
const end_scene_name = "EndScene";
const terrain_constraint_name: String = "TerrainConstraint";

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(
        screen_width,
        screen_height,
        60,
        "Hello Player",
        init,
    );
}

fn init() void {

    // view with two layer
    var view = graphics.View.new(.{
        .name = view_name,
        .position = .{ 0, 0 },
        .scale = .{ scale, scale },
        .projection = .{
            .width = screen_width,
            .height = screen_height,
            .zoom = zoom,
        },
    });

    _ = view.withControlOf(
        game.SimplePivotCamera{
            .name = cam_name,
            .pixel_perfect = false,
            .snap_to_bounds = .{ 0, 0, room_pixel_width, room_pixel_height },
            .velocity_relative_to_pivot = .{ 0.5, 0.5 },
            .enable_parallax = true,
        },
        true,
    );

    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_LEFT, api.InputButtonType.LEFT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_RIGHT, api.InputButtonType.RIGHT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_SPACE, api.InputButtonType.FIRE_1);

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
    })
        .withActivationTask(
        api.Task{
            .name = "CreatePlayer",
            .run_once = true,
            .function = create_player,
        },
        null,
    );

    room.start();
}

var player_pos_ptr: *utils.PosF = undefined;
fn create_player(_: api.CallContext) void {
    const sprite_id = graphics.SpriteTemplate.new(.{
        .texture_name = texture_name,
        .texture_bounds = utils.RectF{ 7 * 16, 1 * 16, 16, 16 },
    }).id;

    // create player entity
    _ = api.Entity.new(.{ .name = "Player" })
        .withComponent(graphics.ETransform{
        .position = .{ 32, 32 },
        .pivot = .{ 0, 0 },
    })
        .withComponent(graphics.EView{
        .view_id = graphics.View.idByName(view_name).?,
        .layer_id = graphics.Layer.idByName(layer2).?,
    })
        .withComponent(graphics.ESprite{ .template_id = sprite_id })
        .withComponent(physics.EMovement{
        .mass = 50,
        .max_velocity_south = 80,
        .max_velocity_east = 50,
        .max_velocity_west = 50,
        .integrator = physics.EulerIntegrator,
    })
        .withComponent(physics.EContactScan{
        .collision_resolver = game.PlatformerCollisionResolver.new(.{
            .contact_bounds = .{ 4, 1, 8, 14 },
            .view_id = graphics.View.idByName(view_name),
            .layer_id = graphics.Layer.idByName(layer2),
        }),
    })
        .entity()
        .withActiveControlOf(game.SimplePlatformerHorizontalMoveControl{
        .button_left = api.InputButtonType.LEFT,
        .button_right = api.InputButtonType.RIGHT,
    })
        .withActiveControlOf(game.SimplePlatformerJumpControl{
        .jump_button = api.InputButtonType.FIRE_1,
        .jump_impulse = 200,
    })
        .activate();

    // apply player position as pivot for camera
    var cam = game.SimplePivotCamera.byName(cam_name).?;
    player_pos_ptr = &graphics.ETransform.byName("Player").?.position;
    cam.pivot = player_pos_ptr;
}
