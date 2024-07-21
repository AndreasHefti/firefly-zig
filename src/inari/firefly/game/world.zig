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

    Room.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    Room.deinit();
}

//////////////////////////////////////////////////////////////
//// Area
//////////////////////////////////////////////////////////////

pub const Area = struct {};

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

pub const RoomCallback = *const fn (room: *Room) void;

pub const Room = struct {
    pub usingnamespace api.CompositeTrait(Room);

    name: String,
    area_ref: ?String = null,
    bounds: RectF,

    state: RoomState = RoomState.NONE,
    start_scene_ref: ?String = null,
    end_scene_ref: ?String = null,
    player_ref: ?String = null, // if set, room is active (STARTING,RUNNING,PAUSED,STOPPING) for referenced player

    _composite_ref: Index = undefined,
    _callback: ?RoomCallback = undefined,

    var starting_room_ref: ?String = null;
    var stopping_room_ref: ?String = null;

    pub fn new(room: Room) *Room {
        var result = Room.register(room);
        result.state = .CREATED;
        return result;
    }

    // 2. Load  --> run load tasks --> all needed data is in memory no file load after this. This might also create new activation tasks
    pub fn load(self: *Room) void {
        if (self.state != .CREATED) return;
        defer self.state = .LOADED;

        api.Composite.byId(self._composite_ref).load();
    }

    // 3. Activate  runs activation tasks to create needed components and entities are created from in memory meta  data,
    pub fn activateRoom(self: *Room) void {
        if (self.state != .LOADED) self.load();
        // ignore when room is in unexpected state
        if (self.state != .LOADED) {
            std.debug.print("Room is in unexpected state to run: {any} still active!", .{self});
            return;
        }

        api.Composite.activateById(self._composite_ref, true);
        self.state = .ACTIVATED;
        game.pauseGame();
    }

    pub fn startRoom(
        room_name: String,
        player_ref: String,
        callback: ?RoomCallback,
    ) void {
        if (Room.byName(room_name)) |room|
            room.start(player_ref, callback);
    }

    // 4. Start --> and runs start scene if available
    pub fn start(
        self: *Room,
        player_ref: String,
        callback: ?RoomCallback,
    ) void {
        // if this or another room is already starting, ignore call
        if (starting_room_ref != null) {
            std.debug.print("Another Room is already starting cannot start: {any}", .{self});
            return;
        }

        // activate if room is not already loaded --> but should be loaded before
        if (self.state != .ACTIVATED) self.activateRoom();
        // ignore when room is in unexpected state
        if (self.state != .ACTIVATED) {
            std.debug.print("Room is in unexpected state to run: {any} still active!", .{self});
            return;
        }

        self.player_ref = player_ref;
        self.state = .STARTING;
        starting_room_ref = self.name;
        // TODO init and adjust camera for player
        // game.Player.byName(player_ref).adjustCamera()

        // run start scene if defined. Callback gets invoked when scene finished
        if (self.start_scene_ref) |scene_name| {
            if (graphics.Scene.byName(scene_name)) |scene| {
                self._callback = callback;
                scene.callback = runRoom;
                scene.run();
            }
        } else {
            // just run the Room immediately
            game.resumeGame();
            self.state = .RUNNING;
            starting_room_ref = null;
            if (callback) |c| c(self);
        }
    }

    fn runRoom(_: Index, _: api.ActionResult) void {
        var room = Room.byName(starting_room_ref.?).?;
        room.state = .RUNNING;
        game.resumeGame();
        starting_room_ref = null;
        if (room._callback) |c| c(room);
        room._callback = null;
    }

    // 6. Stop (Scene) --> stops the play and start end scene if available,
    //                    deactivates all registered component refs and run registered deactivation tasks.
    pub fn stopRoom(
        player_ref: String,
        callback: ?RoomCallback,
    ) void {
        if (getActiveRoomForPlayer(player_ref)) |room|
            stop(room, callback);
    }

    pub fn stop(
        self: *Room,
        player_ref: String,
        callback: ?RoomCallback,
    ) void {
        // ignore when room is not running
        if (self.state != .RUNNING or stopping_room_ref != null)
            return;

        self.state = .STOPPING;
        stopping_room_ref = self.name;
        game.pauseGame();

        // if end scene defined run it and wait for callback
        if (self.end_scene_ref) |scene_name| {
            if (graphics.Scene.byName(scene_name)) |scene| {
                self._callback = callback;
                scene.callback = deactivateRoomCallback;
                scene.run();
            }
        } else {
            // just end the Room immediately
            api.Composite.activateById(self._composite_ref, false);
            self.state = .LOADED;
            stopping_room_ref = null;
            self.player_ref = player_ref;
            if (callback) |c| c(self);
            self.player_ref = null;
        }
    }

    // 7. Dispose --> Dispose also meta data and delete the room object
    pub fn dispose(self: *Room) void {
        defer self.state = .CREATED;
        api.Composite.byId(self._composite_ref).dispose();
    }

    fn deactivateRoomCallback(_: Index, _: api.ActionResult) void {
        var room = Room.byName(stopping_room_ref.?).?;
        api.Composite.activateByName(room.name, false);
        room.state = .LOADED;
        stopping_room_ref = null;
        room.player_ref = null;
        if (room._callback) |c| c(room);
        room._callback = null;
    }

    pub fn getActiveRoomForPlayer(player_ref: String) ?*Room {
        var it = Room.referenceIterator();
        while (it.next()) |r| {
            if (r.player_ref) |p|
                if ((r.state == RoomState.RUNNING or r.state == RoomState.STARTING or r.state == RoomState.STOPPING) and
                    utils.stringEquals(p, player_ref)) return r;
        }

        return null;
    }
};

//////////////////////////////////////////////////////////////
//// Room Transition
//////////////////////////////////////////////////////////////

pub const ERoomTransition = struct {
    pub usingnamespace api.EComponent.Trait(ERoomTransition, "ERoomTransition");

    id: Index = UNDEF_INDEX,
    condition: ?api.ConditionFunction = null,
    target_room: String,
    target_transition: String,
    orientation: utils.Orientation,
};

fn createRoomTransition(context: api.TaskContext) void {
    // create the room transition entity
    const condition_name = context.get(game.TaskAttributes.ROOM_TRANSITION_CONDITION).?;
    const transition_name = context.get(game.TaskAttributes.ROOM_TRANSITION_NAME).?;
    const target_room_name = context.get(game.TaskAttributes.ROOM_TRANSITION_TARGET_ROOM).?;
    const target_transition_name = context.get(game.TaskAttributes.ROOM_TRANSITION_TARGET_TRANSITION).?;
    const orientation_name = context.get(game.TaskAttributes.ROOM_TRANSITION_ORIENTATION).?;
    const bounds = utils.parseRectF(context.get(game.TaskAttributes.ROOM_TRANSITION_BOUNDS).?);
    const view_id = graphics.View.idByName(context.get(game.TaskAttributes.VIEW_NAME).?);
    const layer_id = graphics.Layer.idByName(context.get(game.TaskAttributes.LAYER_NAME).?);

    _ = api.Entity.new(.{ .name = transition_name })
        .withComponent(graphics.ETransform{ .position = .{ bounds[0], bounds[1] } })
        .withComponent(graphics.EView{ .view_id = view_id, .layer_id = layer_id })
        .withComponent(physics.EContact{
        .bounds = .{ .rect = bounds },
        .type = game.ContactTypes.ROOM_TRANSITION,
    })
        .withComponent(ERoomTransition{
        .condition = api.Condition.functionByName(condition_name),
        .target_room = target_room_name,
        .target_transition = target_transition_name,
        .orientation = utils.Orientation.byName(orientation_name),
    })
        .activate();
}

// ContactCallback used to apply to player to get called on players transition contact constraint
fn applyRoomTransition(player_id: Index, contact: *physics.ContactScan) void {
    // check transition condition
    if (contact.mask.?.count() <= 8) return;

    const c = contact.firstContactOfType(game.ContactTypes.ROOM_TRANSITION) orelse return;
    const transition_id = c.entity_id;
    const player = api.Entity.byId(player_id);
    const move = physics.EMovement.byId(player_id) orelse return;
    const transition = ERoomTransition.byId(transition_id) orelse return;

    switch (transition.orientation) {
        .EAST => if (move.velocity[0] <= 0) return,
        .WEST => if (move.velocity[0] >= 0) return,
        .NORTH => if (move.velocity[1] >= 0) return,
        .SOUTH => if (move.velocity[1] <= 0) return,
        else => return,
    }

    // stop current room with callback
    // Stack Index: player_id, transition_id
    game.GlobalStack.putIndex(player_id);
    game.GlobalStack.putIndex(transition_id);
    // Stack Name: target_room, target_transition,player_name
    game.GlobalStack.putName(transition.target_room);
    game.GlobalStack.putName(transition.target_transition);
    game.GlobalStack.putName(player.name);

    game.Room.stopRoom(player.name, stoppedRoomCallback);
}

fn stoppedRoomCallback(_: *Room) void {
    // Stack Index: transition_id player_id
    const source_transition_id = game.GlobalStack.popIndex();
    const player_id = game.GlobalStack.popIndex();
    // Stack Name: target_transition, target_room
    const target_transition = game.GlobalStack.popName();
    const target_room_name = game.GlobalStack.popName();
    const player_name = game.GlobalStack.popName();

    // activate new room also load room if not loaded
    const target_room = Room.byName(target_room_name) orelse return;
    target_room.activateRoom();

    // set player position adjust cam
    const player_transform = graphics.ETransform.byId(player_id) orelse return;
    const source_transition = ERoomTransition.byId(source_transition_id) orelse return;
    const source_transition_transform = graphics.ETransform.byId(source_transition_id) orelse return;
    const target_transition_transform = graphics.ETransform.byName(target_transition) orelse return;

    // playerToTransition(player.playerPosition) - sourceTransform.position
    // playerTargetPos(targetTransform.position) + playerToTransition
    // player.playerPosition(playerTargetPos )

    const player_to_transition: utils.PosF = player_transform.position - source_transition_transform.position;
    const player_target_pos = target_transition_transform.position + player_to_transition;
    player_transform.position = player_target_pos;

    switch (source_transition.orientation) {
        .EAST => player_transform.position[0] += 5,
        .WEST => player_transform.position[0] -= 5,
        .NORTH => player_transform.position[1] -= 5,
        .SOUTH => player_transform.position[1] += 5,
        else => {},
    }

    target_room.start(player_name, null);
}
