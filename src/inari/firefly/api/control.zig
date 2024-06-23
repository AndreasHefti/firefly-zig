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

    api.Component.registerComponent(CCondition);
    api.Component.registerComponent(Task);
    api.Component.registerComponent(Trigger);
    api.Component.registerComponent(ComponentControl);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////////////////
//// CallContext
//////////////////////////////////////////////////////////////////////////

pub const CallContext = struct {
    parent_id: Index,
    caller_id: ?Index,
    attributes: ?api.Attributes = undefined,

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
//// Condition Component
//////////////////////////////////////////////////////////////////////////

pub const ConditionFunction = *const fn (CallContext) bool;
pub const ConditionType = enum { f, f_and, f_or, f_not };
pub const Condition = union(ConditionType) {
    f: ConditionFunction,
    f_and: CRef2,
    f_or: CRef2,
    f_not: CRef1,

    fn check(self: Condition, context: CallContext) bool {
        return switch (self) {
            .f => self.f(context),
            .f_and => CCondition.byId(self.f_and.left_ref).condition.check(context) and
                CCondition.byId(self.f_and.right_ref).condition.check(context),
            .f_or => CCondition.byId(self.f_or.left_ref).condition.check(context) or
                CCondition.byId(self.f_or.right_ref).condition.check(context),
            .f_not => !CCondition.byId(self.f_not.f_ref).condition.check(context),
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
    pub usingnamespace api.Component.Trait(
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
    context: CallContext = undefined,

    pub fn construct(self: *CCondition) void {
        self.context = .{ .parent_id = self.id };
    }

    pub fn destruct(self: *CCondition) void {
        self.context.deinit();
    }

    pub fn check(self: *CCondition, caller_id: Index) bool {
        self.context.caller_id = caller_id;
        return self.condition.check(self.context);
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

    pub fn checkById(c_id: Index, caller_id: Index) bool {
        return CCondition.byId(c_id).check(caller_id);
    }

    pub fn checkByName(c_name: String, caller_id: Index) bool {
        if (CCondition.byName(c_name)) |cc|
            return cc.check(caller_id);
        return false;
    }
};

//////////////////////////////////////////////////////////////////////////
//// Component Control
//////////////////////////////////////////////////////////////////////////

pub const ControlFunction = *const fn (CallContext) void;
pub const ControlDispose = *const fn (Index) void;

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

    control: ControlFunction,
    dispose: ?ControlDispose = null,
    attributes: ?api.Attributes = null,

    pub fn destruct(self: *ComponentControl) void {
        if (self.dispose) |df| df(self.id);
        self.groups = null;
    }

    pub fn update(control_id: Index, c_id: Index) void {
        const c = ComponentControl.byId(control_id);
        c.control(.{
            .parent_id = control_id,
            .caller_id = c_id,
            .attributes = c.attributes,
        });
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

        var register: utils.DynArray(T) = undefined;

        pub fn init() void {
            register = utils.DynArray(T).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 20);
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
        attributes: ?api.Attributes,
    ) void {
        defer {
            if (self.run_once)
                Task.disposeById(self.id);
        }

        if (self.blocking) {
            self._run(caller_id, attributes);
        } else {
            _ = std.Thread.spawn(.{}, _run, .{ self, caller_id, attributes }) catch unreachable;
        }
    }

    pub fn runTaskById(task_id: Index) void {
        Task.byId(task_id).runWith(null, null);
    }

    pub fn runTaskByIdWith(task_id: Index, caller_id: ?Index, attributes: ?api.Attributes) void {
        Task.byId(task_id).runWith(caller_id, attributes);
    }
    pub fn runTaskByName(task_name: String) void {
        if (Task.byName(task_name)) |t| t.runWith(null, null);
    }

    pub fn runTaskByNameWith(task_name: String, caller_id: ?Index, attributes: ?api.Attributes) void {
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
    condition_ref: Index,
    attributes: ?api.Attributes = null,

    pub fn componentTypeInit() !void {
        firefly.api.subscribeUpdate(update);
    }

    pub fn componentTypeDeinit() void {
        firefly.api.unsubscribeUpdate(update);
    }

    pub fn destruct(self: *Trigger) void {
        if (self.attributes) |*a| a.deinit();
        self.attributes = undefined;
    }

    fn update(_: api.UpdateEvent) void {
        var next = Trigger.nextActiveId(0);
        while (next) |i| {
            const trigger = Trigger.byId(i);
            if (CCondition.byId(trigger.condition_ref).check(trigger.id))
                Task.byId(trigger.task_ref).runWith(trigger.id, trigger.attributes);

            next = Trigger.nextActiveId(i + 1);
        }
    }
};
