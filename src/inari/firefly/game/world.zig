const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
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
// 3. Start --> ends active room when available,
//              runs activation tasks to create needed components and entities are created from in memory meta data,
//              and runs start scene if available
// 5. Running/Pause/Resume --> pauses or resumes the play
// 6. End (Scene) --> stops the play and start end scene if available,
//                    deactivates all registered component refs and run registered deactivation tasks.
// 8. Dispose --> Dispose also meta data and delete the room object

pub const RoomState = enum {
    NONE,
    CREATED,
    LOADED,
    STARTING,
    RUNNING,
    PAUSED,
    STOPPING,
};

pub const Room = struct {
    name: String,
    area_ref: ?String = null,
    bounds: RectF,

    state: RoomState = RoomState.NONE,
    start_scene_ref: ?String = null,
    end_scene_ref: ?String = null,
    composite_ref: Index = undefined,
    player_ref: ?String = null, // if set, room is active (STARTING,RUNNING,PAUSED,STOPPING) for referenced player

    _callback: ?*const fn (room: ?*Room) void = undefined,

    var starting_room_ref: ?String = null;
    var stopping_room_ref: ?String = null;

    var rooms: std.StringHashMap(Room) = undefined;

    fn init() void {
        rooms = std.StringHashMap(Room).init(api.COMPONENT_ALLOC);
    }

    fn deinit() void {
        var it = rooms.iterator();
        while (it.next()) |r|
            r.value_ptr.deconstruct();

        rooms.deinit();
        rooms = undefined;
    }

    pub fn new(room: Room) *Room {
        var result = rooms.getOrPut(room.name) catch unreachable;
        if (result.found_existing)
            utils.panic(api.ALLOC, "Room with name already exists: {any}", .{room.name});

        result.value_ptr.* = room;
        result.value_ptr.composite_ref = api.Composite.new(.{ .name = room.name }).id;
        result.value_ptr.state = RoomState.CREATED;
        return result.value_ptr;
    }

    pub fn withLoadTaskByName(self: *Room, task_name: String, attributes: anytype) *Room {
        Room.addTaskByName(
            self.name,
            task_name,
            api.CompositeLifeCycle.LOAD,
            attributes,
        );

        return self;
    }

    pub fn withLoadTaskById(self: *Room, task_Id: Index, attributes: anytype) *Room {
        Room.addTaskById(
            self.name,
            task_Id,
            api.CompositeLifeCycle.LOAD,
            attributes,
        );

        return self;
    }

    pub fn withActivationTask(self: *Room, task: api.Task, attributes: anytype) *Room {
        return withActivationTaskById(self, api.Task.new(task).id, attributes);
    }

    pub fn withActivationTaskByName(self: *Room, task_name: String, attributes: anytype) *Room {
        Room.addTaskByName(
            self.name,
            task_name,
            api.CompositeLifeCycle.ACTIVATE,
            attributes,
        );

        return self;
    }

    pub fn withActivationTaskById(self: *Room, task_Id: Index, attributes: anytype) *Room {
        Room.addTaskById(
            self.name,
            task_Id,
            api.CompositeLifeCycle.ACTIVATE,
            attributes,
        );

        return self;
    }

    pub fn deconstruct(self: *Room) void {
        dispose(self);

        api.Composite.disposeById(self.composite_ref);
        _ = rooms.remove(self.name);
    }

    pub fn byName(name: String) ?*Room {
        return rooms.getPtr(name);
    }

    // 2. Load  --> run load tasks --> all needed data is in memory no file load after this. This might also create new activation tasks
    pub fn load(self: *Room) void {
        if (self.state != RoomState.CREATED) return;
        defer self.state = RoomState.LOADED;

        api.Composite.byId(self.composite_ref).load();
    }

    pub fn dispose(self: *Room) void {
        defer self.state = RoomState.CREATED;
        if (self.state == RoomState.PAUSED or self.state == RoomState.RUNNING) {
            endRoomWithPlayer(self.player_ref.?, disposeRoomCallback);
        } else {
            api.Composite.byId(self.composite_ref).dispose();
        }
    }

    fn disposeRoomCallback(self: ?*Room) void {
        if (self) |r| api.Composite.byId(r.composite_ref).dispose();
    }

    pub fn startRoomWithPlayer(room_name: String, player_ref: String, callback: ?*const fn (room: ?*Room) void) void {
        if (byName(room_name)) |room| {
            room.start(player_ref, callback);
        } else {
            if (callback) |c| c(null);
        }
    }

    // 3. Start --> end active room when available,
    //              runs activation tasks to create needed components and entities are created from in memory meta  data,
    //              and runs start scene if available
    pub fn start(self: *Room, player_ref: String, callback: ?*const fn (room: ?*Room) void) void {
        // if this or another room is already starting, ignore call
        if (starting_room_ref != null) {
            if (callback) |c| c(null);
            return;
        }

        // load if room is not already loaded --> but should be loaded before
        if (self.state == RoomState.CREATED) self.load();
        // ignore when room is in unexpected state
        if (self.state != RoomState.LOADED) {
            std.debug.print("Room is in unexpected state to run: {any} still active!", .{self});
            if (callback) |c| c(null);
            return;
        }

        self.player_ref = player_ref;
        self.state = RoomState.STARTING;
        starting_room_ref = self.name;
        api.Composite.activateById(self.composite_ref, true);
        game.pauseGame();

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
            self.state = RoomState.RUNNING;
            starting_room_ref = null;
            if (callback) |c| c(self);
        }
    }

    fn runRoom(_: Index, _: api.ActionResult) void {
        var room = Room.byName(starting_room_ref.?).?;
        room.state = RoomState.RUNNING;
        game.resumeGame();
        starting_room_ref = null;
        if (room._callback) |c| c(room);
        room._callback = null;
    }

    // 6. End (Scene) --> stops the play and start end scene if available,
    //                    deactivates all registered component refs and run registered deactivation tasks.
    pub fn endRoomWithPlayer(player_ref: String, callback: ?*const fn (room: ?*Room) void) void {
        if (getActiveRoomForPlayer(player_ref)) |room| {
            end(room, callback);
        } else {
            // ignore call when there is no active room
            if (callback) |c| c(null);
        }
    }

    pub fn end(self: *Room, callback: ?*const fn (room: ?*Room) void) void {
        // ignore when room is not running
        if (self.state != RoomState.RUNNING or stopping_room_ref != null) {
            if (callback) |c| c(null);
            return;
        }

        self.state = RoomState.STOPPING;
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
            api.Composite.activateById(self.composite_ref, false);
            self.state = RoomState.LOADED;
            stopping_room_ref = null;
            self.player_ref = null;
            if (callback) |c| c(self);
        }
    }

    fn deactivateRoomCallback(_: Index, _: api.ActionResult) void {
        var room = Room.byName(stopping_room_ref.?).?;
        api.Composite.activateByName(room.name, false);
        room.state = RoomState.LOADED;
        stopping_room_ref = null;
        room.player_ref = null;
        if (room._callback) |c| c(room);
        room._callback = null;
    }

    pub fn getActiveRoomForPlayer(player_ref: String) ?*Room {
        var it = rooms.valueIterator();
        while (it.next()) |r| {
            if (r.player_ref) |p|
                if ((r.state == RoomState.RUNNING or r.state == RoomState.STARTING or r.state == RoomState.STOPPING) and
                    utils.stringEquals(p, player_ref)) return r;
        }

        return null;
    }

    pub fn addTask(
        room_name: String,
        task: api.Task,
        life_cycle: api.CompositeLifeCycle,
        attributes: anytype,
    ) void {
        checkInCreationState(room_name);

        var attrs = api.Attributes.of(attributes);
        if (attrs) |*a| a.set(firefly.game.TaskAttributes.OWNER_COMPOSITE, room_name);

        addTaskById(
            room_name,
            api.Task.new(task).id,
            life_cycle,
            attributes,
        );
    }

    pub fn addTaskById(
        room_name: String,
        task_id: Index,
        life_cycle: api.CompositeLifeCycle,
        attributes: anytype,
    ) void {
        checkInCreationState(room_name);

        var attrs = api.Attributes.of(attributes);
        if (attrs) |*a| a.set(firefly.game.TaskAttributes.OWNER_COMPOSITE, room_name);

        if (api.Composite.byName(room_name)) |comp|
            _ = comp.withObject(.{
                .task_ref = task_id,
                .life_cycle = life_cycle,
                .attributes = attrs,
            });
    }

    pub fn addTaskByName(
        room_name: String,
        task_name: String,
        life_cycle: api.CompositeLifeCycle,
        attributes: anytype,
    ) void {
        checkInCreationState(room_name);

        var attrs = api.Attributes.of(attributes);
        if (attrs) |*a| a.set(firefly.game.TaskAttributes.OWNER_COMPOSITE, room_name);

        if (api.Composite.byName(room_name)) |comp|
            _ = comp.withObject(.{
                .task_name = task_name,
                .life_cycle = life_cycle,
                .attributes = attrs,
            });
    }

    fn checkInCreationState(room_name: String) void {
        if (Room.byName(room_name).?.state != RoomState.CREATED)
            utils.panic(api.ALLOC, "Room not in expected CREATED state: {s}", .{room_name});
    }
};
