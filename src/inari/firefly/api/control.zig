const std = @import("std");
const firefly = @import("../firefly.zig");

const api = firefly.api;

const GroupAspect = firefly.api.GroupAspect;
const GroupKind = firefly.api.GroupKind;
const GroupAspectGroup = firefly.api.GroupAspectGroup;
const DynArray = firefly.utils.DynArray;
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
//// Properties and CallAttributes
//////////////////////////////////////////////////////////////////////////

pub const Properties = std.StringHashMap(String);

pub const CallAttributes = struct {
    caller_id: ?Index = null,
    caller_name: ?String = null,
    c1_id: ?Index = null,
    c2_id: ?Index = null,
    c3_id: ?Index = null,
    properties: ?Properties = undefined,

    pub fn deinit(self: *CallAttributes) void {
        self.clearProperties();
        if (self.properties) |*p|
            p.deinit();
        self.properties = undefined;
    }

    pub fn clearProperties(self: *CallAttributes) void {
        if (self.properties) |*p| {
            var it = p.iterator();
            while (it.next()) |e| {
                api.ALLOC.free(e.key_ptr.*);
                api.ALLOC.free(e.value_ptr.*);
            }

            p.clearAndFree();
        }
    }

    pub fn setProperty(self: *CallAttributes, name: String, value: String) void {
        if (self.properties == null)
            self.properties = std.StringHashMap(String).init(api.ALLOC);
        // if existing, delete old first
        if (self.properties) |*p| {
            if (p.contains(name))
                self.deleteProperty(name);
            // add new with allocated key and value
            p.put(
                api.ALLOC.dupe(u8, name) catch unreachable,
                api.ALLOC.dupe(u8, value) catch unreachable,
            ) catch unreachable;
        }
    }

    pub fn setAllProperties(self: *CallAttributes, properties: Properties) void {
        var it = properties.iterator();
        while (it.next()) |e|
            self.setProperty(e.key_ptr.*, e.value_ptr.*);
    }

    pub fn getProperty(self: *CallAttributes, name: String) ?String {
        if (self.properties) |p| return p.get(name);
        return null;
    }

    pub fn deleteProperty(self: *CallAttributes, name: String) void {
        if (self.properties) |*p| {
            if (p.fetchRemove(name)) |kv| {
                api.ALLOC.free(kv.key);
                api.ALLOC.free(kv.value);
            }
        }
    }

    pub fn copyMerge(self: *CallAttributes, other: *const CallAttributes) CallAttributes {
        var copy = CallAttributes{
            .caller_id = self.caller_id,
            .caller_name = self.caller_name,
            .c1_id = other.c1_id,
            .c2_id = other.c2_id,
            .c3_id = other.c3_id,
        };

        if (self.properties) |p|
            copy.setAllProperties(p);
        if (other.properties) |p|
            copy.setAllProperties(p);

        return copy;
    }

    pub fn format(
        self: CallAttributes,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("CallAttributes[", .{});
        if (self.caller_id) |ci| try writer.print(" caller_id:{d}", .{ci});
        if (self.caller_name) |cn| try writer.print(" caller_name:{s}", .{cn});
        if (self.c1_id) |ci| try writer.print(" c1_id:{d}", .{ci});
        if (self.c2_id) |ci| try writer.print(" c2_id:{d}", .{ci});
        if (self.c3_id) |ci| try writer.print(" c3_id:{d}", .{ci});
        if (self.properties) |p| {
            try writer.print(" properties: ", .{});
            var i = p.iterator();
            while (i.next()) |e|
                try writer.print("{s}={s}, ", .{ e.key_ptr.*, e.value_ptr.* });
        }
        try writer.print(" ]", .{});
    }
};

//////////////////////////////////////////////////////////////////////////
//// Condition Component
//////////////////////////////////////////////////////////////////////////

pub const ConditionFunction = *const fn (?*CallAttributes) bool;
pub const ConditionType = enum { f, f_and, f_or, f_not };
pub const Condition = union(ConditionType) {
    f: ConditionFunction,
    f_and: CRef2,
    f_or: CRef2,
    f_not: CRef1,

    fn check(self: Condition, attributes: ?*CallAttributes) bool {
        return switch (self) {
            .f => self.f(attributes),
            .f_and => CCondition.byId(self.f_and.left_ref).condition.check(attributes) and
                CCondition.byId(self.f_and.right_ref).condition.check(attributes),
            .f_or => CCondition.byId(self.f_or.left_ref).condition.check(attributes) or
                CCondition.byId(self.f_or.right_ref).condition.check(attributes),
            .f_not => !CCondition.byId(self.f_not.f_ref).condition.check(attributes),
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

    pub fn check(self: *CCondition, attributes: ?*CallAttributes) bool {
        return self.condition.check(attributes);
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

    pub fn checkById(c_id: Index, attributes: ?*CallAttributes) bool {
        return CCondition.byId(c_id).check(attributes);
    }

    pub fn checkByName(c_name: String, attributes: ?*CallAttributes) bool {
        if (CCondition.byName(c_name)) |cc|
            return cc.check(attributes);
        return false;
    }
};

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
pub const TaskFunction = *const fn (*CallAttributes) void;
pub const TaskCallback = *const fn (*CallAttributes) void;

pub const GlobalTaskAttributes = struct {
    pub const CALLER_ID = "CALLER_ID";
    pub const CALLER_NAME = "CALLER_Name";

    pub const COMPONENT1_ID = "COMPONENT1_ID";
    pub const COMPONENT1_NAME = "COMPONENT1_NAME";
    pub const COMPONENT2_ID = "COMPONENT2_ID";
    pub const COMPONENT2_NAME = "COMPONENT2_NAME";
    pub const COMPONENT3_ID = "COMPONENT3_ID";
    pub const COMPONENT3_NAME = "COMPONENT3_NAME";
};

pub const Task = struct {
    pub usingnamespace Component.Trait(Task, .{
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

    attributes: CallAttributes = undefined,

    pub fn construct(self: *Task) void {
        self.attributes = CallAttributes{
            .caller_id = self.id,
            .caller_name = self.name,
        };
    }

    pub fn destruct(self: *Task) void {
        self.attributes.deinit();
        self.attributes = undefined;
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

    pub fn runWith(self: *Task, attributes: ?*CallAttributes) void {
        defer {
            if (self.run_once)
                Task.disposeById(self.id);
        }

        if (self.blocking) {
            self._run(attributes);
        } else {
            _ = std.Thread.spawn(.{}, _run, .{ self, attributes }) catch unreachable;
        }
    }

    pub fn runTaskById(task_id: Index, attributes: ?*CallAttributes) void {
        Task.byId(task_id).runWith(attributes);
    }

    pub fn runTaskByName(task_name: String, attributes: ?*CallAttributes) void {
        if (Task.byName(task_name)) |t| t.runWith(attributes);
    }

    fn _run(self: *Task, additional_attributes: ?*CallAttributes) void {
        if (additional_attributes) |aa| {
            var attrs = self.attributes.copyMerge(aa);
            defer attrs.deinit();
            self.function(&attrs);
            if (self.callback) |c|
                c(&attrs);
        } else {
            self.function(&self.attributes);
            if (self.callback) |c|
                c(&self.attributes);
        }
    }

    pub fn format(
        self: Task,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Task[ id:{d} name:{?s} run_once:{} blocking:{} callback:{} {?any} ], ",
            .{ self.id, self.name, self.run_once, self.blocking, self.callback != null, self.attributes },
        );
    }
};

pub const Trigger = struct {
    pub usingnamespace Component.Trait(Trigger, .{
        .name = "Trigger",
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    task_ref: Index,
    condition_ref: Index,
    attributes: CallAttributes = undefined,

    pub fn componentTypeInit() !void {
        firefly.api.subscribeUpdate(update);
    }

    pub fn componentTypeDeinit() void {
        firefly.api.unsubscribeUpdate(update);
    }

    pub fn construct(self: *Trigger) void {
        self.attributes = CallAttributes{
            .caller_id = self.id,
            .caller_name = self.name,
        };
    }

    pub fn withComponentRef1(self: *Trigger, id: Index) *Trigger {
        self.attributes.c1_id = id;
        return self;
    }
    pub fn withComponentRef2(self: *Trigger, id: Index) *Trigger {
        self.attributes.c2_id = id;
        return self;
    }
    pub fn withComponentRef3(self: *Trigger, id: Index) *Trigger {
        self.attributes.c3_id = id;
        return self;
    }

    pub fn destruct(self: *Trigger) void {
        self.attributes.deinit();
        self.attributes = undefined;
    }

    fn update(_: UpdateEvent) void {
        var next = Trigger.nextActiveId(0);
        while (next) |i| {
            const trigger = Trigger.byId(i);
            if (CCondition.byId(trigger.condition_ref).check(&trigger.attributes))
                Task.byId(trigger.task_ref).runWith(&trigger.attributes);

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
