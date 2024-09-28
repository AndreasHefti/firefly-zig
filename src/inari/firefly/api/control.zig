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

    api.Component.register(Condition, "Condition");
    api.Component.register(Task, "Task");
    api.Component.register(Trigger, "Trigger");
    api.Component.register(Control, "Control");
    api.Component.register(StateEngine, "StateEngine");
    api.Component.register(EntityStateEngine, "EntityStateEngine");
    api.Component.Subtype.register(Control, VoidControl, "VoidControl");
    api.Entity.registerComponent(EState, "EState");
    api.System.register(StateSystem);
    api.System.register(EntityStateSystem);
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
    pub const Component = api.Component.Mixin(Condition);
    pub const Naming = api.Component.NameMappingMixin(Condition);

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    check: api.CallPredicate,

    pub fn functionById(id: Index) api.CallPredicate {
        return Component.byId(id).f;
    }

    pub fn functionByName(name: String) api.CallPredicate {
        return Naming.byName(name).?.check;
    }

    pub fn createAND(comptime f1: api.CallPredicate, comptime f2: api.CallPredicate) api.CallPredicate {
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
    pub const Component = api.Component.Mixin(Control);
    pub const Naming = api.Component.NameMappingMixin(Control);
    pub const Activation = api.Component.ActivationMixin(Control);
    pub const Grouping = api.Component.GroupingMixin(Control);
    pub const Subscription = api.Component.SubscriptionMixin(Control);
    pub const Subtypes = api.Component.SubTypingMixin(Control);
    pub const CallContext = api.Component.CallContextMixin(Control);
    pub const init_attributes = true;

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    groups: ?api.GroupKind = null,
    controlled_component_type: api.ComponentAspect,

    call_context: api.CallContext = undefined,
    update: api.CallFunction,

    pub fn createForSubType(subtype: anytype) *Control {
        const c_subtype_type = @TypeOf(subtype);
        const update = if (@hasDecl(c_subtype_type, "update")) c_subtype_type.update else subtype.update;
        const name = if (@hasField(c_subtype_type, "name")) subtype.name else @typeName(c_subtype_type);
        return Component.newForSubType(.{
            .name = name,
            .update = update,
            .controlled_component_type = if (@hasDecl(c_subtype_type, "controlledComponentType"))
                c_subtype_type.controlledComponentType()
            else
                api.ComponentAspectGroup.getAspect("VoidControl"),
        });
    }
};

pub const VoidControl = struct {
    pub const Component = api.Component.SubTypeMixin(api.Control, VoidControl);

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    update: api.CallFunction,
};

//////////////////////////////////////////////////////////////////////////
////Task and Trigger
//////////////////////////////////////////////////////////////////////////

pub const Task = struct {
    pub const Component = api.Component.Mixin(Task);
    pub const Naming = api.Component.NameMappingMixin(Task);

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
        Component.byId(task_id).runWith(&ctx, false);
    }

    pub fn runOwnedTaskById(task_id: Index, context: *api.CallContext) void {
        Component.byId(task_id).runWith(context, true);
    }

    pub fn runTaskByIdWith(task_id: Index, context: api.CallContext) void {
        var ctx = context;
        Component.byId(task_id).runWith(&ctx, false);
    }

    pub fn runTaskByName(task_name: String) void {
        if (Naming.byName(task_name)) |task| {
            var ctx = api.CallContext{};
            task.runWith(&ctx, false);
        }
    }

    pub fn runTaskByNameWith(task_name: String, context: api.CallContext) void {
        if (Naming.byName(task_name)) |task| {
            var ctx = context;
            task.runWith(&ctx, false);
        } else utils.panic(api.ALLOC, "No Task with name {s} found!", .{task_name});
    }

    pub fn runOwnedTaskByName(task_name: String, context: *api.CallContext) void {
        if (Naming.byName(task_name)) |task| {
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
            Task.Component.dispose(self.id);
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
    pub const Component = api.Component.Mixin(Trigger);
    pub const Naming = api.Component.NameMappingMixin(Trigger);
    pub const Activation = api.Component.ActivationMixin(Trigger);
    pub const CallContext = api.Component.CallContextMixin(Trigger);
    pub const init_attributes = true;

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

    fn update(_: api.UpdateEvent) void {
        var next = Activation.nextId(0);
        while (next) |i| {
            next = Activation.nextId(i + 1);
            const trigger = Component.byId(i);
            if (trigger.condition(&trigger.call_context))
                Task.Component.byId(trigger.task_ref).runWith(&trigger.call_context, true);
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
    pub const Component = api.Component.Mixin(StateEngine);
    pub const Naming = api.Component.NameMappingMixin(StateEngine);
    pub const Activation = api.Component.ActivationMixin(StateEngine);
    pub const Subscription = api.Component.SubscriptionMixin(StateEngine);
    pub const CallContext = api.Component.CallContextMixin(StateEngine);
    pub const init_attributes = true;

    id: Index = UNDEF_INDEX,
    name: ?String,

    states: utils.DynArray(State) = undefined,
    call_context: api.CallContext = undefined,
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
    pub const Component = api.Component.Mixin(EntityStateEngine);
    pub const Naming = api.Component.NameMappingMixin(EntityStateEngine);
    pub const Activation = api.Component.ActivationMixin(EntityStateEngine);
    pub const Subscription = api.Component.SubscriptionMixin(EntityStateEngine);
    pub const CallContext = api.Component.CallContextMixin(EntityStateEngine);
    pub const init_attributes = true;

    id: Index = UNDEF_INDEX,
    name: ?String,
    states: utils.DynArray(State) = undefined,
    call_context: api.CallContext = undefined,

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
    pub const Component = api.EntityComponentMixin(EState);

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
    pub const System = api.SystemMixin(StateSystem);

    pub fn update(_: api.UpdateEvent) void {
        StateEngine.Activation.process(processEngine);
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
    pub const System = api.SystemMixin(EntityStateSystem);
    pub const EntityUpdate = api.EntityUpdateSystemMixin(EntityStateSystem);
    pub const accept = .{EState};

    pub fn updateEntities(components: *utils.BitSet) void {
        var next = components.nextSetBit(0);
        while (next) |i| {
            if (EState.Component.byId(i)) |e| processEntity(e);
            next = components.nextSetBit(i + 1);
        }
    }

    inline fn processEntity(entity: *EState) void {
        const state_engine = EntityStateEngine.Component.byId(entity.state_engine_ref);
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
