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

    COMPONENT_INTERFACE_TABLE = utils.DynArray(ComponentTypeInterface).newWithRegisterSize(api.COMPONENT_ALLOC, 20);
    SUB_COMPONENT_INTERFACE_TABLE = utils.DynArray(SubComponentTypeInterface).newWithRegisterSize(api.COMPONENT_ALLOC, 20);
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
    // deinit all registered sub-component types
    next = SUB_COMPONENT_INTERFACE_TABLE.slots.nextSetBit(0);
    while (next) |i| {
        if (SUB_COMPONENT_INTERFACE_TABLE.get(i)) |interface| {
            interface.deinit();
            SUB_COMPONENT_INTERFACE_TABLE.delete(i);
        }
        next = SUB_COMPONENT_INTERFACE_TABLE.slots.nextSetBit(i + 1);
    }
    SUB_COMPONENT_INTERFACE_TABLE.deinit();
    SUB_COMPONENT_INTERFACE_TABLE = undefined;
}

//////////////////////////////////////////////////////////////
//// Component API
//////////////////////////////////////////////////////////////
pub const ComponentAspectGroup = utils.AspectGroup(struct {
    pub const name = "ComponentType";
});
pub const ComponentKind = ComponentAspectGroup.Kind;
pub const ComponentAspect = ComponentAspectGroup.Aspect;

pub const GroupAspectGroup = utils.AspectGroup(struct {
    pub const name = "ComponentGroup";
});
pub const GroupKind = GroupAspectGroup.Kind;
pub const GroupAspect = GroupAspectGroup.Aspect;

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
    subtypes: bool = false,
};

pub fn registerComponent(comptime T: type) void {
    ComponentPool(T).init();
}

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
        pub const COMPONENT_TYPE_NAME = context.name;
        pub var aspect: ComponentAspect = undefined;

        const pool = ComponentPool(T);

        pub fn allowSubtypes() bool {
            return context.subtypes;
        }

        pub fn isInitialized() bool {
            return pool._type_init;
        }

        pub fn count() usize {
            return pool.items.slots.count();
        }

        pub fn new(t: T) *T {
            if (context.subtypes)
                @panic("Use new on specific subtype");

            return pool.register(t);
        }

        pub fn reg(t: T) *T {
            return pool.register(t);
        }

        pub fn exists(id: Index) bool {
            return pool.items.exists(id);
        }

        pub fn byId(id: Index) *T {
            return pool.items.get(id).?;
        }

        pub fn referenceById(id: Index, owned: bool) ?api.CRef {
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
            if (id != UNDEF_INDEX)
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
        pub usingnamespace if (context.subscription or context.subtypes) SubscriptionTrait(T, @This(), context) else empty_struct;
        pub usingnamespace if (context.control) ControlTrait(T, @This(), context) else empty_struct;
        pub usingnamespace if (context.grouping) GroupingTrait(T, @This(), context) else empty_struct;
        pub usingnamespace if (context.subtypes) ComponentSubTypingTrait(T, @This(), context) else empty_struct;
    };
}

fn ComponentSubTypingTrait(comptime T: type, comptime _: anytype, comptime context: Context) type {
    return struct {
        pub fn registerSubtype(comptime SubType: type) void {
            ComponentSubType(T, SubType).init();
        }

        pub fn dataById(id: Index, comptime SubType: type) ?@TypeOf(SubType) {
            return SubType.dataById(id);
        }

        pub fn dataByName(name: String, comptime SubType: type) ?@TypeOf(SubType) {
            if (!context.name_mapping)
                return null;

            return SubType.dataByName(name);
        }
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

        pub fn withGroupAspect(self: *T, aspect: GroupAspect) *T {
            return addToGroup(self, aspect);
        }

        pub fn addToGroup(self: *T, aspect: GroupAspect) *T {
            if (self.groups == null)
                self.groups = GroupAspectGroup.newKind();

            if (self.groups) |*g|
                g.addAspect(aspect);

            return self;
        }

        pub fn removeFromGroup(self: *T, group: GroupAspect) *T {
            if (self.groups) |g|
                g.removeAspect(group);

            return self;
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
        pub fn referenceByName(name: String, owned: bool) ?api.CRef {
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
        pub fn withActiveControl(self: *T, update: api.CallFunction, name: ?String) *T {
            return withControl(self, update, name, true);
        }

        pub fn withControl(self: *T, update: api.CallFunction, name: ?String, active: bool) *T {
            if (adapter.pool.control_mapping) |*cm| {
                const c_sub = api.VoidControl.new(.{ .name = name }, update);
                cm.map(self.id, c_sub.id);
                api.Control.activateById(c_sub.id, active);
            }
            return self;
        }

        pub fn withActiveControlOf(self: *T, subtype: anytype) *T {
            return withControlOf(self, subtype, true);
        }

        pub fn withControlOf(self: *T, subtype: anytype, active: bool) *T {
            if (adapter.pool.control_mapping) |*cm| {
                const c_subtype_type = @TypeOf(subtype);
                const c_subtype = c_subtype_type.new(subtype, c_subtype_type.update);
                cm.map(self.id, c_subtype.id);

                if (@hasDecl(c_subtype_type, "initForComponent"))
                    c_subtype_type.initForComponent(self.id);

                api.Control.activateById(c_subtype.id, active);
            }
            return self;
        }

        pub fn applyControlById(self: *T, control_id: Index) *T {
            if (adapter.pool.control_mapping) |*cm| {
                const c = api.Control.byId(control_id);
                if (c.component_type == T.aspect)
                    cm.map(self.id, c.id);
            }

            return self;
        }

        pub fn applyControlByName(self: *T, name: String) *T {
            if (adapter.pool.control_mapping) |*cm| {
                if (api.Control.byName(name)) |c| {
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

fn ComponentPool(comptime T: type) type {

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

            if (has_subscribe or T.allowSubtypes())
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
            if (active_mapping) |*am|
                am.deinit();
            active_mapping = null;

            if (eventDispatch) |*ed|
                ed.deinit();
            eventDispatch = null;

            if (name_mapping) |*nm|
                nm.deinit();
            name_mapping = null;

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

                    for (0..e.value_ptr.size_pointer) |i| {
                        const control_id = e.value_ptr.items[i];
                        var control = api.Control.byId(control_id);
                        control.call_context.id_1 = c_id;
                        control.update(&control.call_context);
                    }
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
            if (id == UNDEF_INDEX)
                return;

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
//// Component Subtype
//////////////////////////////////////////////////////////////////////////

pub fn SubTypeTrait(comptime T: type, comptime SubType: type) type {
    comptime {
        if (!T.allowSubtypes())
            @compileError("Component of type does not support subtypes");
    }
    return struct {
        const subtype = ComponentSubType(T, SubType);

        pub fn newSubType(t: T, st: SubType) *SubType {
            const id = T.reg(t).id;
            const result = subtype.data.getOrPut(id) catch unreachable;
            if (result.found_existing)
                utils.panic(api.ALLOC, "Component Subtype with id already exists: {d}", .{id});

            result.value_ptr.* = st;
            result.value_ptr.*.id = id;

            if (@hasDecl(SubType, "construct"))
                st.construct();

            return result.value_ptr;
        }

        pub fn activate(self: *SubType) void {
            T.activateById(self.id, true);
        }

        pub fn deactivate(self: *SubType) void {
            T.activateById(self.id, false);
        }

        pub fn byId(id: Index) *SubType {
            return subtype.data.getPtr(id).?;
        }

        pub fn existsByName(name: String) bool {
            return T.existsName(name);
        }

        pub fn byName(name: String) ?*SubType {
            if (T.byName(name)) |c|
                return subtype.data.getPtr(c.id);

            return null;
        }

        pub fn idIterator() std.AutoHashMap(Index, SubType).KeyIterator {
            return subtype.data.keyIterator();
        }
    };
}

const SubComponentTypeInterface = struct {
    deinit: api.Deinit,
};
var SUB_COMPONENT_INTERFACE_TABLE: utils.DynArray(SubComponentTypeInterface) = undefined;

fn ComponentSubType(comptime T: type, comptime SubType: type) type {
    comptime {
        if (@typeInfo(SubType) != .Struct)
            @compileError("Expects component sub type is a struct.");
        if (!@hasField(SubType, "id"))
            @compileError("Expects component sub type to have field: id: Index, that holds the index-id of the component");
    }
    return struct {
        pub var data: std.AutoHashMap(Index, SubType) = undefined;
        fn init() void {
            data = std.AutoHashMap(Index, SubType).init(api.COMPONENT_ALLOC);
            // subscribe to T and dispatch activation and dispose
            T.subscribe(notifyComponentChange);
            // create and register SubComponentTypeInterface
            _ = SUB_COMPONENT_INTERFACE_TABLE.add(.{
                .deinit = _deinit,
            });
        }

        fn _deinit() void {
            // unsubscribe from base Component events
            T.unsubscribe(notifyComponentChange);
            // destruct and clear subtype data
            if (@hasDecl(SubType, "deconstruct")) {
                var it = data.iterator();
                while (it.next()) |r|
                    r.value_ptr.deconstruct();
            }

            data.deinit();
            data = undefined;
        }

        fn notifyComponentChange(event: ComponentEvent) void {
            const sub_type: *SubType = data.getPtr(event.c_id.?) orelse return;
            switch (event.event_type) {
                .ACTIVATED => {
                    if (@hasDecl(SubType, "activation"))
                        sub_type.activation(true);
                },
                .DEACTIVATING => {
                    if (@hasDecl(SubType, "activation"))
                        sub_type.activation(false);
                },
                .DISPOSING => {
                    if (@hasDecl(SubType, "deconstruct"))
                        sub_type.deconstruct();

                    _ = data.remove(event.c_id.?);
                },
                else => {},
            }
        }
    };
}
