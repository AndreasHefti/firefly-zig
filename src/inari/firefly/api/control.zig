const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;

const String = firefly.utils.String;
const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.Condition(*const fn (*const CallContext) bool).init();
    api.Condition(*const fn (Index, ?*State) bool).init();
    api.Component.registerComponent(Task);
    api.Component.registerComponent(Trigger);
    api.Component.registerComponent(ComponentControl);
    api.Component.registerComponent(StateEngine);
    api.Component.registerComponent(EntityStateEngine);
    api.EComponent.registerEntityComponent(EState);

    api.System(StateSystem).createSystem(
        firefly.Engine.CoreSystems.StateSystem.name,
        "Updates all active StateEngine components, and change state on conditions",
        false,
    );
    api.System(EntityStateSystem).createSystem(
        firefly.Engine.CoreSystems.EntityStateSystem.name,
        "Updates all active Entities with EState components, and change state on conditions",
        false,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    api.System(StateSystem).disposeSystem();
    api.System(EntityStateSystem).disposeSystem();
    api.Condition(*const fn (*const CallContext) bool).deinit();
    api.Condition(*const fn (Index, ?*State) bool).deinit();
}

//////////////////////////////////////////////////////////////////////////
//// CallContext
//////////////////////////////////////////////////////////////////////////

pub const CallContext = struct {
    parent_id: Index,
    caller_id: ?Index = null,
    attributes: ?api.Attributes = null,

    pub fn deinit(self: *CallContext) void {
        if (self.attributes) |*p|
            p.deinit();
        self.attributes = undefined;
    }

    pub fn set(self: *CallContext, name: String, value: String) void {
        if (self.attributes == null)
            self.attributes = api.Attributes.new();

        self.attributes.?.set(name, value);
    }

    pub fn setAll(self: *CallContext, attributes: api.Attributes) void {
        if (self.attributes == null)
            self.attributes = api.Attributes.new();

        self.attributes.?.setAll(attributes);
    }

    pub fn get(self: CallContext, name: String) ?String {
        if (self.attributes) |a| return a.get(name);
        return null;
    }

    pub fn format(
        self: CallContext,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("CallContext[ parent_id: {d} caller_id: {?d}", .{ self.parent_id, self.caller_id });
        if (self.attributes) |p| {
            try writer.print(" attributes: ", .{});
            var i = p._map.iterator();
            while (i.next()) |e|
                try writer.print("{s}={s}, ", .{ e.key_ptr.*, e.value_ptr.* });
        }
        try writer.print(" ]", .{});
    }
};

//////////////////////////////////////////////////////////////////////////
//// Call Condition
//////////////////////////////////////////////////////////////////////////

pub const CallCondition = api.Condition(*const fn (*const CallContext) bool);

//////////////////////////////////////////////////////////////////////////
//// Component Control
//////////////////////////////////////////////////////////////////////////

pub const ControlFunction = *const fn (component_id: Index, data_id: ?Index) void;
pub const ControlDispose = *const fn (data_id: ?Index) void;

pub const ComponentControl = struct {
    pub usingnamespace api.Component.Trait(ComponentControl, .{
        .name = "ComponentControl",
        .grouping = true,
        .subscription = false,
    });

    component_type: api.ComponentAspect,
    id: Index = UNDEF_INDEX,
    name: ?String = null,
    groups: ?api.GroupKind = null,

    f: ControlFunction,
    data_id: ?Index = null,
    dispose: ?ControlDispose = null,

    pub fn destruct(self: *ComponentControl) void {
        if (self.dispose) |df| df(self.data_id);
        self.groups = null;
    }

    pub fn update(control_id: Index, component_id: Index) void {
        if (ComponentControl.getWhenActiveById(control_id)) |c|
            c.f(component_id, c.data_id);
    }
};

pub fn ControlTypeTrait(comptime T: type, comptime ComponentType: type) type {
    return struct {
        pub const component_type = ComponentType;
        pub fn byName(name: String) ?*T {
            const control = ComponentControl.byName(name) orelse return null;
            return byId(control.data_id);
        }

        pub fn byId(data_id: ?Index) ?*T {
            const id = data_id orelse return null;
            return ComponentControlType(T).dataById(id);
        }
    };
}

pub fn ComponentControlType(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects component control type is a struct.");
        if (!@hasDecl(T, "update"))
            @compileError("Expects component control type to have function 'update(Index)'");
        if (!@hasDecl(T, "component_type"))
            @compileError("Expects component control type to have var 'component_type: ComponentAspect'");
    }

    return struct {
        const Self = @This();

        var data: utils.DynArray(T) = undefined;

        pub fn init() void {
            data = utils.DynArray(T).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 5);
        }

        pub fn deinit() void {
            data.deinit();
            data = undefined;
        }

        pub fn dataById(id: Index) ?*T {
            return data.get(id);
        }

        pub fn new(control_type: T) *ComponentControl {
            if (!initialized) @panic("Not Initialized");

            var control = ComponentControl.new(.{
                .name = if (@hasField(T, "name")) control_type.name else null,
                .f = T.update,
                .component_type = firefly.api.ComponentAspectGroup.getAspectFromAnytype(T.component_type).?,
                .dispose = dispose,
            });

            control.data_id = data.add(control_type);
            return control;
        }

        fn dispose(id: ?Index) void {
            if (!initialized) return;
            if (id) |i|
                data.delete(i);
        }
    };
}

//////////////////////////////////////////////////////////////////////////
//// Action, Task and Trigger
//////////////////////////////////////////////////////////////////////////

pub const ActionResult = enum {
    Running,
    Success,
    Failed,
};

pub const UpdateActionFunction = *const fn (Index) ActionResult;
pub const UpdateActionCallback = *const fn (Index, ActionResult) void;

pub const TaskFunction = *const fn (CallContext) void;
pub const TaskCallback = *const fn (CallContext) void;

/// Task takes ownership over given attributes and free memory for attributes after use
pub const Task = struct {
    pub usingnamespace api.Component.Trait(Task, .{
        .name = "Task",
        .activation = false,
        .subscription = false,
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    run_once: bool = false,
    blocking: bool = true,

    function: TaskFunction,
    callback: ?TaskCallback = null,

    pub fn run(self: *Task) void {
        self.runWith(self, null, null);
    }

    pub fn runWith(
        self: *Task,
        caller_id: ?Index,
        attributes: anytype,
    ) void {
        defer {
            if (self.run_once)
                Task.disposeById(self.id);
        }

        const attrs = api.Attributes.of(attributes);

        if (self.blocking) {
            self._run(caller_id, attrs);
        } else {
            _ = std.Thread.spawn(.{}, _run, .{ self, caller_id, attrs }) catch unreachable;
        }
    }

    pub fn runTaskById(task_id: Index) void {
        Task.byId(task_id).runWith(null, null);
    }

    pub fn runTaskByIdWith(task_id: Index, caller_id: ?Index, attributes: anytype) void {
        Task.byId(task_id).runWith(caller_id, attributes);
    }
    pub fn runTaskByName(task_name: String) void {
        if (Task.byName(task_name)) |t| t.runWith(null, null);
    }

    pub fn runTaskByNameWith(task_name: String, caller_id: ?Index, attributes: anytype) void {
        if (Task.byName(task_name)) |t| t.runWith(caller_id, attributes);
    }

    fn _run(
        self: *Task,
        caller_id: ?Index,
        attributes: ?api.Attributes,
    ) void {
        const context: CallContext = .{
            .parent_id = self.id,
            .caller_id = caller_id,
            .attributes = attributes,
        };

        self.function(context);
        if (self.callback) |c|
            c(context);

        if (attributes) |attrs| {
            var a = attrs;
            a.deinit();
        }
    }

    pub fn format(
        self: Task,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Task[ id:{d} name:{?s} run_once:{any} blocking:{any} callback:{any} ] ",
            .{ self.id, self.name, self.run_once, self.blocking, self.callback != null },
        );
    }
};

pub const Trigger = struct {
    pub usingnamespace api.Component.Trait(Trigger, .{
        .name = "Trigger",
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    task_ref: Index,
    condition: CallCondition.Function,
    context: CallContext = undefined,

    pub fn componentTypeInit() !void {
        firefly.api.subscribeUpdate(update);
    }

    pub fn componentTypeDeinit() void {
        firefly.api.unsubscribeUpdate(update);
    }

    pub fn construct(self: *Trigger) void {
        self.context = .{ .parent_id = self.id };
    }

    pub fn destruct(self: *Trigger) void {
        self.context.deinit();
    }

    fn update(_: api.UpdateEvent) void {
        var next = Trigger.nextActiveId(0);
        while (next) |i| {
            const trigger = Trigger.byId(i);
            if (trigger.condition(&trigger.context))
                Task.byId(trigger.task_ref).runWith(trigger.id, trigger.context.attributes);

            next = Trigger.nextActiveId(i + 1);
        }
    }
};

//////////////////////////////////////////////////////////////
//// State API
//////////////////////////////////////////////////////////////

pub const StateCondition = api.Condition(*const fn (Index, ?*State) bool);

pub const State = struct {
    id: Index = UNDEF_INDEX,
    name: ?String,
    // Note using StateConditionFunction here results in dependency loop detected error (don't know why)
    condition: ?StateCondition.Function = null,
    init: ?*const fn (Index) void = null,
    dispose: ?*const fn (Index) void = null,

    pub fn equals(self: *State, other: ?*State) bool {
        if (other) |s| {
            return std.mem.eql(String, self.name, s.name);
        }
        return false;
    }
};

//////////////////////////////////////////////////////////////
//// State Engine Component
//////////////////////////////////////////////////////////////

pub const StateEngine = struct {
    pub usingnamespace api.Component.Trait(StateEngine, .{ .name = "StateEngine" });

    id: Index = UNDEF_INDEX,
    name: ?String,
    states: utils.DynArray(State) = undefined,
    current_state: ?*State = null,
    update_scheduler: ?api.UpdateScheduler = null,

    pub fn construct(self: *StateEngine) void {
        self.states = utils.DynArray(State).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10) catch unreachable;
    }

    pub fn destruct(self: *StateEngine) void {
        self.states.deinit();
    }

    pub fn withState(self: *StateEngine, state: State) *StateEngine {
        const s = self.states.addAndGet(state);
        if (state.condition) |condition| {
            if (condition(self.id, self.current_state))
                setNewState(self, s.ref);
        }
        return self;
    }

    pub fn setState(self: *StateEngine, name: String) void {
        var next_state: ?*State = null;
        var next = self.states.slots.nextSetBit(0);
        while (next) |i| {
            next_state = self.states.get(i).?;
            if (next_state.hasName(name))
                break;
            next_state = null;
            next = self.states.slots.nextSetBit(i + 1);
        }

        if (next_state) |ns| setNewState(ns);
    }

    fn setNewState(self: *StateEngine, target: *State) void {
        if (self.current_state) |cs|
            if (cs.dispose) |df| df(self.id);

        if (target.init) |in| in(self.id);
        self.current_state = target;
    }
};

//////////////////////////////////////////////////////////////
//// EntityStateEngine
//////////////////////////////////////////////////////////////

pub const EntityStateEngine = struct {
    pub usingnamespace api.Component.Trait(EntityStateEngine, .{ .name = "EntityStateEngine" });

    id: Index = UNDEF_INDEX,
    name: ?String,
    states: utils.DynArray(State) = undefined,

    pub fn construct(self: *EntityStateEngine) void {
        self.states = utils.DynArray(State).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
    }

    pub fn destruct(self: *EntityStateEngine) void {
        self.states.deinit();
    }

    pub fn withState(self: *EntityStateEngine, state: State) *EntityStateEngine {
        _ = self.states.add(state);
        return self;
    }

    fn setNewState(entity: *EState, target: *State) void {
        if (entity.current_state) |cs|
            if (cs.dispose) |df| df(entity.id);

        if (target.init) |in| in(entity.id);
        entity.current_state = target;
    }
};

pub const EState = struct {
    pub usingnamespace api.EComponent.Trait(@This(), "EState");

    id: Index = UNDEF_INDEX,
    state_engine_ref: Index = undefined,
    current_state: ?*State = null,

    pub fn withStateEngineByName(self: *EState, name: String) *EState {
        self.state_engine_ref = EntityStateEngine.idByName(name) orelse undefined;
        return self;
    }
};

//////////////////////////////////////////////////////////////
//// State Systems
//////////////////////////////////////////////////////////////

const StateSystem = struct {
    pub fn update(_: api.UpdateEvent) void {
        StateEngine.processActive(processEngine);
    }

    fn processEngine(state_engine: *StateEngine) void {
        if (state_engine.update_scheduler) |u| if (!u.needs_update)
            return;

        var next = state_engine.states.slots.nextSetBit(0);
        while (next) |i| {
            if (state_engine.states.get(i)) |state| {
                if (state.condition) |condition| {
                    if (condition(state_engine.id, state_engine.current_state)) {
                        state_engine.setNewState(state);
                        return;
                    }
                }
            }
            next = state_engine.states.slots.nextSetBit(i + 1);
        }
    }
};

const EntityStateSystem = struct {
    pub var entity_condition: api.EntityTypeCondition = undefined;
    var entities: utils.BitSet = undefined;

    pub fn systemInit() void {
        entities = utils.BitSet.new(firefly.api.COMPONENT_ALLOC);
        entity_condition = api.EntityTypeCondition{
            .accept_kind = api.EComponentAspectGroup.newKindOf(.{EState}),
        };
    }

    pub fn systemDeinit() void {
        entity_condition = undefined;
        entities.deinit();
        entities = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        entities.setValue(id, register);
    }

    pub fn update(_: api.UpdateEvent) void {
        var next = entities.nextSetBit(0);
        while (next) |i| {
            if (EState.byId(i)) |e| processEntity(e);
            next = entities.nextSetBit(i + 1);
        }
    }

    inline fn processEntity(entity: *EState) void {
        const state_engine = EntityStateEngine.byId(entity.state_engine_ref);
        var next = state_engine.states.slots.nextSetBit(0);
        while (next) |i| {
            if (state_engine.states.get(i)) |state| {
                if (entity.current_state) |cs| {
                    if (state == cs) {
                        next = state_engine.states.slots.nextSetBit(i + 1);
                        continue;
                    }
                }

                if (state.condition) |condition| {
                    if (condition(entity.id, entity.current_state)) {
                        EntityStateEngine.setNewState(entity, state);
                        return;
                    }
                }
            }
            next = state_engine.states.slots.nextSetBit(i + 1);
        }
    }
};
