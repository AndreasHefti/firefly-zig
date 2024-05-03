const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const api = firefly.api;

const System = api.System;
const UpdateScheduler = api.UpdateScheduler;
const EComponent = api.EComponent;
const EntityCondition = api.EntityCondition;
const EComponentAspectGroup = api.EComponentAspectGroup;
const UpdateEvent = api.UpdateEvent;
const BitSet = utils.BitSet;
const DynArray = utils.DynArray;
const Component = api.Component;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// state init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(StateEngine);
    Component.registerComponent(EntityStateEngine);
    EComponent.registerEntityComponent(EState);

    System(StateSystem).createSystem(
        firefly.Engine.CoreSystems.StateSystem.name,
        "Updates all active StateEngine components, and change state on conditions",
        false,
    );
    System(EntityStateSystem).createSystem(
        firefly.Engine.CoreSystems.EntityStateSystem.name,
        "Updates all active Entities with EState components, and change state on conditions",
        false,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    System(StateSystem).disposeSystem();
    System(EntityStateSystem).disposeSystem();
}

//////////////////////////////////////////////////////////////
//// State API
//////////////////////////////////////////////////////////////

pub const State = struct {
    id: Index = UNDEF_INDEX,
    name: ?String,
    condition: ?*const fn (Index, current: ?*State) bool = null,
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
    pub usingnamespace Component.Trait(StateEngine, .{ .name = "StateEngine" });

    id: Index = UNDEF_INDEX,
    name: ?String,
    states: DynArray(State) = undefined,
    current_state: ?*State = null,
    update_scheduler: ?*UpdateScheduler = null,

    pub fn construct(self: *StateEngine) void {
        self.states = DynArray(State).newWithRegisterSize(api.ALLOC, 10) catch unreachable;
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
    pub usingnamespace Component.Trait(EntityStateEngine, .{ .name = "EntityStateEngine" });

    id: Index = UNDEF_INDEX,
    name: ?String,
    states: DynArray(State) = undefined,

    pub fn construct(self: *EntityStateEngine) void {
        self.states = DynArray(State).newWithRegisterSize(api.ALLOC, 10) catch unreachable;
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
    pub usingnamespace EComponent.Trait(@This(), "EState");

    id: Index = UNDEF_INDEX,
    state_engine: *EntityStateEngine,
    current_state: ?*State = null,
};

//////////////////////////////////////////////////////////////
//// State Systems
//////////////////////////////////////////////////////////////

const StateSystem = struct {
    pub fn update(_: UpdateEvent) void {
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
    pub var entity_condition: EntityCondition = undefined;
    var entities: BitSet = undefined;

    pub fn systemInit() void {
        entities = BitSet.new(api.ALLOC) catch undefined;
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{EState}),
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

    pub fn update(_: UpdateEvent) void {
        var next = entities.nextSetBit(0);
        while (next) |i| {
            if (EState.byId(i)) |e| processEntity(e);
            next = entities.nextSetBit(i + 1);
        }
    }

    inline fn processEntity(entity: *EState) void {
        var next = entity.state_engine.states.slots.nextSetBit(0);
        while (next) |i| {
            if (entity.state_engine.states.get(i)) |state| {
                if (entity.current_state) |cs| {
                    if (state == cs) {
                        next = entity.state_engine.states.slots.nextSetBit(i + 1);
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
            next = entity.state_engine.states.slots.nextSetBit(i + 1);
        }
    }
};
