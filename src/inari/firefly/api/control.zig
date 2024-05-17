const std = @import("std");
const firefly = @import("../firefly.zig");

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
//// Component Control
//////////////////////////////////////////////////////////////////////////

pub const ComponentControl = struct {
    pub usingnamespace Component.Trait(ComponentControl, .{
        .name = "ComponentControl",
        .processing = false,
        .subscription = false,
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    component_type: ComponentAspect,
    operation: *const fn (Index) void,

    dispose: ?*const fn (Index) void = null,

    pub fn update(controlId: Index, c_id: Index) void {
        const Self = @This();
        if (Self.isActiveById(controlId))
            Self.byId(controlId).operation(c_id);
    }

    pub fn destruct(self: *ComponentControl) void {
        if (self.dispose) |df| df(self.id);
    }
};

pub fn ComponentControlType(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects component control type is a struct.");
        if (!@hasDecl(T, "update"))
            @compileError("Expects component control type to have function 'update(Index)'");
        if (!@hasField(T, "name"))
            @compileError("Expects component control type to have field 'name: ?String'");
        if (!@hasDecl(T, "component_type"))
            @compileError("Expects component control type to have field 'component_type: ComponentAspect'");
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

        pub fn byId(id: Index) ?*T {
            return register.get(id);
        }

        pub fn new(control_type: T) Index {
            const control_id = ComponentControl.new(.{
                .name = control_type.name,
                .operation = T.update,
                .component_type = firefly.api.ComponentAspectGroup.getAspectFromAnytype(T.component_type),
                .dispose = dispose,
            });

            register.set(control_type, control_id);

            return control_id;
        }

        fn dispose(id: Index) void {
            register.delete(id);
        }
    };
}
