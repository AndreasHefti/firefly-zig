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

    // needed systems that are not active by default
    firefly.physics.ContactSystem.System.activate();
    firefly.physics.ContactGizmosRenderer.System.activate();
    firefly.physics.ContactScanGizmosRenderer.System.activate();
    // we need to initialize the JSON integration tasks fist
    firefly.game.initJSONIntegration();

    // create view with two layer
    _ = graphics.View.Component.new(.{
        .name = view_name,
        .position = .{ 0, 0 },
        .scale = .{ scale, scale },
        .projection = .{
            .width = screen_width,
            .height = screen_height,
            .zoom = zoom,
        },
    });

    // create the world from json file
    api.Task.runTaskByNameWith(
        game.Tasks.JSON_LOAD_WORLD,
        .{
            .attributes_id = api.Attributes.newWith(
                null,
                .{
                    .{ game.TaskAttributes.JSON_RESOURCE_WORLD_FILE, "resources/example_world.json" },
                    .{ game.TaskAttributes.VIEW_NAME, view_name },
                },
            ).id,
        },
    );

    // load the created world (will create all thr rooms of the world from json files)
    game.World.loadByName("World1");

    //create player with load task (active room will load and activate the player when started)
    const player_id = game.Player.Component.new(.{ .name = player_name });
    game.Player.Composite.addTask(
        player_id,
        api.Task{
            .run_once = true,
            .function = playerLoadTask,
        },
        api.CompositeLifeCycle.LOAD,
        null,
    );

    // and just start the Room with the player
    game.Room.startRoom(room1_name, player_name, roomLoaded);
}

fn roomLoaded(room_id: Index) void {
    std.debug.print(
        "Room running!!! test_attribute1={?s} \n",
        .{game.Room.Composite.Attributes.getAttribute(room_id, "test_attribute1")},
    );
}

fn playerLoadTask(_: *api.CallContext) void {
    const view = graphics.View.Naming.byName(view_name) orelse return;
    var player = game.Player.Component.byName(player_name) orelse return;
    player._view_id = view.id;

    // single sprite for this player
    const sprite_id = graphics.SpriteTemplate.Component.new(.{
        .texture_name = texture_name,
        .texture_bounds = utils.RectF{ 7 * 16, 1 * 16, 16, 16 },
    });

    // init key control for the player
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_A, api.InputButtonType.LEFT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_D, api.InputButtonType.RIGHT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_SPACE, api.InputButtonType.FIRE_1);

    // create player entity with normal gravity movement, controller and collision scans
    player._entity_id = api.Entity.new(.{
        .name = player_name,
        .groups = api.GroupAspectGroup.newKindOf(.{game.Groups.PAUSEABLE}),
    }, .{
        graphics.ETransform{ .position = .{ 32, 32 }, .pivot = .{ 0, 0 } },
        graphics.EView{ .view_id = graphics.View.Naming.getId(view_name), .layer_id = graphics.Layer.Naming.getId(layer2) },
        graphics.ESprite{ .template_id = sprite_id },
        physics.EMovement{ .mass = 50, .max_velocity_south = 180, .max_velocity_east = 50, .max_velocity_west = 50, .integrator = physics.EulerIntegrator },
        physics.EContactScan{
            .collision_resolver = game.PlatformerCollisionResolver.new(
                .{
                    .contact_bounds = .{ 4, 1, 8, 14 },
                    .view_id = graphics.View.Naming.getId(view_name),
                    .layer_id = graphics.Layer.Naming.getId(layer2),
                },
            ),
        },
        physics.ContactConstraint{
            .name = "Room_Transition",
            .layer_id = graphics.Layer.Naming.getId(layer2),
            .bounds = .{ .rect = .{ 6, 6, 4, 4 } },
            .type_filter = physics.ContactTypeKind.of(.{game.ContactTypes.ROOM_TRANSITION}),
            .full_scan = true,
            .callback = game.TransitionContactCallback,
        },
        game.SimplePlatformerHorizontalMoveControl{ .button_left = api.InputButtonType.LEFT, .button_right = api.InputButtonType.RIGHT },
        game.SimplePlatformerJumpControl{ .jump_button = api.InputButtonType.FIRE_1, .jump_impulse = 140, .double_jump = true },
    });

    player._move = physics.EMovement.Component.byId(player._entity_id);
    player._transform = graphics.ETransform.Component.byId(player._entity_id);

    // create camera control
    graphics.View.Control.addOf(
        view.id,
        game.SimplePivotCamera{
            .name = cam_name,
            .pivot = &player._transform.position,
            .pixel_perfect = false,
            .snap_to_bounds = .{ 0, 0, 0, 0 },
            .velocity_relative_to_pivot = .{ 0.5, 0.5 },
            .enable_parallax = true,
        },
        true,
    );

    player._cam_id = game.SimplePivotCamera.Component.idByName(cam_name).?;
    firefly.Engine.printState();
}
