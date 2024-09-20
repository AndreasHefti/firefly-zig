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
    check: api.CallPredicate,

    pub fn functionById(id: Index) api.CallPredicate {
        return Condition.byId(id).f;
    }

    pub fn functionByName(name: String) api.CallPredicate {
        return Condition.byName(name).?.check;
    }

    pub fn createAND(comptime f1: api.CallPredicate, comptime f2: api.RegPredicate) api.CallPredicate {
        return struct {
            fn check(reg: *api.CallContext) bool {
                return f1(reg) and f2(reg);
            }
        }.check;
    }

    pub fn createOR(comptime f1: api.CallPredicate, comptime f2: api.CallPredicate) api.CallPredicate {
        return struct {
            fn check(reg: *api.CallContext) bool {
                return f1(reg) or f2(reg);
            }
        }.check;
    }
};

//////////////////////////////////////////////////////////////////////////
//// Component Control
//////////////////////////////////////////////////////////////////////////

pub const Control = struct {
    pub usingnamespace api.Component.Trait(Control, .{
        .name = "Control",
        .grouping = true,
        .subtypes = true,
    });
    pub usingnamespace api.CallContextTrait(Control);

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    groups: ?api.GroupKind = null,

    controlled_component_type: api.ComponentAspect,
    call_context: api.CallContext = undefined,
    update: api.CallFunction,

    pub fn construct(self: *Control) void {
        self.initCallContext(true);
    }

    pub fn destruct(self: *Control) void {
        self.deinitCallContext();
        self.groups = null;
    }
};

pub fn ControlSubTypeTrait(comptime T: type, comptime ControlledType: type) type {
    return struct {
        pub const component_type = ControlledType;
        pub usingnamespace firefly.api.SubTypeTrait(Control, T);

        pub fn new(subtype: T, update: api.CallFunction) *T {
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

    function: api.CallFunction,
    callback: ?api.CallFunction = null,

    pub fn run(self: *Task) void {
        var ctx = api.CallContext{};
        defer ctx.deinit();
        self.runWith(ctx, true);
    }

    pub fn runWith(self: *Task, context: *api.CallContext, owned: bool) void {
        if (self.blocking) {
            self._run(context, owned);
        } else {
            _ = std.Thread.spawn(.{}, _run, .{ self, context, owned }) catch unreachable;
        }
    }

    pub fn runTaskById(task_id: Index) void {
        var ctx = api.CallContext{};
        Task.byId(task_id).runWith(&ctx, false);
    }

    pub fn runOwnedTaskById(task_id: Index, context: *api.CallContext) void {
        Task.byId(task_id).runWith(context, true);
    }

    pub fn runTaskByIdWith(task_id: Index, context: api.CallContext) void {
        var ctx = context;
        Task.byId(task_id).runWith(&ctx, false);
    }

    pub fn runTaskByName(task_name: String) void {
        if (Task.byName(task_name)) |task| {
            var ctx = api.CallContext{};
            task.runWith(&ctx, false);
        }
    }

    pub fn runTaskByNameWith(task_name: String, context: api.CallContext) void {
        if (Task.byName(task_name)) |task| {
            var ctx = context;
            task.runWith(&ctx, false);
        } else utils.panic(api.ALLOC, "No Task with name {s} found!", .{task_name});
    }

    pub fn runOwnedTaskByName(task_name: String, context: *api.CallContext) void {
        if (Task.byName(task_name)) |task| {
            task.runWith(context, true);
        }
    }

    fn _run(self: *Task, context: *api.CallContext, owned: bool) void {
        self.function(context);
        if (self.callback) |c|
            c(context);

        if (!owned)
            context.deinit();

        if (self.run_once)
            Task.disposeById(self.id);
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
    pub usingnamespace api.CallContextTrait(Trigger);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    task_ref: Index,
    call_context: api.CallContext = undefined,
    condition: api.CallPredicate,

    pub fn componentTypeInit() !void {
        firefly.api.subscribeUpdate(update);
    }

    pub fn componentTypeDeinit() void {
        firefly.api.unsubscribeUpdate(update);
    }

    pub fn construct(self: *Trigger) void {
        self.initCallContext(true);
    }

    pub fn destruct(self: *Trigger) void {
        self.deinitCallContext();
    }

    fn update(_: api.UpdateEvent) void {
        var next = Trigger.nextActiveId(0);
        while (next) |i| {
            const trigger = Trigger.byId(i);
            if (trigger.condition(&trigger.call_context))
                Task.byId(trigger.task_ref).runWith(&trigger.call_context, true);

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
    condition: ?api.CallPredicate = null,
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
    pub usingnamespace api.CallContextTrait(StateEngine);

    id: Index = UNDEF_INDEX,
    name: ?String,
    states: utils.DynArray(State) = undefined,
    call_context: api.CallContext = undefined,
    current_state: ?*State = null,
    update_scheduler: ?api.UpdateScheduler = null,

    pub fn construct(self: *StateEngine) void {
        self.states = utils.DynArray(State).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10) catch unreachable;
        self.initCallContext(true);
    }

    pub fn destruct(self: *StateEngine) void {
        self.states.deinit();
        self.deinitCallContext();
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
    pub usingnamespace api.CallContextTrait(EntityStateEngine);

    id: Index = UNDEF_INDEX,
    name: ?String,
    states: utils.DynArray(State) = undefined,
    call_context: api.CallContext = undefined,

    pub fn construct(self: *EntityStateEngine) void {
        self.states = utils.DynArray(State).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
        self.initCallContext(true);
    }

    pub fn destruct(self: *EntityStateEngine) void {
        self.states.deinit();
        self.deinitCallContext();
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

        state_engine.call_context.id_1 = if (state_engine.current_state) |s| s.id else UNDEF_INDEX;

        var next = state_engine.states.slots.nextSetBit(0);
        while (next) |i| {
            if (state_engine.states.get(i)) |state| {
                if (state.condition) |condition| {
                    state_engine.call_context.id_2 = state.id;
                    if (condition(&state_engine.call_context)) {
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
        state_engine.call_context.id_2 = if (entity.current_state) |s| s.id else UNDEF_INDEX;
        var next = state_engine.states.slots.nextSetBit(0);
        while (next) |i| {
            next = state_engine.states.slots.nextSetBit(i + 1);
            if (state_engine.states.get(i)) |state| {
                if (state.id == state_engine.call_context.id_2)
                    continue;

                if (state.condition) |condition| {
                    state_engine.call_context.id_1 = entity.id;

                    if (condition(&state_engine.call_context)) {
                        EntityStateEngine.setNewState(entity, state);
                        return;
                    }
                }
            }
        }
    }
};
