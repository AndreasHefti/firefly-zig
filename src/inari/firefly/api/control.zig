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

pub const Control = *const fn (Index) void;

pub const ControlNode = struct {
    control: Control,
    next: ?*ControlNode = null,

    pub fn update(self: *ControlNode, id: Index) void {
        self.control(id);
        if (self.next) |n| n.update(id);
    }

    pub fn add(self: *ControlNode, control: Control) void {
        if (self.next) |n|
            n.add(control)
        else {
            self.next = api.COMPONENT_ALLOC.create(ControlNode) catch unreachable;
            self.next.?.control = control;
            self.next.?.next = null;
        }
    }

    fn deinit(self: *ControlNode) void {
        if (self.next) |n|
            n.deinit();
        api.COMPONENT_ALLOC.destroy(self);
    }
};

//////////////////////////////////////////////////////////////////////////
//// Entity Control
//////////////////////////////////////////////////////////////////////////

pub const EControl = struct {
    pub usingnamespace EComponent.Trait(@This(), "EControl");

    id: Index = UNDEF_INDEX,
    controls: ?*ControlNode = null,

    fn update(self: *EControl, id: Index) void {
        if (self.controls) |c| c.update(id);
    }

    pub fn withControl(self: *EControl, control: Control) *EControl {
        addControl(self, control);
        return self;
    }

    pub fn withControlAnd(self: *EControl, control: Control) *Entity {
        addControl(self, control);
        return Entity.byId(self.id);
    }

    pub fn destruct(self: *EControl) void {
        if (self.controls) |c|
            c.deinit();

        self.controls = null;
    }

    fn addControl(self: *EControl, control: Control) void {
        if (self.controls) |c|
            c.add(control)
        else {
            self.controls = api.COMPONENT_ALLOC.create(ControlNode) catch unreachable;
            self.controls.?.control = control;
            self.controls.?.next = null;
        }
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
            if (EControl.byId(i)) |ec|
                ec.update(i);

            next = entities.nextSetBit(i + 1);
        }
    }
};
