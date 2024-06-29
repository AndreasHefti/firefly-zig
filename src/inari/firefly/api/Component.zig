const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;

const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const String = utils.String;

//////////////////////////////////////////////////////////////
//// Component global
//////////////////////////////////////////////////////////////
var INIT = false;
pub fn init() void {
    defer INIT = true;
    if (INIT)
        return;

    COMPONENT_INTERFACE_TABLE = utils.DynArray(ComponentTypeInterface).new(api.COMPONENT_ALLOC);
    registerComponent(Composite);
}

pub fn deinit() void {
    defer INIT = false;
    if (!INIT)
        return;

    // deinit all registered component pools
    var next = COMPONENT_INTERFACE_TABLE.slots.nextSetBit(0);
    while (next) |i| {
        if (COMPONENT_INTERFACE_TABLE.get(i)) |interface| {
            interface.deinit();
            COMPONENT_INTERFACE_TABLE.delete(i);
        }
        next = COMPONENT_INTERFACE_TABLE.slots.nextSetBit(i + 1);
    }
    COMPONENT_INTERFACE_TABLE.deinit();
    COMPONENT_INTERFACE_TABLE = undefined;
}

//////////////////////////////////////////////////////////////
//// Component API
//////////////////////////////////////////////////////////////
pub const ComponentAspectGroup = utils.AspectGroup(struct {
    pub const name = "ComponentType";
});
pub const ComponentKind = ComponentAspectGroup.Kind;
pub const ComponentAspect = *const ComponentAspectGroup.Aspect;

pub const GroupAspectGroup = utils.AspectGroup(struct {
    pub const name = "ComponentGroup";
});
pub const GroupKind = GroupAspectGroup.Kind;
pub const GroupAspect = *const GroupAspectGroup.Aspect;

const ComponentTypeInterface = struct {
    activate: *const fn (Index, bool) void,
    clear: *const fn (Index) void,
    deinit: api.Deinit,
    to_string: *const fn (*utils.StringBuffer) void,
};
var COMPONENT_INTERFACE_TABLE: utils.DynArray(ComponentTypeInterface) = undefined;

pub const Context = struct {
    name: String,
    activation: bool = true,
    name_mapping: bool = true,
    subscription: bool = true, // TODO make default false
    control: bool = false,
    grouping: bool = false,
};

pub fn registerComponent(comptime T: type) void {
    ComponentPool(T).init();
}

pub fn deinitComponent(comptime T: type) void {
    ComponentPool(T).deinit();
}

pub const CReference = struct {
    type: ComponentAspect,
    id: Index,
    activation: ?*const fn (Index, bool) void,
    dispose: ?*const fn (Index) void,
};

pub fn print(string_buffer: *utils.StringBuffer) void {
    string_buffer.print("\nComponents:", .{});
    var next = COMPONENT_INTERFACE_TABLE.slots.nextSetBit(0);
    while (next) |i| {
        if (COMPONENT_INTERFACE_TABLE.get(i)) |interface| interface.to_string(string_buffer);
        next = COMPONENT_INTERFACE_TABLE.slots.nextSetBit(i + 1);
    }
}

//////////////////////////////////////////////////////////////
//// Component Event Handling
//////////////////////////////////////////////////////////////

pub const ComponentListener = *const fn (ComponentEvent) void;
pub const ComponentEvent = struct {
    pub const Type = enum {
        /// Empty type used only for initialization
        NONE,
        /// Indicates that a certain component has been created
        CREATED,
        /// Indicates that a certain component has been activated
        ACTIVATED,
        /// Indicates that a certain component is going to be deactivated
        DEACTIVATING,
        /// Indicates that a certain component is going to be  disposed/deleted
        DISPOSING,
    };

    event_type: Type = .NONE,
    c_id: ?Index = null,
};

//////////////////////////////////////////////////////////////
//// Component Traits
//////////////////////////////////////////////////////////////

pub fn Trait(comptime T: type, comptime context: Context) type {
    return struct {

        // component type fields
        pub const COMPONENT_TYPE_NAME = context.name;
        pub const pool = ComponentPool(T);
        pub var aspect: ComponentAspect = undefined;

        pub fn isInitialized() bool {
            return pool._type_init;
        }

        pub fn count() usize {
            return pool.items.slots.count();
        }

        pub fn new(t: T) *T {
            return pool.register(t);
        }

        pub fn exists(id: Index) bool {
            return pool.items.exists(id);
        }

        pub fn byId(id: Index) *T {
            return pool.items.get(id).?;
        }

        pub fn referenceById(id: Index, owned: bool) ?CReference {
            _ = pool.items.get(id) orelse return null;
            return .{
                .type = aspect,
                .id = id,
                .activation = if (context.activation) T.activateById else null,
                .dispose = if (owned) disposeById else null,
            };
        }

        pub fn nextId(id: Index) ?Index {
            return pool.items.slots.nextSetBit(id);
        }

        pub fn disposeById(id: Index) void {
            pool.clear(id);
        }

        pub fn processBitSet(indices: *utils.BitSet, f: *const fn (*T) void) void {
            var next = indices.nextSetBit(0);
            while (next) |i| {
                if (pool.items.get(i)) |c| f(c);
                next = indices.nextSetBit(i + 1);
            }
        }

        // optional component type features
        const empty_struct = struct {};
        pub usingnamespace if (context.name_mapping) NameMappingTrait(T, @This(), context) else empty_struct;
        pub usingnamespace if (context.activation) ActivationTrait(T, @This(), context) else empty_struct;
        pub usingnamespace if (context.subscription) SubscriptionTrait(T, @This(), context) else empty_struct;
        pub usingnamespace if (context.control) ControlTrait(T, @This(), context) else empty_struct;
        pub usingnamespace if (context.grouping) GroupingTrait(T, @This(), context) else empty_struct;
    };
}

fn GroupingTrait(comptime T: type, comptime adapter: anytype, comptime _: Context) type {
    comptime {
        if (!@hasField(T, "groups"))
            @compileError("Expects component type to have field: groups: ?GroupKind");
    }
    return struct {
        pub fn getGroups(id: Index) ?GroupKind {
            const c = adapter.pool.items.get(id) orelse return null;
            return c.groups;
        }

        pub fn addToGroup(self: *T, group: GroupAspect) void {
            if (self.groups == null)
                self.groups = GroupAspectGroup.newKind(group)
            else
                self.groups.addAspect(group);
        }

        pub fn removeFromGroup(self: *T, group: GroupAspect) void {
            if (self.groups) |g|
                g.removeAspect(group);
        }

        pub fn isInGroup(self: *T, group: GroupAspect) bool {
            const g = self.groups orelse return false;
            return g.hasAspect(group);
        }

        fn processGroup(group: GroupAspect, f: *const fn (*T) void) void {
            var next = adapter.pool.items.slots.nextSetBit(0);
            while (next) |i| {
                const c = adapter.pool.items.get(i) orelse continue;
                const g = c.groups orelse continue;
                if (g.hasAspect(group))
                    f(c);

                next = adapter.pool.items.slots.nextSetBit(i + 1);
            }
        }
    };
}

fn SubscriptionTrait(comptime _: type, comptime adapter: anytype, comptime _: Context) type {
    return struct {
        pub fn subscribe(listener: ComponentListener) void {
            if (adapter.pool.eventDispatch) |*ed| ed.register(listener);
        }

        pub fn unsubscribe(listener: ComponentListener) void {
            if (adapter.pool.eventDispatch) |*ed| ed.unregister(listener);
        }
    };
}

fn NameMappingTrait(comptime T: type, comptime adapter: anytype, comptime context: Context) type {
    comptime {
        if (!@hasField(T, "name"))
            @compileError("Expects component type to have field: name: ?String");
    }

    return struct {
        pub fn existsName(name: String) bool {
            if (adapter.pool.name_mapping) |*nm| {
                return nm.contains(name);
            }
            return false;
        }

        pub fn idByName(name: String) ?Index {
            if (adapter.pool.name_mapping) |*nm|
                return nm.get(name);
            return null;
        }

        pub fn byName(name: String) ?*T {
            if (adapter.pool.name_mapping) |*nm| {
                if (nm.get(name)) |id|
                    return adapter.pool.items.get(id);
            }
            return null;
        }
        pub fn referenceByName(name: String, owned: bool) ?CReference {
            if (adapter.pool.name_mapping) |*nm| {
                if (nm.get(name)) |id| {
                    return .{
                        .type = T.aspect,
                        .id = id,
                        .activation = if (context.activation) T.activateById else null,
                        .dispose = if (owned) T.disposeById else null,
                    };
                }
            }
            return null;
        }
        pub fn disposeByName(name: String) void {
            if (adapter.pool.name_mapping) |*nm| {
                if (nm.get(name)) |id| adapter.pool.clear(id);
            }
        }
    };
}

fn ActivationTrait(comptime T: type, comptime adapter: anytype, comptime _: Context) type {
    return struct {
        pub fn activateById(id: Index, active: bool) void {
            adapter.pool.activate(id, active);
        }

        pub fn activateByName(name: String, active: bool) void {
            if (adapter.pool.name_mapping) |*nm| {
                if (nm.get(name)) |id| {
                    adapter.pool.activate(id, active);
                }
            }
        }
        pub fn isActiveById(index: Index) bool {
            if (adapter.pool.active_mapping) |am| return am.isSet(index);
            return false;
        }

        pub fn isActiveByName(name: String) bool {
            if (adapter.pool.name_mapping) |*nm| {
                if (nm.get(name)) |id| {
                    return adapter.pool.active_mapping.isSet(id);
                }
            }
            return false;
        }

        pub fn isActive(self: T) bool {
            return adapter.pool.active_mapping.?.isSet(self.id);
        }

        pub fn getWhenActiveById(id: Index) ?*T {
            if (adapter.pool.active_mapping) |*am| {
                if (am.isSet(id)) {
                    return adapter.pool.items.get(id).?;
                }
            }
            return null;
        }

        pub fn getWhenActiveByName(name: String) ?*T {
            if (adapter.pool.name_mapping) |*nm| {
                const id = nm.get(name) orelse return null;
                if (adapter.pool.active_mapping) |*am| {
                    if (am.isSet(id)) {
                        return adapter.pool.items.get(id).?;
                    }
                }
            }
            return null;
        }

        pub fn activeCount() usize {
            return adapter.pool.active_mapping.?.count();
        }

        pub fn nextActiveId(id: Index) ?Index {
            return adapter.pool.active_mapping.?.nextSetBit(id);
        }

        pub fn activate(self: *T) *T {
            if (self.id == UNDEF_INDEX)
                return self;

            activateById(self.id, true);
            return self;
        }

        pub fn processActive(f: *const fn (*T) void) void {
            if (adapter.pool.active_mapping) |*am| {
                var next = am.nextSetBit(0);
                while (next) |i| {
                    if (adapter.pool.items.get(i)) |c| f(c);
                    next = am.nextSetBit(i + 1);
                }
            }
        }
    };
}

fn ControlTrait(comptime T: type, comptime adapter: anytype, comptime _: Context) type {
    return struct {
        pub fn withActiveControl(self: *T, control: api.ControlFunction, name: ?String) *T {
            return withControl(self, control, name, true);
        }

        pub fn withControl(self: *T, control: api.ControlFunction, name: ?String, active: bool) *T {
            if (adapter.pool.control_mapping) |*cm| {
                const c = api.ComponentControl.new(.{
                    .name = name,
                    .component_type = T.aspect.*,
                    .control = control,
                });
                cm.map(self.id, c.id);
                api.ComponentControl.activateById(c.id, active);
            }
            return self;
        }

        pub fn withActiveControlOf(self: *T, control_type: anytype) *T {
            return withControlOf(self, control_type, true);
        }

        pub fn withControlOf(self: *T, control_type: anytype, active: bool) *T {
            if (adapter.pool.control_mapping) |*cm| {
                const ct = @TypeOf(control_type);
                const control = api.ComponentControlType(ct).new(control_type);
                cm.map(self.id, control.id);

                if (@hasDecl(ct, "initForComponent"))
                    control_type.initForComponent(self.id);

                api.ComponentControl.activateById(control.id, active);
            }
            return self;
        }

        pub fn withControlById(self: *T, control_id: Index) *T {
            if (adapter.pool.control_mapping) |*cm| {
                const c = api.ComponentControl.byId(control_id);
                if (c.component_type == T.aspect)
                    cm.map(self.id, c.id);
            }

            return self;
        }

        pub fn withControlByName(self: *T, name: String) *T {
            if (adapter.pool.control_mapping) |*cm| {
                if (api.ComponentControl.byName(name)) |c| {
                    if (c.component_type == T.aspect)
                        cm.map(self.id, c.id);
                }
            }
            return self;
        }
    };
}

//////////////////////////////////////////////////////////////
//// Component Pooling
//////////////////////////////////////////////////////////////

pub fn ComponentPool(comptime T: type) type {

    // component type constraints and function references
    const has_subscribe: bool = @hasDecl(T, "subscribe");
    const has_active_mapping: bool = @hasDecl(T, "activeCount");
    const has_name_mapping: bool = @hasField(T, "name");
    const has_control_mapping: bool = @hasDecl(T, "withControl");

    // component type init/deinit functions
    const has_component_type_init: bool = @hasDecl(T, "componentTypeInit");
    const has_component_type_deinit: bool = @hasDecl(T, "componentTypeDeinit");

    // component member function interceptors
    const has_construct: bool = @hasDecl(T, "construct");
    const has_activation: bool = @hasDecl(T, "activation");
    const has_destruct = @hasDecl(T, "destruct");

    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects component type is a struct.");
        if (!@hasDecl(T, "COMPONENT_TYPE_NAME"))
            @compileError("Expects component type to have field: COMPONENT_TYPE_NAME: String, that defines a unique name of the component type.");
        if (!@hasField(T, "id"))
            @compileError("Expects component type to have field: id: Index, that holds the index-id of the component");
    }

    return struct {
        const Self = @This();

        // ensure type based singleton
        var _type_init = false;

        var items: utils.DynArray(T) = undefined;
        // mappings
        var active_mapping: ?utils.BitSet = null;
        var name_mapping: ?std.StringHashMap(Index) = null;
        var control_mapping: ?utils.DynIndexMap = null;
        // events
        var eventDispatch: ?utils.EventDispatch(ComponentEvent) = null;

        pub fn init() void {
            if (_type_init)
                return;

            errdefer Self.deinit();
            defer {
                _ = COMPONENT_INTERFACE_TABLE.add(ComponentTypeInterface{
                    .activate = Self.activate,
                    .clear = Self.clear,
                    .deinit = Self.deinit,
                    .to_string = toString,
                });
                _type_init = true;
            }

            items = utils.DynArray(T).new(api.COMPONENT_ALLOC);
            ComponentAspectGroup.applyAspect(T, T.COMPONENT_TYPE_NAME);

            if (has_active_mapping)
                active_mapping = utils.BitSet.newEmpty(api.COMPONENT_ALLOC, 64);

            if (has_subscribe)
                eventDispatch = utils.EventDispatch(ComponentEvent).new(api.COMPONENT_ALLOC);

            if (has_name_mapping)
                name_mapping = std.StringHashMap(Index).init(api.COMPONENT_ALLOC);

            if (has_component_type_init) {
                T.componentTypeInit() catch
                    std.log.err("Failed to initialize component of type: {any}", .{T});
            }

            if (has_control_mapping) {
                control_mapping = utils.DynIndexMap.new(api.COMPONENT_ALLOC);
                api.subscribeUpdate(update);
            }
        }

        /// Release all allocated memory.
        pub fn deinit() void {
            defer _type_init = false;
            if (!_type_init)
                return;

            clearAll();
            if (has_component_type_deinit)
                T.componentTypeDeinit();

            items.deinit();
            if (active_mapping) |*am| {
                am.deinit();
                active_mapping = null;
            }

            if (eventDispatch) |*ed| {
                ed.deinit();
                eventDispatch = null;
            }

            if (name_mapping) |*nm| nm.deinit();
            if (has_control_mapping)
                api.unsubscribeUpdate(update);
            if (control_mapping) |*cm|
                cm.deinit();
            control_mapping = null;
        }

        fn update(_: api.UpdateEvent) void {
            if (control_mapping) |cm| {
                var iterator = cm.mapping.iterator();
                while (iterator.next()) |e| {
                    const c_id = e.key_ptr.*;

                    if (active_mapping) |am|
                        if (!am.isSet(c_id)) continue;

                    for (0..e.value_ptr.size_pointer) |i|
                        api.ComponentControl.update(e.value_ptr.items[i], c_id);
                }
            }
        }

        fn register(c: T) *T {
            const id = items.add(c);
            const result = items.get(id) orelse unreachable;

            result.id = id;
            if (name_mapping) |*nm| {
                if (result.name) |n| {
                    if (nm.contains(n))
                        utils.panic(api.ALLOC, "Component name already exists: {s}", .{n});
                    nm.put(n, id) catch unreachable;
                }
            }

            if (has_construct)
                result.construct();

            notify(ComponentEvent.Type.CREATED, id);
            return result;
        }

        fn activate(id: Index, a: bool) void {
            if (active_mapping) |*am| {
                if ((a and am.isSet(id)) or (!a and !am.isSet(id)))
                    return; // already active or inactive

                am.setValue(id, a);

                if (has_activation)
                    if (items.get(id)) |v| v.activation(a);
                notify(if (a) ComponentEvent.Type.ACTIVATED else ComponentEvent.Type.DEACTIVATING, id);
            }
        }

        pub fn clearAll() void {
            var i: Index = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(next);
                i = next + 1;
            }
        }

        fn clear(id: Index) void {
            if (active_mapping) |*am| {
                if (am.isSet(id))
                    activate(id, false);
                notify(ComponentEvent.Type.DISPOSING, id);
            }

            if (items.get(id)) |val| {
                if (has_destruct)
                    val.destruct();

                if (name_mapping) |*nm| {
                    if (val.name) |n| {
                        _ = nm.remove(n);
                        val.name = null;
                    }
                }

                val.id = UNDEF_INDEX;
                if (active_mapping) |*am|
                    am.setValue(id, false);
                items.delete(id);
            }
        }

        fn toString(string_buffer: *utils.StringBuffer) void {
            string_buffer.print("\n  {s} size: {d}", .{ T.COMPONENT_TYPE_NAME, items.slots.count() });
            var next = items.slots.nextSetBit(0);
            while (next) |i| {
                var active = "(x)";
                if (active_mapping) |*am| {
                    if (am.isSet(i)) active = "(a)";
                }
                string_buffer.print("\n    {s} {any}", .{ active, items.get(i) });
                next = items.slots.nextSetBit(i + 1);
            }
        }

        fn notify(event_type: ComponentEvent.Type, id: Index) void {
            if (eventDispatch) |*ed|
                ed.notify(.{ .event_type = event_type, .c_id = id });
        }
    };
}

//////////////////////////////////////////////////////////////////////////
//// Composite Component
//////////////////////////////////////////////////////////////////////////

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
    pub usingnamespace Trait(Composite, .{
        .name = "Composite",
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    loaded: bool = false,

    attributes: api.Attributes = undefined,
    objects: utils.DynArray(CompositeObject) = undefined,
    _loaded_components: utils.DynArray(CReference) = undefined,

    pub fn construct(self: *Composite) void {
        self.objects = utils.DynArray(CompositeObject).newWithRegisterSize(
            api.COMPONENT_ALLOC,
            5,
        );
        self._loaded_components = utils.DynArray(CReference).newWithRegisterSize(
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
        attributes: ?api.CallContext,
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

    pub fn addComponentReference(self: *Composite, ref: ?CReference) void {
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
