const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;

const System = api.System;
const EComponent = api.EComponent;
const EComponentAspectGroup = api.EComponentAspectGroup;
const Entity = api.Entity;
const EntityCondition = api.EntityCondition;
const UpdateEvent = api.UpdateEvent;
const BitSet = utils.BitSet;
const DynArray = utils.DynArray;
const Component = api.Component;
const AspectGroup = utils.AspectGroup;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    EComponent.registerEntityComponent(EControl);
    System(EntityControlSystem).createSystem(
        firefly.Engine.CoreSystems.EntityControlSystem.name,
        "Processes active entities with EControl for every frame",
        false,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    System(EntityControlSystem).disposeSystem();
}

//////////////////////////////////////////////////////////////////////////
//// Entity Control
//////////////////////////////////////////////////////////////////////////

pub const Control = *const fn (Index) void;

pub const EControl = struct {
    pub usingnamespace EComponent.Trait(@This(), "EControl");

    id: Index = UNDEF_INDEX,
    controls: DynArray(Control) = undefined,

    pub fn construct(self: *EControl) void {
        self.controls = DynArray(Control).newWithRegisterSize(api.ENTITY_ALLOC, 5) catch unreachable;
    }

    pub fn withControl(self: *EControl, control: Control) *EControl {
        _ = self.controls.add(control);
        return self;
    }

    pub fn withControlAnd(self: *EControl, control: Control) *Entity {
        _ = self.controls.add(control);
        return Entity.byId(self.id);
    }

    pub fn destruct(self: *EControl) void {
        self.controls.deinit();
        self.controls = undefined;
    }
};

const EntityControlSystem = struct {
    pub var entity_condition: EntityCondition = undefined;

    var entities: BitSet = undefined;

    pub fn systemInit() void {
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{EControl}),
        };
        entities = BitSet.new(api.ALLOC) catch unreachable;
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
            if (EControl.byId(i)) |ec| {
                var next_e = ec.controls.slots.nextSetBit(0);
                while (next_e) |ci| {
                    if (ec.controls.get(ci)) |c| c.*(i);
                    next_e = ec.controls.slots.nextSetBit(i + 1);
                }
            }
            next = entities.nextSetBit(i + 1);
        }
    }
};
