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

    api.Component.registerComponent(Composite);
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
pub const OWNER_COMPOSITE_TASK_ATTRIBUTE = "OWNER_COMPOSITE";

pub const CompositeLifeCycle = enum {
    LOAD,
    ACTIVATE,
    DEACTIVATE,
    DISPOSE,
};

pub const CompositeTaskRef = struct {
    task_ref: ?Index = null,
    task_name: ?String = null,
    life_cycle: CompositeLifeCycle,
    attributes: ?Index = null,

    pub fn deinit(self: *CompositeTaskRef) void {
        if (self.attributes) |a_id|
            api.Attributes.disposeById(a_id);
        self.attributes = null;
    }
};

pub const Composite = struct {
    pub usingnamespace api.Component.Trait(Composite, .{
        .name = "Composite",
        .subtypes = true,
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    loaded: bool = false,

    attributes: ?Index = undefined,
    task_refs: utils.DynArray(CompositeTaskRef) = undefined,
    _loaded_components: utils.DynArray(api.CRef) = undefined,

    pub fn construct(self: *Composite) void {
        self.task_refs = utils.DynArray(CompositeTaskRef).newWithRegisterSize(
            api.COMPONENT_ALLOC,
            5,
        );
        self._loaded_components = utils.DynArray(api.CRef).newWithRegisterSize(
            api.COMPONENT_ALLOC,
            3,
        );

        self.attributes = api.Attributes.new(.{ .name = self.name }).id;
    }

    pub fn destruct(self: *Composite) void {
        var next = self.task_refs.slots.nextSetBit(0);
        while (next) |i| {
            next = self.task_refs.slots.nextSetBit(i + 1);
            if (self.task_refs.get(i)) |o|
                o.deinit();
        }

        self.task_refs.deinit();
        self.task_refs = undefined;
        self._loaded_components.deinit();
        self._loaded_components = undefined;
        if (self.attributes) |a_id| {
            api.Attributes.disposeById(a_id);
            self.attributes = null;
        }
    }

    pub fn withTask(
        self: *Composite,
        task: api.Task,
        life_cycle: CompositeLifeCycle,
        attributes: anytype,
    ) *Composite {
        const _task = api.Task.new(task);
        _ = self.task_refs.add(CompositeTaskRef{
            .task_ref = _task.id,
            .task_name = _task.name,
            .life_cycle = life_cycle,
            .attributes = api.Attributes.ofGetId(attributes),
        });
        return self;
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

    pub fn dispose(self: *Composite) void {
        defer self.loaded = false;
        if (!self.loaded)
            return;

        // first deactivate if still active
        Composite.activateById(self.id, false);
        // run dispose tasks if defined
        self.runTasks(.DISPOSE);
        // dispose all owned references that still available
        var next = self._loaded_components.slots.nextSetBit(0);
        while (next) |i| {
            if (self._loaded_components.get(i)) |ref|
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
                if (ref.activation) |a|
                    a(ref.id, active);
            }

            next = self._loaded_components.slots.nextSetBit(i + 1);
        }
    }

    fn callRefCallback(c_ref: api.CRef, context: ?*api.CallContext) void {
        if (context) |c|
            _ = Composite.byId(c.caller_id)._loaded_components.add(c_ref);
    }

    fn runTasks(self: *Composite, life_cycle: CompositeLifeCycle) void {
        var next = self.task_refs.slots.nextSetBit(0);
        while (next) |i| {
            next = self.task_refs.slots.nextSetBit(i + 1);
            const tr = self.task_refs.get(i).?;

            if (tr.life_cycle == life_cycle)
                if (tr.task_ref) |id|
                    api.Task.runTaskByIdWith(
                        id,
                        .{
                            .caller_id = self.id,
                            .caller_name = self.name,
                            .attributes_id = tr.attributes,
                            .c_ref_callback = callRefCallback,
                        },
                    )
                else if (tr.task_name) |name|
                    api.Task.runTaskByNameWith(
                        name,
                        .{
                            .caller_id = self.id,
                            .caller_name = self.name,
                            .attributes_id = tr.attributes,
                            .c_ref_callback = callRefCallback,
                        },
                    );
        }
    }
};

pub fn CompositeTrait(comptime T: type) type {
    return struct {
        pub usingnamespace firefly.api.SubTypeTrait(Composite, T);

        pub fn withTask(
            self: *T,
            task: api.Task,
            life_cycle: CompositeLifeCycle,
            attributes: anytype,
        ) *T {
            checkInCreationState(self);

            _ = self.addTaskById(
                api.Task.new(task).id,
                life_cycle,
                attributes,
            );

            return self;
        }

        pub fn addTaskById(
            self: *T,
            task_id: Index,
            life_cycle: api.CompositeLifeCycle,
            attributes: anytype,
        ) *T {
            checkInCreationState(self);

            const attrs = api.Attributes.of(attributes, null);
            if (attrs) |a| {
                a.set(OWNER_COMPOSITE_TASK_ATTRIBUTE, self.name);
                _ = api.Composite.byId(self.id).withTaskRef(.{
                    .task_ref = task_id,
                    .life_cycle = life_cycle,
                    .attributes = a.id,
                });
            } else {
                _ = api.Composite.byId(self.id).withTaskRef(.{
                    .task_ref = task_id,
                    .life_cycle = life_cycle,
                });
            }

            return self;
        }

        pub fn addTaskByName(
            self: *T,
            task_name: String,
            life_cycle: api.CompositeLifeCycle,
            attributes: anytype,
        ) *T {
            checkInCreationState(self);

            const attrs = api.Attributes.of(attributes, null);
            if (attrs) |a| {
                a.set(OWNER_COMPOSITE_TASK_ATTRIBUTE, self.name);
                _ = api.Composite.byId(self.id).withTaskRef(.{
                    .task_name = task_name,
                    .life_cycle = life_cycle,
                    .attributes = a.id,
                });
            } else {
                _ = api.Composite.byId(self.id).withTaskRef(.{
                    .task_name = task_name,
                    .life_cycle = life_cycle,
                });
            }

            return self;
        }

        fn checkInCreationState(self: *T) void {
            if (Composite.byName(self.name)) |composite|
                if (composite.loaded)
                    utils.panic(api.ALLOC, "Composite is already loaded: {s}", .{self.name});
        }
    };
}
