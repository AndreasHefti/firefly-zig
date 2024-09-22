// const std = @import("std");
// const firefly = @import("../firefly.zig");

// const System = firefly.api.System;
// const UpdateScheduler = firefly.api.UpdateScheduler;
// const EComponent = firefly.api.EComponent;
// const EntityTypeCondition = firefly.api.EntityTypeCondition;
// const EComponentAspectGroup = firefly.api.EComponentAspectGroup;
// const UpdateEvent = firefly.api.UpdateEvent;
// const BitSet = firefly.utils.BitSet;
// const DynArray = firefly.utils.DynArray;
// const Component = firefly.api.Component;
// const String = firefly.utils.String;
// const Index = firefly.utils.Index;
// const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

// //////////////////////////////////////////////////////////////
// //// state init
// //////////////////////////////////////////////////////////////

// var initialized = false;

// pub fn init() void {
//     defer initialized = true;
//     if (initialized)
//         return;

//     Component.registerComponent(StateEngine);
//     Component.registerComponent(EntityStateEngine);
//     EComponent.registerEntityComponent(EState);

//     System(StateSystem).createSystem(
//         firefly.Engine.CoreSystems.StateSystem.name,
//         "Updates all active StateEngine components, and change state on conditions",
//         false,
//     );
//     System(EntityStateSystem).createSystem(
//         firefly.Engine.CoreSystems.EntityStateSystem.name,
//         "Updates all active Entities with EState components, and change state on conditions",
//         false,
//     );
// }

// pub fn deinit() void {
//     defer initialized = false;
//     if (!initialized)
//         return;

//     System(StateSystem).disposeSystem();
//     System(EntityStateSystem).disposeSystem();
// }

// //////////////////////////////////////////////////////////////
// //// State API
// //////////////////////////////////////////////////////////////

// pub const State = struct {
//     id: Index = UNDEF_INDEX,
//     name: ?String,
//     condition: ?*const fn (Index, current: ?*State) bool = null,
//     init: ?*const fn (Index) void = null,
//     dispose: ?*const fn (Index) void = null,

//     pub fn equals(self: *State, other: ?*State) bool {
//         if (other) |s| {
//             return std.mem.eql(String, self.name, s.name);
//         }
//         return false;
//     }
// };

// //////////////////////////////////////////////////////////////
// //// State Engine Component
// //////////////////////////////////////////////////////////////

// pub const StateEngine = struct {
//     pub usingnamespace Component.Mixin(StateEngine, .{ .name = "StateEngine" });

//     id: Index = UNDEF_INDEX,
//     name: ?String,
//     states: DynArray(State) = undefined,
//     current_state: ?*State = null,
//     update_scheduler: ?*UpdateScheduler = null,

//     pub fn construct(self: *StateEngine) void {
//         self.states = DynArray(State).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10) catch unreachable;
//     }

//     pub fn destruct(self: *StateEngine) void {
//         self.states.deinit();
//     }

//     pub fn withState(self: *StateEngine, state: State) *StateEngine {
//         const s = self.states.addAndGet(state);
//         if (state.condition) |condition| {
//             if (condition(self.id, self.current_state))
//                 setNewState(self, s.ref);
//         }
//         return self;
//     }

//     pub fn setState(self: *StateEngine, name: String) void {
//         var next_state: ?*State = null;
//         var next = self.states.slots.nextSetBit(0);
//         while (next) |i| {
//             next_state = self.states.get(i).?;
//             if (next_state.hasName(name))
//                 break;
//             next_state = null;
//             next = self.states.slots.nextSetBit(i + 1);
//         }

//         if (next_state) |ns| setNewState(ns);
//     }

//     fn setNewState(self: *StateEngine, target: *State) void {
//         if (self.current_state) |cs|
//             if (cs.dispose) |df| df(self.id);

//         if (target.init) |in| in(self.id);
//         self.current_state = target;
//     }
// };

// //////////////////////////////////////////////////////////////
// //// EntityStateEngine
// //////////////////////////////////////////////////////////////

// pub const EntityStateEngine = struct {
//     pub usingnamespace Component.Mixin(EntityStateEngine, .{ .name = "EntityStateEngine" });

//     id: Index = UNDEF_INDEX,
//     name: ?String,
//     states: DynArray(State) = undefined,

//     pub fn construct(self: *EntityStateEngine) void {
//         self.states = DynArray(State).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
//     }

//     pub fn destruct(self: *EntityStateEngine) void {
//         self.states.deinit();
//     }

//     pub fn withState(self: *EntityStateEngine, state: State) *EntityStateEngine {
//         _ = self.states.add(state);
//         return self;
//     }

//     fn setNewState(entity: *EState, target: *State) void {
//         if (entity.current_state) |cs|
//             if (cs.dispose) |df| df(entity.id);

//         if (target.init) |in| in(entity.id);
//         entity.current_state = target;
//     }
// };

// pub const EState = struct {
//     pub usingnamespace EComponent.Mixin(@This(), "EState");

//     id: Index = UNDEF_INDEX,
//     state_engine: *EntityStateEngine,
//     current_state: ?*State = null,
// };

// //////////////////////////////////////////////////////////////
// //// State Systems
// //////////////////////////////////////////////////////////////

// const StateSystem = struct {
//     pub fn update(_: UpdateEvent) void {
//         StateEngine.processActive(processEngine);
//     }

//     fn processEngine(state_engine: *StateEngine) void {
//         if (state_engine.update_scheduler) |u| if (!u.needs_update)
//             return;

//         var next = state_engine.states.slots.nextSetBit(0);
//         while (next) |i| {
//             if (state_engine.states.get(i)) |state| {
//                 if (state.condition) |condition| {
//                     if (condition(state_engine.id, state_engine.current_state)) {
//                         state_engine.setNewState(state);
//                         return;
//                     }
//                 }
//             }
//             next = state_engine.states.slots.nextSetBit(i + 1);
//         }
//     }
// };

// const EntityStateSystem = struct {
//     pub var entity_condition: EntityTypeCondition = undefined;
//     var entities: BitSet = undefined;

//     pub fn systemInit() void {
//         entities = BitSet.new(firefly.api.COMPONENT_ALLOC);
//         entity_condition = EntityTypeCondition{
//             .accept_kind = EComponentAspectGroup.newKindOf(.{EState}),
//         };
//     }

//     pub fn systemDeinit() void {
//         entity_condition = undefined;
//         entities.deinit();
//         entities = undefined;
//     }

//     pub fn entityRegistration(id: Index, register: bool) void {
//         entities.setValue(id, register);
//     }

//     pub fn update(_: UpdateEvent) void {
//         var next = entities.nextSetBit(0);
//         while (next) |i| {
//             if (EState.byId(i)) |e| processEntity(e);
//             next = entities.nextSetBit(i + 1);
//         }
//     }

//     inline fn processEntity(entity: *EState) void {
//         var next = entity.state_engine.states.slots.nextSetBit(0);
//         while (next) |i| {
//             if (entity.state_engine.states.get(i)) |state| {
//                 if (entity.current_state) |cs| {
//                     if (state == cs) {
//                         next = entity.state_engine.states.slots.nextSetBit(i + 1);
//                         continue;
//                     }
//                 }

//                 if (state.condition) |condition| {
//                     if (condition(entity.id, entity.current_state)) {
//                         EntityStateEngine.setNewState(entity, state);
//                         return;
//                     }
//                 }
//             }
//             next = entity.state_engine.states.slots.nextSetBit(i + 1);
//         }
//     }
// };
