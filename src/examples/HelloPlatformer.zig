const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const game = firefly.game;
const api = firefly.api;
const graphics = firefly.graphics;
const physics = firefly.physics;

const String = utils.String;
const Index = utils.Index;

const player_name = "Player1";
const texture_name = "Atlas";
const view_name = "TestView";
const cam_name = "Camera1";
const room1_name = "Room1";
const room2_name = "Room2";
const room3_name = "Room3";
const zoom = 4;
const scale = 1;
const tile_width: usize = 16;
const tile_height: usize = 16;
const screen_width: usize = 600;
const screen_height: usize = 400;
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

const speed = 1;
var pivot: utils.PosF = .{ 0, 0 };

fn init() void {
    firefly.physics.ContactSystem.activate();
    firefly.physics.ContactGizmosRenderer.activate();
    firefly.physics.ContactScanGizmosRenderer.activate();

    // create view with two layer
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

    // create camera control (apply player pivot and room bounds later)
    _ = view.withControlOf(
        game.SimplePivotCamera{
            .name = cam_name,
            .pixel_perfect = false,
            .snap_to_bounds = .{ 0, 0, 0, 0 },
            .velocity_relative_to_pivot = .{ 0.5, 0.5 },
            .enable_parallax = true,
        },
        true,
    );

    // create key control
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_A, api.InputButtonType.LEFT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_D, api.InputButtonType.RIGHT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_SPACE, api.InputButtonType.FIRE_1);

    // crate transition scene
    game.SimpleRoomTransitionScene.init(screen_width, screen_height, view_name, layer2);

    // load first (entry) room from file
    api.Task.runTaskByNameWith(
        game.Tasks.JSON_LOAD_ROOM,
        firefly.api.CallContext.withAttributes(
            null,
            .{
                .{ game.TaskAttributes.FILE_RESOURCE, "resources/example_room2.json" },
                .{ game.TaskAttributes.VIEW_NAME, view_name },
            },
        ),
    );
    api.Task.runTaskByNameWith(
        game.Tasks.JSON_LOAD_ROOM,
        firefly.api.CallContext.withAttributes(
            null,
            .{
                .{ game.TaskAttributes.FILE_RESOURCE, "resources/example_room1.json" },
                .{ game.TaskAttributes.VIEW_NAME, view_name },
            },
        ),
    );
    api.Task.runTaskByNameWith(
        game.Tasks.JSON_LOAD_ROOM,
        firefly.api.CallContext.withAttributes(
            null,
            .{
                .{ game.TaskAttributes.FILE_RESOURCE, "resources/example_room3.json" },
                .{ game.TaskAttributes.VIEW_NAME, view_name },
            },
        ),
    );

    // add player and init cam for room
    _ = game.Room.byName(room1_name).?.withTask(
        api.Task{
            .name = "CreatePlayer",
            .run_once = true,
            .function = createPlayer,
        },
        api.CompositeLifeCycle.ACTIVATE,
        null,
    );

    // and just start the Room
    game.Room.startRoom(room1_name, player_name, roomLoaded);
}

fn roomLoaded(_: Index) void {
    std.debug.print("Room running!!!\n", .{});
}

var player_pos_ptr: *utils.PosF = undefined;
fn createPlayer(_: *api.CallContext) void {
    const sprite_id = graphics.SpriteTemplate.new(.{
        .texture_name = texture_name,
        .texture_bounds = utils.RectF{ 7 * 16, 1 * 16, 16, 16 },
    }).id;

    // create player entity
    _ = api.Entity.new(.{
        .name = player_name,
    })
        .withGroupAspect(game.Groups.PAUSEABLE)
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
        .max_velocity_south = 180,
        .max_velocity_east = 50,
        .max_velocity_west = 50,
        .integrator = physics.EulerIntegrator,
    })
        .withComponent(physics.EContactScan{ .collision_resolver = game.PlatformerCollisionResolver.new(
        .{
            .contact_bounds = .{ 4, 1, 8, 14 },
            .view_id = graphics.View.idByName(view_name),
            .layer_id = graphics.Layer.idByName(layer2),
        },
    ) })
        .withConstraint(.{
        .name = "Room_Transition",
        .layer_id = graphics.Layer.idByName(layer2),
        .bounds = .{ .rect = .{ 6, 6, 4, 4 } },
        .type_filter = physics.ContactTypeKind.of(.{game.ContactTypes.ROOM_TRANSITION}),
        .full_scan = true,
        .callback = game.TransitionContactCallback,
    })
        .entity()
        .withActiveControlOf(game.SimplePlatformerHorizontalMoveControl{
        .button_left = api.InputButtonType.LEFT,
        .button_right = api.InputButtonType.RIGHT,
    })
        .withActiveControlOf(game.SimplePlatformerJumpControl{
        .jump_button = api.InputButtonType.FIRE_1,
        .jump_impulse = 140,
        .double_jump = true,
    })
    //     .withComponent(graphics.EShape{
    //     .color = .{ 0, 255, 0, 255 },
    //     .fill = false,
    //     .shape_type = api.ShapeType.RECTANGLE,
    //     .thickness = 0.3,
    //     .vertices = api.allocFloatArray(.{ 6, 6, 4, 4 }),
    // })
        .activate();

    // apply player position as pivot for camera
    var cam = game.SimplePivotCamera.byName(cam_name).?;
    player_pos_ptr = &graphics.ETransform.byName(player_name).?.position;
    cam.pivot = player_pos_ptr;
    cam.snap_to_bounds = game.Room.byName(room2_name).?.bounds;
    cam.adjust(graphics.View.idByName(view_name).?);
}
