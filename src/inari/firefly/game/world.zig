const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const physics = firefly.physics;
const game = firefly.game;

const PosF = utils.PosF;
const Index = utils.Index;
const String = utils.String;
const Float = utils.Float;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const RectF = utils.RectF;
const CInt = utils.CInt;
const BindingId = api.BindingId;
const UNDEF_INDEX = utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// game world init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.Component.Subtype.register(api.Composite, World, "World");
    api.Component.Subtype.register(api.Composite, Room, "Room");
    api.Component.Subtype.register(api.Composite, Player, "Player");

    api.Entity.registerComponent(ERoomTransition, "ERoomTransition");

    _ = api.Task.Component.new(.{
        .name = game.Tasks.ROOM_TRANSITION_BUILDER,
        .function = createRoomTransition,
    });
    _ = api.Task.Component.new(.{
        .name = game.Tasks.SIMPLE_ROOM_TRANSITION_SCENE_BUILDER,
        .function = SimpleRoomTransitionScene.buildSimpleRoomTransitionScene,
    });
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    api.Task.Naming.dispose(game.Tasks.ROOM_TRANSITION_BUILDER);
}

//////////////////////////////////////////////////////////////
//// Player data and composite
//////////////////////////////////////////////////////////////

pub const Player = struct {
    pub const Component = api.Component.SubTypeMixin(api.Composite, Player);
    pub const Composite = api.CompositeMixin(Player);

    id: Index = UNDEF_INDEX,
    name: String,

    _loaded: bool = false,
    _entity_id: Index = UNDEF_INDEX,
    _transform: *graphics.ETransform = undefined,
    _move: *physics.EMovement = undefined,
    _cam_id: Index = UNDEF_INDEX,
    _view_id: Index = UNDEF_INDEX,

    pub fn load(self: *Player) void {
        defer self._loaded = true;
        if (self._loaded)
            return;

        api.Composite.Component.byId(self.id).load();
        var cam = game.SimplePivotCamera.Component.byId(self._cam_id);
        cam.pivot = &self._transform.position;
        api.Entity.Activation.activate(self._entity_id);
        game.pauseGame();
    }
};

//////////////////////////////////////////////////////////////
//// World
//////////////////////////////////////////////////////////////

pub const World = struct {
    pub const Component = api.Component.SubTypeMixin(api.Composite, World);
    pub const Composite = api.CompositeMixin(World);

    id: Index = UNDEF_INDEX,
    name: String,

    pub fn load(self: *World) void {
        api.Composite.byId(self.id).load();
    }

    pub fn loadByName(name: String) void {
        if (api.Composite.Naming.byName(name)) |c| c.load();
    }
};

//////////////////////////////////////////////////////////////
//// Room
//////////////////////////////////////////////////////////////

// TODO define life-cycle of a Room, When should be done what
// 1. Build --> populate the room with needed attributes and load/activation tasks
// 2. Load  --> run load tasks --> all needed data is in memory no file load after this. This might also create new activation tasks
// 3  Activate --> uns activation tasks to create needed components and entities are created from in memory meta data,
// 4. Start --> runs start scene if there is one
// 5. Running/Pause/Resume --> pauses or resumes the play
// 6. End (Scene) --> stops the play and start end scene if available,
//                    deactivates all registered component refs and run registered deactivation tasks.
// 7. Dispose --> Dispose also meta data and delete the room object

pub const RoomState = enum {
    NONE,
    CREATED,
    LOADED,
    ACTIVATED,
    STARTING,
    RUNNING,
    STOPPING,
};

pub const RoomCallback = *const fn (room_id: Index) void;

pub const Room = struct {
    pub const Component = api.Component.SubTypeMixin(api.Composite, Room);
    pub const Composite = api.CompositeMixin(Room);

    id: Index = UNDEF_INDEX,
    name: String,
    area_ref: ?String = null,
    bounds: RectF,

    state: RoomState = RoomState.NONE,
    start_scene_ref: ?String = null,
    end_scene_ref: ?String = null,
    player_ref: ?String = null, // if set, room is active (STARTING,RUNNING,PAUSED,STOPPING) for referenced player

    _run_callback: ?RoomCallback = undefined,
    _stop_callback: ?RoomCallback = undefined,
    _unload_callback: ?RoomCallback = undefined,

    pub fn construct(self: *Room) void {
        std.debug.print("FIREFLY : INFO: Room {s} created\n", .{self.name});
        self.state = .CREATED;
    }

    pub fn destruct(self: *Room) void {
        std.debug.print("FIREFLY : INFO: Room {s} destructed\n", .{self.name});
        self.state = .NONE;
    }

    // 2. Load  --> run load tasks --> all needed data is in memory no file load after this. This might also create new activation tasks
    pub fn load(self: *Room) void {
        if (self.state != .CREATED) return;
        defer self.state = .LOADED;

        api.Composite.Component.byId(self.id).load();
    }

    // 3. Activate  runs activation tasks to create needed components and entities are created from in memory meta  data,
    pub fn activateRoom(self: *Room) void {
        if (self.state != .LOADED) self.load();
        // ignore when room is in unexpected state
        if (self.state != .LOADED) {
            std.debug.print("FIREFLY : ERROR: Room is in unexpected state to run: {any} still active!", .{self});
            return;
        }

        api.Composite.Activation.activate(self.id);
        self.state = .ACTIVATED;
        game.pauseGame();
    }

    pub fn startRoom(
        room_name: String,
        player_ref: String,
        callback: ?RoomCallback,
    ) void {
        if (Room.Component.byName(room_name)) |room|
            room.start(player_ref, callback);
    }

    // 4. Start --> and runs start scene if available
    pub fn start(
        self: *Room,
        player_ref: String,
        callback: ?RoomCallback,
    ) void {
        // if this room is already starting, ignore call
        if (self.state == .STARTING or self.state == .RUNNING) {
            std.debug.print("FIREFLY : ERROR: Another Room is already starting cannot start: {any}", .{self});
            return;
        }

        // activate if room is not already loaded --> but should be loaded before
        if (self.state != .ACTIVATED)
            self.activateRoom();

        // ignore when room is in unexpected state
        if (self.state != .ACTIVATED) {
            std.debug.print("FIREFLY : ERROR: Room is in unexpected state to run: {any} still active!", .{self});
            return;
        }

        self.player_ref = player_ref;
        self.state = .STARTING;

        // load player if needed and init camera
        const player = game.Player.Component.byName(player_ref);
        if (player) |p| {
            p.load();
            var cam = game.SimplePivotCamera.Component.byId(p._cam_id);
            cam.snap_to_bounds = self.bounds;
            cam.adjust(p._view_id);
        }

        // run start scene if defined. Callback gets invoked when scene finished
        if (self.start_scene_ref) |scene_name| {
            if (graphics.Scene.Naming.byName(scene_name)) |scene| {
                self._run_callback = callback;
                scene.call_context.caller_id = self.id;
                scene.callback = runRoom;
                scene.run();
            } else utils.panic(api.ALLOC, "Start scene with name {s} not found", .{scene_name});
        } else {
            // just run the Room immediately
            game.resumeGame();
            self.state = .RUNNING;
            if (callback) |c| c(self.id);
        }
    }

    fn runRoom(ctx: *api.CallContext) void {
        var room = Room.Component.byId(ctx.caller_id);
        defer room._run_callback = null;

        room.state = .RUNNING;
        game.resumeGame();
        if (room._run_callback) |c|
            c(room.id);
    }

    // 6. Stop (Scene) --> stops the play and start end scene if available,
    //                    deactivates all registered component refs and run registered deactivation tasks.
    pub fn stopRoom(player_ref: String, callback: ?RoomCallback) void {
        if (getActiveRoomForPlayer(player_ref)) |room|
            stop(room, callback);
    }

    pub fn stop(self: *Room, callback: ?RoomCallback) void {
        // ignore when room is not running or already stopping
        if (self.state != .RUNNING or self.state == .STOPPING)
            return;

        self.state = .STOPPING;
        game.pauseGame();

        // if end scene defined run it and wait for callback
        if (self.end_scene_ref) |scene_name| {
            if (graphics.Scene.Naming.byName(scene_name)) |scene| {
                self._stop_callback = callback;
                scene.call_context.caller_id = self.id;
                scene.callback = stopRoomCallback;
                scene.run();
            } else utils.panic(api.ALLOC, "End scene with name {s} not found", .{scene_name});
        } else {
            // just end the Room immediately
            api.Composite.Activation.deactivate(self.id);
            self.state = .LOADED;
            if (callback) |c|
                c(self.id);
            self.player_ref = null;
        }
    }

    pub fn unloadRoom(player_ref: String, callback: ?RoomCallback) void {
        if (getActiveRoomForPlayer(player_ref)) |room|
            unload(room, callback);
    }

    // 7. Dispose --> Dispose also meta data and delete the room object
    pub fn unload(self: *Room, callback: ?RoomCallback) void {
        defer self.state = .CREATED;

        if (self.state == .RUNNING) {
            self._unload_callback = callback;
            self.stop(unloadRoomCallback);
        } else {
            self.state = .CREATED;

            if (callback) |c|
                c(self.id);
        }
    }

    fn unloadRoomCallback(room_id: Index) void {
        var room = Room.Component.byId(room_id);
        defer room._unload_callback = null;

        if (api.Composite.Naming.byName(room.name)) |composite|
            composite.unload();

        room.state = .CREATED;

        if (room._unload_callback) |c|
            c(room.id);
    }

    fn stopRoomCallback(ctx: *api.CallContext) void {
        var room = Room.Component.byId(ctx.caller_id);
        defer room._stop_callback = null;

        api.Composite.Activation.deactivateByName(room.name);
        room.state = .LOADED;
        room.player_ref = null;
        if (room._stop_callback) |c| c(room.id);
    }

    pub fn getActiveRoomForPlayer(player_ref: String) ?*Room {
        var it = Room.Component.idIterator();
        while (it.next()) |r_id| {
            const room = Room.Component.byId(r_id.*);
            if (room.player_ref) |p|
                if ((room.state == RoomState.RUNNING or room.state == RoomState.STARTING or room.state == RoomState.STOPPING) and
                    utils.stringEquals(p, player_ref)) return room;
        }

        return null;
    }
};

//////////////////////////////////////////////////////////////
//// Room Transition
//////////////////////////////////////////////////////////////

pub const ERoomTransition = struct {
    pub const Component = api.EntityComponentMixin(ERoomTransition);

    id: Index = UNDEF_INDEX,
    condition: ?api.CallPredicate = null,
    target_room: String,
    target_transition: String,
    orientation: utils.Orientation,
};

fn createRoomTransition(ctx: *api.CallContext) void {
    // create the room transition entity
    const name = ctx.string(game.TaskAttributes.NAME);
    const view_id = graphics.View.Naming.getId(ctx.attribute(game.TaskAttributes.VIEW_NAME));
    const layer_id = graphics.Layer.Naming.getId(ctx.attribute(game.TaskAttributes.LAYER_NAME));
    const bounds = ctx.rectF(game.TaskAttributes.BOUNDS);

    var properties = ctx.properties(game.TaskAttributes.PROPERTIES);
    const target_room_name = properties.nextName().?;
    const target_transition_name = properties.nextName().?;
    const orientation = properties.nextOrientation().?;

    const condition_name = switch (orientation) {
        .EAST => game.Conditions.GOES_EAST,
        .WEST => game.Conditions.GOES_WEST,
        .NORTH => game.Conditions.GOES_NORTH,
        .SOUTH => game.Conditions.GOES_SOUTH,
        else => "NONE",
    };

    const trans_entity_id = api.Entity.build(.{ .name = name })
        .withComponent(graphics.ETransform{ .position = .{ bounds[0], bounds[1] } })
        .withComponent(graphics.EView{ .view_id = view_id, .layer_id = layer_id })
        .withComponent(physics.EContact{
        .bounds = .{ .rect = .{ 0, 0, bounds[2], bounds[3] } },
        .type = game.ContactTypes.ROOM_TRANSITION,
    })
        .withComponent(ERoomTransition{
        .condition = api.Condition.functionByName(condition_name),
        .target_room = target_room_name,
        .target_transition = target_transition_name,
        .orientation = orientation,
    })
        .activateGetId();

    // add transition entity as owned reference if requested
    if (ctx.c_ref_callback) |callback|
        callback(api.Entity.Component.getReference(trans_entity_id, true).?, ctx);
}

const TransitionState = struct {
    var player_id: ?Index = null;
    var player_offset: ?utils.PosF = null;
    var orientation: ?utils.Orientation = null;
    var target_room: ?String = null;
    var target_transition: ?String = null;
};

// ContactCallback used to apply to player to get called on players transition contact constraint
pub fn TransitionContactCallback(player_id: Index, contact: *physics.ContactScan) bool {
    // check transition condition
    if (contact.mask.?.count() < 4) return false;

    const c = contact.firstContactOfType(game.ContactTypes.ROOM_TRANSITION) orelse return false;
    const transition_id = c.entity_id;
    const player = api.Entity.Component.byId(player_id);
    const player_transform = graphics.ETransform.Component.byId(player_id);
    const move = physics.EMovement.Component.byId(player_id);
    const transition = ERoomTransition.Component.byId(transition_id);
    const transition_transform = graphics.ETransform.Component.byId(transition_id);

    switch (transition.orientation) {
        .EAST => if (move.velocity[0] <= 0) return false,
        .WEST => if (move.velocity[0] >= 0) return false,
        .NORTH => if (move.velocity[1] >= 0) return false,
        .SOUTH => if (move.velocity[1] <= 0) return false,
        else => return false,
    }

    // set current transition state
    TransitionState.player_id = player_id;
    TransitionState.player_offset = player_transform.position - transition_transform.position;
    TransitionState.orientation = transition.orientation;
    TransitionState.target_room = transition.target_room;
    TransitionState.target_transition = transition.target_transition;

    // unload current room with callback
    game.Room.unloadRoom(player.name.?, roomUnloadedCallback);
    return true;
}

fn roomUnloadedCallback(_: Index) void {
    const player_id = TransitionState.player_id.?;
    const orientation = TransitionState.orientation.?;
    const target_room_name = TransitionState.target_room.?;
    const target_transition = TransitionState.target_transition.?;

    // activate new room also load room if not loaded
    if (Room.Component.byName(target_room_name)) |target_room| {
        target_room.activateRoom();

        // set player position adjust cam
        const player = api.Entity.Component.byId(player_id);
        const player_transform = graphics.ETransform.Component.byId(player_id);
        const player_movement = physics.EMovement.Component.byId(player_id);
        const target_transition_transform = graphics.ETransform.Component.byName(target_transition).?;

        player_movement.on_ground = false;
        player_transform.moveTo(
            target_transition_transform.position[0] + TransitionState.player_offset.?[0],
            target_transition_transform.position[1] + TransitionState.player_offset.?[1],
        );

        switch (orientation) {
            .EAST => player_transform.position[0] += 5,
            .WEST => player_transform.position[0] -= 5,
            .NORTH => player_transform.position[1] -= 5,
            .SOUTH => player_transform.position[1] += 5,
            else => {},
        }

        // start new room
        target_room.start(player.name.?, null);
    } else {
        utils.panic(api.ALLOC, "No Room with name: {s} found", .{target_room_name});
    }
}

//////////////////////////////////////////////////////////////
//// Simple Room Transition Scene
//////////////////////////////////////////////////////////////
// rudimentary implementation of an action control for the start and end scene
// just creates a rectangle shape entity that overlays the whole screen
// with initial black color, fading alpha to 0 with ALPHA blend of the background

pub const SimpleRoomTransitionScene = struct {
    fn buildSimpleRoomTransitionScene(ctx: *api.CallContext) void {
        const name = ctx.string(game.TaskAttributes.NAME);
        const entry = !ctx.boolean("exit");

        const scene_id = graphics.Scene.Component.new(.{
            .name = name,
            .init_function = entityInit,
            .dispose_function = disposeEntity,
            .update_action = if (entry) entryAction else exitAction,
        });

        graphics.Scene.CallContext.Attributes.setAllAttributesById(scene_id, ctx.attributes_id);
    }

    fn entityInit(ctx: *api.CallContext) void {
        // create new overlay entity
        const name = ctx.string(game.TaskAttributes.NAME);
        const view_name = ctx.string(game.TaskAttributes.VIEW_NAME);
        const layer_name = ctx.string(game.TaskAttributes.LAYER_NAME);
        const entry = !ctx.boolean("exit");

        if (graphics.View.Naming.byName(view_name)) |view| {
            ctx.id_1 = api.Entity.build(.{ .name = name })
                .withComponent(graphics.ETransform{
                .scale = .{ view.projection.width, view.projection.height },
            })
                .withComponent(graphics.EView{
                .view_id = graphics.View.Naming.getId(view_name),
                .layer_id = graphics.Layer.Naming.getId(layer_name),
            })
                .withComponent(graphics.EShape{
                .blend_mode = api.BlendMode.ALPHA,
                .color = .{ 0, 0, 0, if (entry) 255 else 0 },
                .shape_type = api.ShapeType.RECTANGLE,
                .fill = true,
                .vertices = api.allocFloatArray([_]utils.Float{ 0, 0, 1, 1 }),
            }).activateGetId();
        }
    }

    fn disposeEntity(ctx: *api.CallContext) void {
        const name = ctx.attribute(game.TaskAttributes.NAME);
        api.Entity.Naming.dispose(name);
        ctx.id_1 = UNDEF_INDEX;
    }

    fn entryAction(ctx: *api.CallContext) void {
        const shape = graphics.EShape.Component.byId(ctx.id_1);
        shape.color[3] -= @min(20, shape.color[3]);
        if (shape.color[3] <= 0)
            ctx.result = .Success
        else
            ctx.result = .Running;
    }

    fn exitAction(ctx: *api.CallContext) void {
        const shape = graphics.EShape.Component.byId(ctx.id_1);
        shape.color[3] = @min(255, @as(usize, @intCast(shape.color[3])) + 20);
        if (shape.color[3] >= 255)
            ctx.result = .Success
        else
            ctx.result = .Running;
    }
};
