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

pub const CompositeObject = struct {
    task_ref: ?Index = null,
    task_name: ?String = null,
    life_cycle: CompositeLifeCycle,
    attributes: ?api.Attributes = null,
};

pub const Composite = struct {
    pub usingnamespace api.Component.Trait(Composite, .{
        .name = "Composite",
        .subtypes = true,
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    loaded: bool = false,

    attributes: api.Attributes = undefined,
    objects: utils.DynArray(CompositeObject) = undefined,
    _loaded_components: utils.DynArray(api.CReference) = undefined,

    pub fn construct(self: *Composite) void {
        self.objects = utils.DynArray(CompositeObject).newWithRegisterSize(
            api.COMPONENT_ALLOC,
            5,
        );
        self._loaded_components = utils.DynArray(api.CReference).newWithRegisterSize(
            api.COMPONENT_ALLOC,
            3,
        );

        self.attributes = api.Attributes.new();
    }

    pub fn destruct(self: *Composite) void {
        self.objects.deinit();
        self.objects = undefined;
        self._loaded_components.deinit();
        self._loaded_components = undefined;
        self.attributes.deinit();
        self.attributes = undefined;
    }

    pub fn setAttribute(self: *Composite, name: String, value: String) void {
        self.attributes.put(name, value) catch unreachable;
    }

    pub fn withTask(
        self: *Composite,
        task: api.Task,
        life_cycle: CompositeLifeCycle,
        attributes: ?api.Attributes,
    ) *Composite {
        const _task = api.Task.new(task);
        _ = self.objects.add(CompositeObject{
            .task_ref = _task.id,
            .task_name = _task.name,
            .life_cycle = life_cycle,
            .attributes = attributes,
        });
        return self;
    }

    pub fn withObject(self: *Composite, object: CompositeObject) *Composite {
        if (object.task_ref == null and object.task_name == null)
            utils.panic(api.ALLOC, "CompositeObject has whether id nor name. {any}", .{object});

        _ = self.objects.add(object);
        return self;
    }

    pub fn addComponentReference(self: *Composite, ref: ?api.CReference) void {
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

    fn runTasks(self: *Composite, life_cycle: CompositeLifeCycle) void {
        var next = self.objects.slots.nextSetBit(0);
        while (next) |i| {
            const tr = self.objects.get(i) orelse {
                next = self.objects.slots.nextSetBit(i + 1);
                continue;
            };

            if (tr.life_cycle == life_cycle)
                if (tr.task_ref) |id|
                    api.Task.runTaskByIdWith(id, self.id, tr.attributes)
                else if (tr.task_name) |name|
                    api.Task.runTaskByNameWith(name, self.id, tr.attributes);

            next = self.objects.slots.nextSetBit(i + 1);
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

            var attrs = api.Attributes.of(attributes);
            if (attrs) |*a| a.set(OWNER_COMPOSITE_TASK_ATTRIBUTE, self.name);

            _ = api.Composite.byId(self.id).withObject(.{
                .task_ref = task_id,
                .life_cycle = life_cycle,
                .attributes = attrs,
            });

            return self;
        }

        pub fn addTaskByName(
            self: *T,
            task_name: String,
            life_cycle: api.CompositeLifeCycle,
            attributes: anytype,
        ) *T {
            checkInCreationState(self);

            var attrs = api.Attributes.of(attributes);
            if (attrs) |*a| a.set(OWNER_COMPOSITE_TASK_ATTRIBUTE, self.name);

            _ = api.Composite.byId(self.id).withObject(.{
                .task_name = task_name,
                .life_cycle = life_cycle,
                .attributes = attrs,
            });

            return self;
        }

        fn checkInCreationState(self: *T) void {
            if (Composite.byName(self.name)) |composite|
                if (composite.loaded)
                    utils.panic(api.ALLOC, "Composite is already loaded: {s}", .{self.name});
        }
    };
}