const std = @import("std");
const firefly = @import("../firefly.zig");

const GroupAspect = firefly.api.GroupAspect;
const GroupKind = firefly.api.GroupKind;
const GroupAspectGroup = firefly.api.GroupAspectGroup;
const DynArray = firefly.utils.DynArray;
const Attributes = firefly.api.Attributes;
const ComponentAspect = firefly.api.ComponentAspect;
const UpdateEvent = firefly.api.UpdateEvent;
const Component = firefly.api.Component;
const String = firefly.utils.String;
const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(CCondition);
    Component.registerComponent(Task);
    Component.registerComponent(Trigger);
    Component.registerComponent(ComponentControl);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////////////////
//// Condition Component
//////////////////////////////////////////////////////////////////////////

pub const ConditionFunction = *const fn (?Index, ?Attributes) bool;
pub const ConditionType = enum { f, f_and, f_or, f_not };
pub const Condition = union(ConditionType) {
    f: ConditionFunction,
    f_and: CRef2,
    f_or: CRef2,
    f_not: CRef1,

    fn check(self: Condition, component_id: ?Index, attributes: ?Attributes) bool {
        return switch (self) {
            .f => self.f(component_id, attributes),
            .f_and => CCondition.byId(self.f_and.left_ref).condition.check(component_id, attributes) and
                CCondition.byId(self.f_and.right_ref).condition.check(component_id, attributes),
            .f_or => CCondition.byId(self.f_or.left_ref).condition.check(component_id, attributes) or
                CCondition.byId(self.f_or.right_ref).condition.check(component_id, attributes),
            .f_not => !CCondition.byId(self.f_not.f_ref).condition.check(component_id, attributes),
        };
    }
};

pub const CRef2 = struct {
    left_ref: Index,
    right_ref: Index,
};

pub const CRef1 = struct {
    f_ref: Index,
};

pub const CCondition = struct {
    pub usingnamespace Component.Trait(
        @This(),
        .{
            .name = "CCondition",
            .subscription = false,
            .activation = false,
        },
    );

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    condition: Condition,

    pub fn check(self: *CCondition, component_id: ?Index, attributes: ?Attributes) bool {
        return self.condition.check(component_id, attributes);
    }

    pub fn newANDById(name: String, c1_id: Index, c2_id: Index) *CCondition {
        return CCondition.new(.{
            .name = name,
            .condition = .{ .f_and = .{
                .left_ref = c1_id,
                .right_ref = c2_id,
            } },
        });
    }

    pub fn newANDByName(name: String, c1_name: String, c2_name: String) *CCondition {
        return CCondition.new(.{
            .name = name,
            .condition = .{ .f_and = .{
                .left_ref = CCondition.idByName(c1_name).?,
                .right_ref = CCondition.idByName(c2_name).?,
            } },
        });
    }

    pub fn newORById(name: String, c1_id: Index, c2_id: Index) *CCondition {
        return CCondition.new(.{
            .name = name,
            .condition = .{ .f_or = .{
                .left_ref = c1_id,
                .right_ref = c2_id,
            } },
        });
    }

    pub fn newORByName(name: String, c1_name: String, c2_name: String) *CCondition {
        return CCondition.new(.{
            .name = name,
            .condition = .{ .f_or = .{
                .left_ref = CCondition.idByName(c1_name).?,
                .right_ref = CCondition.idByName(c2_name).?,
            } },
        });
    }

    pub fn checkById(c_id: Index, component_id: ?Index, attributes: ?Attributes) bool {
        return CCondition.byId(c_id).check(component_id, attributes);
    }

    pub fn checkByName(c_name: String, component_id: ?Index, attributes: ?Attributes) bool {
        if (CCondition.byName(c_name)) |cc|
            return cc.check(component_id, attributes);
        return false;
    }
};

//////////////////////////////////////////////////////////////////////////
//// Action, Task and Trigger
//////////////////////////////////////////////////////////////////////////

pub const ActionResult = enum {
    Success,
    Running,
    Failed,
};

pub const ActionFunction = *const fn (Index) ActionResult;
pub const ActionCallback = *const fn (Index, ActionResult) void;
pub const TaskFunction = *const fn (?Index, ?*Attributes) void;
pub const TaskCallback = *const fn (Index) void;

pub const Task = struct {
    pub usingnamespace Component.Trait(Task, .{
        .name = "Task",
        .activation = false,
    });

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

    pub fn runWith(self: *Task, id: ?Index, attributes: ?Attributes) void {
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

    pub fn runTaskById(task_id: Index, component_id: ?Index, attributes: ?Attributes) void {
        Task.byId(task_id).runWith(component_id, attributes);
    }

    pub fn runTaskByName(task_name: String, component_id: ?Index, attributes: ?Attributes) void {
        if (Task.byName(task_name)) |t| t.runWith(component_id, attributes);
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

        self.function(id, if (attrs) |*a| a else null);

        if (self.callback) |c|
            c(self.id);

        if (attrs) |*a|
            a.deinit();
    }
};

pub const Trigger = struct {
    pub usingnamespace Component.Trait(Trigger, .{
        .name = "Trigger",
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    component_ref: ?Index,
    task_ref: Index,
    condition_ref: Index,
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
            const trigger = Trigger.byId(i);
            if (CCondition.byId(trigger.condition_ref).check(trigger.component_ref, trigger.attributes))
                Task.byId(trigger.task_ref).runWith(trigger.component_ref, trigger.attributes);

            next = Trigger.nextActiveId(i + 1);
        }
    }
};

//////////////////////////////////////////////////////////////////////////
//// Component Control
//////////////////////////////////////////////////////////////////////////

pub const ComponentControl = struct {
    pub usingnamespace Component.Trait(ComponentControl, .{
        .name = "ComponentControl",
        .grouping = true,
        .subscription = false,
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    groups: ?GroupKind = null,

    component_type: ComponentAspect,
    control: *const fn (Index, Index) void,

    dispose: ?*const fn (Index) void = null,

    pub fn destruct(self: *ComponentControl) void {
        if (self.dispose) |df| df(self.id);
        self.groups = null;
    }

    pub fn update(control_id: Index, c_id: Index) void {
        const Self = @This();
        if (Self.isActiveById(control_id))
            Self.byId(control_id).control(c_id, control_id);
    }
};

pub fn ComponentControlType(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects component control type is a struct.");
        if (!@hasDecl(T, "update"))
            @compileError("Expects component control type to have function 'update(Index)'");
        if (!@hasField(T, "name"))
            @compileError("Expects component control type to have field 'name: String'");
        if (!@hasDecl(T, "component_type"))
            @compileError("Expects component control type to have var 'component_type: ComponentAspect'");
    }

    return struct {
        const Self = @This();

        var register: DynArray(T) = undefined;

        pub fn init() void {
            register = DynArray(T).new(firefly.api.COMPONENT_ALLOC);
        }

        pub fn deinit() void {
            register.deinit();
        }

        pub fn stateByControlId(id: Index) ?*T {
            return register.get(id);
        }

        pub fn new(control_type: T) *ComponentControl {
            const control = ComponentControl.new(.{
                .name = control_type.name,
                .control = T.update,
                .component_type = firefly.api.ComponentAspectGroup.getAspectFromAnytype(T.component_type).?.*,
                .dispose = dispose,
            });

            _ = register.set(control_type, control.id);

            return control;
        }

        fn dispose(id: Index) void {
            register.delete(id);
        }
    };
}
