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
            .snap_to_bounds = .{ 0, 0, 0, 0 },
            .velocity_relative_to_pivot = .{ 0.5, 0.5 },
            .enable_parallax = true,
        },
        true,
    );
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_A, api.InputButtonType.LEFT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_D, api.InputButtonType.RIGHT);
    firefly.api.input.setKeyMapping(api.KeyboardKey.KEY_SPACE, api.InputButtonType.FIRE_1);

    // crate start scene
    _ = graphics.Scene.new(.{
        .name = start_scene_name,
        .update_action = startSceneAction,
        .scheduler = api.Timer.getScheduler(20),
    });

    // load room from file
    api.Task.runTaskByNameWith(
        game.JSONTasks.LOAD_ROOM,
        null,
        .{
            .{ game.TaskAttributes.FILE_RESOURCE, "resources/example_room2.json" },
            .{ game.TaskAttributes.ATTR_VIEW_NAME, view_name },
        },
    );

    // add player and init cam for room
    _ = game.Room.byName(room2_name).?.withActivationTask(
        api.Task{
            .name = "CreatePlayer",
            .run_once = true,
            .function = createPlayer,
        },
        null,
    );

    // and just start the Room
    game.Room.startRoomWithPlayer(room2_name, player_name, roomLoaded);
}

fn roomLoaded(_: ?*game.Room) void {
    std.debug.print("Room running!!!\n", .{});
}

var player_pos_ptr: *utils.PosF = undefined;
fn createPlayer(_: api.TaskContext) void {
    const sprite_id = graphics.SpriteTemplate.new(.{
        .texture_name = texture_name,
        .texture_bounds = utils.RectF{ 7 * 16, 1 * 16, 16, 16 },
    }).id;

    // create player entity
    _ = api.Entity.new(.{
        .name = player_name,
    })
        .withGroupAspect(game.BaseGroupAspect.PAUSEABLE)
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
        .jump_impulse = 100,
        .double_jump = true,
    })
        .activate();

    // apply player position as pivot for camera
    var cam = game.SimplePivotCamera.byName(cam_name).?;
    player_pos_ptr = &graphics.ETransform.byName(player_name).?.position;
    cam.pivot = player_pos_ptr;
    cam.snap_to_bounds = game.Room.byName(room2_name).?.bounds;
    cam.adjust(graphics.View.idByName(view_name).?);
}

// rudimentary implementation of an action control for the start scene
// just creates a rectangle shape entity that overlaps the while screen
// with initial black color, fading alpha to 0 with ALPHA blend of the background
// Room view will appear from black screen. When alpha is 0, action successfully  ends
// and pivot control is been activated.
var scene_init = false;
var color: *utils.Color = undefined;
fn startSceneAction(_: Index) api.ActionResult {
    if (!scene_init) {
        // create overlay entity
        const entity = api.Entity.new(.{ .name = "StartSceneEntity" })
            .withComponent(graphics.ETransform{
            .scale = .{ screen_width, screen_height },
        })
            .withComponent(graphics.EView{
            .view_id = graphics.View.idByName(view_name).?,
            .layer_id = graphics.Layer.idByName(layer2).?,
        })
            .withComponent(graphics.EShape{
            .blend_mode = api.BlendMode.ALPHA,
            .color = .{ 0, 0, 0, 255 },
            .shape_type = api.ShapeType.RECTANGLE,
            .fill = true,
            .vertices = api.allocFloatArray([_]utils.Float{ 0, 0, 1, 1 }),
        }).activate();
        color = &graphics.EShape.byId(entity.id).?.color;
        scene_init = true;
    }

    color[3] -= @min(5, color[3]);

    if (color[3] <= 0) {
        api.Entity.disposeByName("StartSceneEntity");
        api.ComponentControl.activateByName("KeyControl", true);
        scene_init = false;
        return api.ActionResult.Success;
    }

    return api.ActionResult.Running;
}
fn endSceneAction(_: Index) api.ActionResult {
    if (!scene_init) {
        // create overlay entity
        const entity = api.Entity.new(.{ .name = "StartSceneEntity" })
            .withComponent(graphics.ETransform{
            .scale = .{ screen_width, screen_height },
        })
            .withComponent(graphics.EView{
            .view_id = graphics.View.idByName(view_name).?,
            .layer_id = graphics.Layer.idByName(layer2).?,
        })
            .withComponent(graphics.EShape{
            .blend_mode = api.BlendMode.ALPHA,
            .color = .{ 0, 0, 0, 255 },
            .shape_type = api.ShapeType.RECTANGLE,
            .fill = true,
            .vertices = api.allocFloatArray([_]utils.Float{ 0, 0, 1, 1 }),
        }).activate();
        color = &graphics.EShape.byId(entity.id).?.color;
        scene_init = true;
    }

    color[3] -= @min(5, color[3]);

    if (color[3] <= 0) {
        api.Entity.disposeByName("StartSceneEntity");
        api.ComponentControl.activateByName("KeyControl", true);
        scene_init = false;
        return api.ActionResult.Success;
    }

    return api.ActionResult.Running;
}
