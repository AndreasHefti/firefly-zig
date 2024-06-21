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
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
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
// 3. Activate --> run activation tasks to create needed components and entities are created from in memory meta data
// 4. Start (Scene) --> starts the room by init player and camera and play start scene if available
// 5. Play/Pause/Resume (is this room dependent?) --> pauses or resumes the play
// 6. End (Scene) --> stops the play and start end scene if available
// 7. Deactivate --> dispose all components and entities created by Activate. Only meta data persists
// 8. Dispose --> Dispose also meta data and delete the room object

pub const Room = struct {
    pub const ATTR_AREA_NAME = "ROOM_AREA_NAME";

    pub var active_room: ?String = null;

    pub fn new(name: String) Index {
        if (api.Composite.existsName(name))
            utils.panic(api.ALLOC, "Composite with name exists: {s}", .{name});

        return api.Composite.new(.{ .name = name }).id;
    }

    pub fn addAttribute(room_name: String, attr_name: String, attr_value: String) void {
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
        if (api.Composite.byName(room_name)) |room|
            room.withObject(.{
                .task_name = task_name,
                .life_cycle = life_cycle,
                .attributes = attributes,
            });
    }

    pub fn load(room_name: String) void {
        if (api.Composite.byName(room_name)) |room|
            room.load();
    }

    pub fn activate(room_name: String) void {
        api.Composite.activateByName(room_name, true);
    }
};
