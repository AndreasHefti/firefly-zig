const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;

const PosF = firefly.utils.PosF;
const Index = firefly.utils.Index;
const String = firefly.utils.String;
const Float = firefly.utils.Float;
const Color = firefly.utils.Color;
const BlendMode = firefly.api.BlendMode;
const RectF = firefly.utils.RectF;
const CInt = firefly.utils.CInt;
const BindingId = firefly.api.BindingId;
const NO_BINDING = firefly.api.NO_BINDING;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

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
    state: RoomState = RoomState.NONE,
    bounds: utils.Vector4f = .{},

    start_scene_ref: ?String = null,
    end_scene_ref: ?String = null,
    composite_ref: Index = undefined,

    var rooms: std.StringHashMap(Room) = undefined;

    var active_room: ?String = null;
    var next_room: ?String = null;

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
            utils.panic(api.ALLOC, "Room with name already exists: {}", .{room.name});

        result.value_ptr.* = room;
        result.value_ptr.composite_ref = api.Composite.new(.{ .name = room.name }).id;
        result.value_ptr.state = RoomState.CREATED;
        return result.value_ptr;
    }

    pub fn deconstruct(self: *Room) void {
        dispose(self);

        api.Composite.disposeById(self.composite_ref);
        _ = rooms.remove(self.name);
    }

    pub fn get(name: String) ?*Room {
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
        if (self.state == RoomState.PAUSED or self.state == RoomState.RUNNING)
            endActiveRoom();

        api.Composite.byId(self.composite_ref).dispose();
    }

    // 3. Start --> end active room when available,
    //              runs activation tasks to create needed components and entities are created from in memory meta data,
    //              and runs start scene if available
    pub fn start(self: *Room) void {
        // if start already running ignore call
        if (self.state == RoomState.STARTING) return;
        // load room is not already loaded --> but should be loaded before
        if (self.state == RoomState.CREATED) self.load();
        // ignore when room is in unexpected state
        if (self.state != RoomState.LOADED) return;

        // add self as next starting room.
        // this lock also starting another room until self has fully started
        next_room = self.name;

        // end active room first if available
        if (active_room) |_| {
            // if next room is already defined and going to start soon, ignore start call
            if (next_room != null or self.state == RoomState.STARTING) return;
            Room.endActiveRoom();
            return;
        }

        self.state = RoomState.STARTING;
        // activate all room objects
        api.Composite.activateByName(self.name, true);
        pause();

        // run start scene if defined
        if (self.start_scene_ref) |scene_name| {
            if (firefly.graphics.Scene.byName(scene_name)) |scene| {
                scene.callback = runNextRoomCallback;
                scene.run();
            }
            return;
        } else runNextRoom();
    }

    fn runNextRoom() void {
        if (next_room) |name| {
            const room = Room.get(name).?;
            active_room = room.name;
            next_room = null;
            _resume();
            room.state = RoomState.RUNNING;
        }
    }

    fn runNextRoomCallback(_: Index, _: api.ActionResult) void {
        runNextRoom();
    }

    pub fn pause() void {}

    pub fn _resume() void {}

    // 6. End (Scene) --> stops the play and start end scene if available,
    //                    deactivates all registered component refs and run registered deactivation tasks.
    pub fn endActiveRoom() void {
        // ignore call when there is no active room
        if (active_room == null) return;

        if (Room.get(active_room.?)) |room| {
            // ignore when room is already stopping
            if (room.state == RoomState.STOPPING) return;

            room.state = RoomState.STOPPING;
            // pause room
            pause();
            // if end scene defined run it and wait for callback
            if (room.end_scene_ref) |scene_name| {
                if (firefly.graphics.Scene.byName(scene_name)) |scene| {
                    scene.callback = deactivateRoomCallback;
                    scene.run();
                }
                return;
            } else deactivateRoom();
        }
    }

    fn deactivateRoom() void {
        // deactivate all room objects
        if (active_room) |name| {
            api.Composite.activateByName(name, false);
            if (Room.get(name)) |room|
                room.state = RoomState.LOADED;
        }

        active_room = null;

        if (next_room) |name| {
            if (Room.get(name)) |room|
                room.start();
        }
    }

    fn deactivateRoomCallback(_: Index, _: api.ActionResult) void {
        deactivateRoom();
    }

    pub fn addAttribute(room_name: String, attr_name: String, attr_value: String) void {
        checkInCreationState(room_name);
        if (api.Composite.byName(room_name)) |room|
            room.attributes.set(attr_name, attr_value);
    }

    pub fn addLoadTask(room_name: String, task: api.Task, call_attributes: ?api.Attributes) void {
        addTask(room_name, task, api.CompositeLifeCycle.LOAD, call_attributes);
    }

    pub fn addLoadTaskById(room_name: String, task_id: Index, call_attributes: ?api.Attributes) void {
        addTaskById(room_name, task_id, api.CompositeLifeCycle.LOAD, call_attributes);
    }

    pub fn addLoadTaskByName(room_name: String, task_name: String, call_attributes: ?api.Attributes) void {
        addTaskByName(room_name, task_name, api.CompositeLifeCycle.LOAD, call_attributes);
    }

    pub fn addActivationTask(room_name: String, task: api.Task, call_attributes: ?api.Attributes) void {
        addTask(room_name, task, api.CompositeLifeCycle.ACTIVATE, call_attributes);
    }

    pub fn addActivationTaskById(room_name: String, task_id: Index, call_attributes: ?api.Attributes) void {
        addTaskById(room_name, task_id, api.CompositeLifeCycle.ACTIVATE, call_attributes);
    }

    pub fn addActivationTaskByName(room_name: String, task_name: String, call_attributes: ?api.Attributes) void {
        addTaskByName(room_name, task_name, api.CompositeLifeCycle.ACTIVATE, call_attributes);
    }

    pub fn addTask(
        room_name: String,
        task: api.Task,
        life_cycle: api.CompositeLifeCycle,
        call_attributes: ?api.Attributes,
    ) void {
        checkInCreationState(room_name);
        addTaskById(
            room_name,
            api.Task.new(task).id,
            life_cycle,
            call_attributes,
        );
    }

    pub fn addTaskById(
        room_name: String,
        task_id: Index,
        life_cycle: api.CompositeLifeCycle,
        attributes: ?api.Attributes,
    ) void {
        checkInCreationState(room_name);
        if (api.Composite.byName(room_name)) |room|
            room.withObject(.{
                .task_ref = task_id,
                .life_cycle = life_cycle,
                .attributes = attributes,
            });
    }

    pub fn addTaskByName(
        room_name: String,
        task_name: String,
        life_cycle: api.CompositeLifeCycle,
        attributes: ?api.Attributes,
    ) void {
        checkInCreationState(room_name);
        if (api.Composite.byName(room_name)) |room|
            room.withObject(.{
                .task_name = task_name,
                .life_cycle = life_cycle,
                .attributes = attributes,
            });
    }

    fn checkInCreationState(room_name: String) void {
        if (Room.get(room_name).?.state != RoomState.CREATED)
            utils.panic(api.ALLOC, "Room not in expected CREATED state: {s}", .{room_name});
    }
};
