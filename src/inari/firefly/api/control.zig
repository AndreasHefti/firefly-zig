const std = @import("std");
const firefly = @import("../firefly.zig");

const Attributes = firefly.api.Attributes;
const System = firefly.api.System;
const EComponent = firefly.api.EComponent;
const EComponentAspectGroup = firefly.api.EComponentAspectGroup;
const Entity = firefly.api.Entity;
const EntityCondition = firefly.api.EntityCondition;
const UpdateEvent = firefly.api.UpdateEvent;
const BitSet = firefly.utils.BitSet;
const Component = firefly.api.Component;
const String = firefly.utils.String;
const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(Task);
    Component.registerComponent(Trigger);
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
//// Action, Task and Trigger
//////////////////////////////////////////////////////////////////////////

// A condition that takes a component identifier as input
pub const CCondition = *const fn (Index, ?Attributes) bool;

pub const ActionResult = enum {
    Success,
    Running,
    Failed,
};

pub const ActionFunction = *const fn (Index) ActionResult;
pub const TaskFunction = *const fn (?Index, ?Attributes) void;
pub const TaskCallback = *const fn (Index) void;

pub const Task = struct {
    pub usingnamespace Component.Trait(Task, .{ .name = "Task", .activation = false, .processing = false });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    run_once: bool = false,
    blocking: bool = true,

    function: TaskFunction,
    attributes: ?Attributes = null,
    callback: ?TaskCallback = null,

    pub fn destruct(self: *Task) void {
        if (self.attributes) |*attr|
            attr.deinit();
        self.attributes = null;
    }

    pub fn run(self: *Task) void {
        defer {
            if (self.run_once)
                Task.disposeById(self.id);
        }

        if (self.blocking) {
            self._run(null, null);
        } else {
            _ = std.Thread.spawn(.{}, _run, .{ self, null, null }) catch unreachable;
        }
    }

    pub fn runWith(self: *Task, id: Index, attributes: ?Attributes) void {
        defer {
            if (self.run_once)
                Task.disposeById(self.id);
        }

        if (self.blocking) {
            self._run(id, attributes);
        } else {
            _ = std.Thread.spawn(.{}, _run, .{ self, id, attributes }) catch unreachable;
        }
    }

    fn _run(self: *Task, id: ?Index, attrs1: ?Attributes) void {
        var attrs: ?Attributes = null;
        if (self.attributes) |*a| {
            attrs = Attributes.new();
            attrs.?.setAll(a);
        }
        if (attrs1) |*a| {
            if (attrs == null)
                attrs = Attributes.new();
            attrs.?.setAll(a);
        }

        self.function(id, attrs);

        if (self.callback) |c|
            c(self.id);

        if (attrs) |*a|
            a.deinit();
    }
};

pub const Trigger = struct {
    pub usingnamespace Component.Trait(Trigger, .{ .name = "Trigger", .processing = false });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    component_ref: Index = UNDEF_INDEX,
    task_ref: Index = UNDEF_INDEX,
    condition: CCondition,
    attributes: ?Attributes = null,

    pub fn componentTypeInit() !void {
        firefly.api.subscribeUpdate(update);
    }

    pub fn componentTypeDeinit() void {
        firefly.api.unsubscribeUpdate(update);
    }

    pub fn destruct(self: *Trigger) void {
        if (self.attributes) |*attr|
            attr.deinit();
        self.attributes = null;
    }

    fn update(_: UpdateEvent) void {
        var next = Trigger.nextActiveId(0);
        while (next) |i| {
            var trigger = Trigger.byId(i);
            if (trigger.condition(trigger.id, trigger.attributes))
                Task.byId(trigger.task_ref).runWith(trigger.component_ref, trigger.attributes);

            next = Trigger.nextActiveId(i + 1);
        }
    }
};

//////////////////////////////////////////////////////////////////////////
//// Component and Entity Control
//////////////////////////////////////////////////////////////////////////

pub fn ControlNode(comptime T: type) type {
    return struct {
        pub const Control = *const fn (*T) void;
        const Self = @This();

        control: Control,
        next: ?*ControlNode(T) = null,

        pub fn new(control: Control) *Self {
            var result = firefly.api.COMPONENT_ALLOC.create(Self) catch unreachable;
            result.control = control;
            result.next = null;
            return result;
        }

        pub fn update(self: *Self, component: *T) void {
            self.control(component);
            if (self.next) |n| n.update(component);
        }

        pub fn add(self: *Self, control: Control) void {
            if (self.next) |n|
                n.add(control)
            else {
                self.next = firefly.api.COMPONENT_ALLOC.create(Self) catch unreachable;
                self.next.?.control = control;
                self.next.?.next = null;
            }
        }

        fn deinit(self: *Self) void {
            if (self.next) |n|
                n.deinit();
            firefly.api.COMPONENT_ALLOC.destroy(self);
        }
    };
}

//////////////////////////////////////////////////////////////////////////
//// Entity Control
//////////////////////////////////////////////////////////////////////////

pub const EControl = struct {
    pub usingnamespace EComponent.Trait(@This(), "EControl");

    id: Index = UNDEF_INDEX,
    controls: ?*ControlNode(Entity) = null,

    fn update(self: *EControl, id: Index) void {
        if (self.controls) |c| c.update(Entity.byId(id));
    }

    pub fn withControl(self: *EControl, control: ControlNode(Entity).Control) *EControl {
        addControl(self, control);
        return self;
    }

    pub fn withControlAnd(self: *EControl, control: ControlNode(Entity).Control) *Entity {
        addControl(self, control);
        return Entity.byId(self.id);
    }

    pub fn destruct(self: *EControl) void {
        if (self.controls) |c|
            c.deinit();

        self.controls = null;
    }

    fn addControl(self: *EControl, control: ControlNode(Entity).Control) void {
        if (self.controls) |c|
            c.add(control)
        else
            self.controls = ControlNode(Entity).new(control);
    }
};

const EntityControlSystem = struct {
    pub var entity_condition: EntityCondition = undefined;

    var entities: BitSet = undefined;

    pub fn systemInit() void {
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{EControl}),
        };
        entities = BitSet.new(firefly.api.COMPONENT_ALLOC) catch unreachable;
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
