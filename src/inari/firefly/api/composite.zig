const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;

const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const String = utils.String;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.Component.register(Composite, "Composite");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////////////////
//// Composite Component
//////////////////////////////////////////////////////////////////////////

/// Name of the owner composite. If this is set, task should get the
/// composite referenced to and add all created components as owner to the composite
//pub const OWNER_COMPOSITE_TASK_ATTRIBUTE = "OWNER_COMPOSITE";

pub const CompositeLifeCycle = enum {
    LOAD,
    ACTIVATE,
    DEACTIVATE,
    UNLOAD,
};

pub const CompositeTaskRef = struct {
    task_ref: ?Index = null,
    task_name: ?String = null,
    life_cycle: CompositeLifeCycle,
    attributes_id: ?Index = null,
};

pub const Composite = struct {
    pub const Component = api.Component.Mixin(Composite);
    pub const Naming = api.Component.NameMappingMixin(Composite);
    pub const Activation = api.Component.ActivationMixin(Composite);
    pub const Subscription = api.Component.SubscriptionMixin(Composite);
    pub const Subtypes = api.Component.SubTypingMixin(Composite);
    pub const Attributes = api.Component.AttributeMixin(Composite);
    pub const init_attributes = true;

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    attributes_id: ?Index = null,
    task_refs: utils.DynArray(CompositeTaskRef) = undefined,
    _loaded_components: utils.DynArray(api.CRef) = undefined,
    loaded: bool = false,

    pub fn construct(self: *Composite) void {
        self.task_refs = utils.DynArray(CompositeTaskRef).newWithRegisterSize(
            api.COMPONENT_ALLOC,
            5,
        );
        self._loaded_components = utils.DynArray(api.CRef).newWithRegisterSize(
            api.COMPONENT_ALLOC,
            3,
        );
    }

    pub fn destruct(self: *Composite) void {
        if (self.loaded)
            unload(self);

        var next = self.task_refs.slots.nextSetBit(0);
        while (next) |i| {
            next = self.task_refs.slots.nextSetBit(i + 1);
            if (self.task_refs.get(i)) |ref| {
                if (ref.attributes_id) |a_id|
                    api.Attributes.Component.dispose(a_id);
                ref.attributes_id = null;
            }
        }

        self.task_refs.deinit();
        self.task_refs = undefined;

        self._loaded_components.deinit();
        self._loaded_components = undefined;
    }

    pub fn createForSubType(SubType: anytype) *Composite {
        return Component.newForSubType(.{ .name = SubType.name });
    }

    pub fn addTask(composite_id: Index, task: api.Task, life_cycle: CompositeLifeCycle) void {
        _ = Component.byId(composite_id).withTask(task, life_cycle);
    }

    pub fn withTask(self: *Composite, task: api.Task, life_cycle: CompositeLifeCycle) *Composite {
        const _task = api.Task.new(task);
        _ = self.task_refs.add(CompositeTaskRef{
            .task_ref = _task.id,
            .task_name = _task.name,
            .life_cycle = life_cycle,
        });
        return self;
    }

    pub fn addTaskRef(composite_id: Index, task_ref: CompositeTaskRef) void {
        _ = Component.byId(composite_id).withTaskRef(task_ref);
    }

    pub fn withTaskRef(self: *Composite, task_ref: CompositeTaskRef) *Composite {
        if (task_ref.task_ref == null and task_ref.task_name == null)
            utils.panic(api.ALLOC, "CompositeTaskRef has whether id nor name. {any}", .{task_ref});

        _ = self.task_refs.add(task_ref);
        return self;
    }

    pub fn addComponentReference(self: *Composite, ref: ?api.CRef) void {
        if (ref) |r| _ = self._loaded_components.add(r);
    }

    pub fn load(self: *Composite) void {
        defer self.loaded = true;
        if (self.loaded)
            return;

        self.runTasks(.LOAD);
    }

    pub fn unload(self: *Composite) void {
        defer self.loaded = false;
        if (!self.loaded)
            return;

        // first deactivate if still active
        Composite.Activation.deactivate(self.id);
        // run dispose tasks if defined
        self.runTasks(.UNLOAD);
        // dispose all owned references that still available
        var next = self._loaded_components.slots.nextSetBit(0);
        while (next) |i| {
            if (self._loaded_components.get(i)) |ref|
                if (ref.is_valid(ref.id))
                    if (ref.dispose) |d| d(ref.id);

            next = self._loaded_components.slots.nextSetBit(i + 1);
        }
        self._loaded_components.clear();
    }

    pub fn activation(self: *Composite, active: bool) void {
        self.runTasks(if (active) .ACTIVATE else .DEACTIVATE);
        // activate all references
        var next = self._loaded_components.slots.nextSetBit(0);
        while (next) |i| {
            if (self._loaded_components.get(i)) |ref| {
                if (ref.is_valid(ref.id))
                    if (ref.activation) |a|
                        a(ref.id, active);
            }

            next = self._loaded_components.slots.nextSetBit(i + 1);
        }
    }

    fn callRefCallback(c_ref: api.CRef, context: ?*api.CallContext) void {
        if (context) |c|
            _ = Composite.Component.byId(c.caller_id)._loaded_components.add(c_ref);
    }

    fn runTasks(self: *Composite, life_cycle: CompositeLifeCycle) void {
        var next = self.task_refs.slots.nextSetBit(0);
        while (next) |i| {
            next = self.task_refs.slots.nextSetBit(i + 1);
            const tr = self.task_refs.get(i).?;

            if (tr.life_cycle == life_cycle) {
                var ctx: api.CallContext = .{
                    .caller_id = self.id,
                    .caller_name = self.name,
                    .attributes_id = tr.attributes_id orelse self.attributes_id,
                    .c_ref_callback = callRefCallback,
                };

                const task_id = if (tr.task_name) |name|
                    api.Task.Naming.getId(name)
                else
                    tr.task_ref;

                if (task_id) |id| {
                    var task = api.Task.Component.byId(id);
                    const delete = task.run_once;
                    task.runWith(&ctx, true);
                    if (delete)
                        self.task_refs.delete(i);
                }
            }
        }
    }
};

pub fn CompositeMixin() type {
    return struct {
        pub const Attributes = Composite.Attributes;

        pub fn addTask(c_id: Index, task: api.Task, life_cycle: api.CompositeLifeCycle, attributes_id: ?Index) void {
            addTaskById(c_id, api.Task.Component.new(task), life_cycle, attributes_id);
        }

        pub fn addTaskById(c_id: Index, task_id: Index, life_cycle: api.CompositeLifeCycle, attributes_id: ?Index) void {
            checkInCreationState(c_id);
            _ = api.Composite.Component.byId(c_id).withTaskRef(.{
                .task_ref = task_id,
                .life_cycle = life_cycle,
                .attributes_id = attributes_id,
            });
        }

        pub fn addTaskByName(c_id: Index, task_name: String, life_cycle: api.CompositeLifeCycle, attributes_id: ?Index) void {
            checkInCreationState(c_id);

            _ = api.Composite.Component.byId(c_id).withTaskRef(.{
                .task_name = task_name,
                .life_cycle = life_cycle,
                .attributes_id = attributes_id,
            });
        }

        fn checkInCreationState(c_id: Index) void {
            const composite = api.Composite.Component.byId(c_id);
            if (composite.loaded)
                utils.panic(api.ALLOC, "Composite is already loaded: {?s}", .{composite.name});
        }
    };
}
