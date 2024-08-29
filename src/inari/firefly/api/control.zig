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

    api.Component.registerComponent(Condition);
    api.Component.registerComponent(Task);
    api.Component.registerComponent(Trigger);
    api.Component.registerComponent(Control);
    Control.registerSubtype(VoidControl);
    api.Component.registerComponent(StateEngine);
    api.Component.registerComponent(EntityStateEngine);
    api.EComponent.registerEntityComponent(EState);
    StateSystem.init();
    EntityStateSystem.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////////////////
//// Condition Component
//////////////////////////////////////////////////////////////////////////
/// A generic condition that uses a api.RegPredicate to check
pub const Condition = struct {
    pub usingnamespace api.Component.Trait(Condition, .{
        .name = "Condition",
        .activation = false,
        .subscription = false,
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    check: api.RegPredicate,

    pub fn functionById(id: Index) api.RegPredicate {
        return Condition.byId(id).f;
    }

    pub fn functionByName(name: String) api.RegPredicate {
        return Condition.byName(name).?.check;
    }

    pub fn createAND(comptime f1: api.RegPredicate, comptime f2: api.RegPredicate) api.RegPredicate {
        return struct {
            fn check(reg: api.CallReg) bool {
                return f1(reg) and f2(reg);
            }
        }.check;
    }

    pub fn createOR(comptime f1: api.RegPredicate, comptime f2: api.RegPredicate) api.RegPredicate {
        return struct {
            fn check(reg: api.CallReg) bool {
                return f1(reg) or f2(reg);
            }
        }.check;
    }
};

//////////////////////////////////////////////////////////////////////////
//// Component Control
//////////////////////////////////////////////////////////////////////////

pub const ControlFunction = *const fn (component_id: Index, data_id: Index) void;
pub const Control = struct {
    pub usingnamespace api.Component.Trait(Control, .{
        .name = "Control",
        .grouping = true,
        .subtypes = true,
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    groups: ?api.GroupKind = null,

    controlled_component_type: api.ComponentAspect,
    update: ControlFunction,

    pub fn destruct(self: *Control) void {
        self.groups = null;
    }
};

pub fn ControlSubTypeTrait(comptime T: type, comptime ControlledType: type) type {
    return struct {
        pub const component_type = ControlledType;
        pub usingnamespace firefly.api.SubTypeTrait(Control, T);

        pub fn new(subtype: T, update: ControlFunction) *T {
            if (!initialized) @panic("Not Initialized");

            return @This().newSubType(
                Control{
                    .name = if (@hasField(T, "name")) subtype.name else null,
                    .update = update,
                    .controlled_component_type = if (@hasDecl(ControlledType, "aspect"))
                        ControlledType.aspect
                    else
                        api.ComponentAspectGroup.getAspect("VoidControl"),
                },
                subtype,
            );
        }
    };
}

pub const VoidControl = struct {
    id: Index = UNDEF_INDEX,
    name: ?String = null,
    pub usingnamespace ControlSubTypeTrait(VoidControl, VoidControl);
};

//////////////////////////////////////////////////////////////////////////
////Task and Trigger
//////////////////////////////////////////////////////////////////////////

/// NOTE: Task takes ownership over given attributes and free memory for attributes after use
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

    function: api.AttributedFunction,
    callback: ?api.AttributedFunction = null,

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

        const a_id = api.Attributes.ofGetId(attributes);

        if (self.blocking) {
            self._run(caller_id, a_id);
        } else {
            _ = std.Thread.spawn(.{}, _run, .{ self, caller_id, a_id }) catch unreachable;
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
        a_id: ?Index,
    ) void {
        self.function(caller_id, a_id);
        if (self.callback) |c|
            c(caller_id, a_id);

        // if (attributes) |*attrs| {
        //     var a = attrs;
        //     a.deinit();
        // }
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
    attributes: ?String,
    registry: api.CallReg = api.CallReg{},
    condition: api.RegPredicate,

    pub fn componentTypeInit() !void {
        firefly.api.subscribeUpdate(update);
    }

    pub fn componentTypeDeinit() void {
        firefly.api.unsubscribeUpdate(update);
    }

    fn update(_: api.UpdateEvent) void {
        var next = Trigger.nextActiveId(0);
        while (next) |i| {
            const trigger = Trigger.byId(i);
            if (trigger.condition(trigger.registry))
                Task.byId(trigger.task_ref).runWith(trigger.id, trigger.attributes);

            next = Trigger.nextActiveId(i + 1);
        }
    }
};

//////////////////////////////////////////////////////////////
//// State API
//////////////////////////////////////////////////////////////

pub const State = struct {
    id: Index = UNDEF_INDEX,
    name: ?String,
    condition: ?api.RegPredicate = null,
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
    registry: api.CallReg = api.CallReg{},
    current_state: ?*State = null,
    update_scheduler: ?api.UpdateScheduler = null,

    pub fn construct(self: *StateEngine) void {
        self.states = utils.DynArray(State).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10) catch unreachable;
        self.registry.caller_id = self.id;
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
    registry: api.CallReg = api.CallReg{},

    pub fn construct(self: *EntityStateEngine) void {
        self.states = utils.DynArray(State).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
        self.registry.caller_id = self.id;
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

pub const StateSystem = struct {
    pub usingnamespace api.SystemTrait(StateSystem);

    pub fn update(_: api.UpdateEvent) void {
        StateEngine.processActive(processEngine);
    }

    fn processEngine(state_engine: *StateEngine) void {
        if (state_engine.update_scheduler) |u| if (!u.needs_update)
            return;

        state_engine.registry.id_1 = if (state_engine.current_state) |s| s.id else UNDEF_INDEX;

        var next = state_engine.states.slots.nextSetBit(0);
        while (next) |i| {
            if (state_engine.states.get(i)) |state| {
                if (state.condition) |condition| {
                    state_engine.registry.id_2 = state.id;
                    if (condition(state_engine.registry)) {
                        state_engine.setNewState(state);
                        return;
                    }
                }
            }
            next = state_engine.states.slots.nextSetBit(i + 1);
        }
    }
};

pub const EntityStateSystem = struct {
    pub usingnamespace api.SystemTrait(EntityStateSystem);
    pub usingnamespace api.EntityUpdateTrait(EntityStateSystem);
    pub const accept = .{EState};

    pub fn updateEntities(components: *utils.BitSet) void {
        var next = components.nextSetBit(0);
        while (next) |i| {
            if (EState.byId(i)) |e| processEntity(e);
            next = components.nextSetBit(i + 1);
        }
    }

    inline fn processEntity(entity: *EState) void {
        const state_engine = EntityStateEngine.byId(entity.state_engine_ref);
        state_engine.registry.id_2 = if (entity.current_state) |s| s.id else UNDEF_INDEX;
        var next = state_engine.states.slots.nextSetBit(0);
        while (next) |i| {
            next = state_engine.states.slots.nextSetBit(i + 1);
            if (state_engine.states.get(i)) |state| {
                if (state.id == state_engine.registry.id_2)
                    continue;

                if (state.condition) |condition| {
                    state_engine.registry.id_1 = entity.id;

                    if (condition(state_engine.registry)) {
                        EntityStateEngine.setNewState(entity, state);
                        return;
                    }
                }
            }
        }
    }
};
