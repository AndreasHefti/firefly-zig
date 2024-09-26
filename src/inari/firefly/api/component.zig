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

    COMPONENT_INTERFACE_TABLE = utils.DynArray(ComponentTypeInterface).newWithRegisterSize(
        api.COMPONENT_ALLOC,
        20,
    );
    SUB_COMPONENT_INTERFACE_TABLE = utils.DynArray(SubComponentTypeInterface).newWithRegisterSize(
        api.COMPONENT_ALLOC,
        20,
    );
}

pub fn deinit() void {
    defer INIT = false;
    if (!INIT)
        return;

    // deinit all registered component pools
    var next = COMPONENT_INTERFACE_TABLE.slots.prevSetBit(COMPONENT_INTERFACE_TABLE.size());
    while (next) |i| {
        if (COMPONENT_INTERFACE_TABLE.get(i)) |interface| {
            interface.deinit();
            COMPONENT_INTERFACE_TABLE.delete(i);
        }
        next = COMPONENT_INTERFACE_TABLE.slots.prevSetBit(i);
    }
    COMPONENT_INTERFACE_TABLE.deinit();
    COMPONENT_INTERFACE_TABLE = undefined;

    // deinit all registered sub-component types
    next = SUB_COMPONENT_INTERFACE_TABLE.slots.prevSetBit(SUB_COMPONENT_INTERFACE_TABLE.size());
    while (next) |i| {
        if (SUB_COMPONENT_INTERFACE_TABLE.get(i)) |interface| {
            interface.deinit();
            SUB_COMPONENT_INTERFACE_TABLE.delete(i);
        }
        next = SUB_COMPONENT_INTERFACE_TABLE.slots.prevSetBit(i);
    }
    SUB_COMPONENT_INTERFACE_TABLE.deinit();
    SUB_COMPONENT_INTERFACE_TABLE = undefined;
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
//// Component API
//////////////////////////////////////////////////////////////

const ComponentTypeInterface = struct {
    activate: ?*const fn (Index, bool) void,
    clear: *const fn (Index) void,
    deinit: api.DeinitFunction,
    to_string: *const fn (*utils.StringBuffer) void,
};
var COMPONENT_INTERFACE_TABLE: utils.DynArray(ComponentTypeInterface) = undefined;

pub fn registerComponent(comptime T: type, comptime name: String) void {
    Mixin(T).init(name);
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
//// Component Mixins
//////////////////////////////////////////////////////////////

pub fn Mixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");
    // if (!@hasDecl(T, "Component"))
    //     @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");
    if (!@hasField(T, "id"))
        @compileError("Expects component type to have field: id: Index, that holds the index-id of the component instance");

    const has_activation: bool = @hasDecl(T, "Activation");
    const has_naming: bool = @hasDecl(T, "Naming");
    const has_subscription: bool = @hasDecl(T, "Subscription");
    const has_grouping: bool = @hasDecl(T, "Grouping");
    const has_control: bool = @hasDecl(T, "Control");
    const has_subtypes: bool = @hasDecl(T, "Subtypes");

    const has_component_type_init: bool = @hasDecl(T, "componentTypeInit");
    const has_component_type_deinit: bool = @hasDecl(T, "componentTypeDeinit");
    const has_construct: bool = @hasDecl(T, "construct");
    const has_destruct = @hasDecl(T, "destruct");

    return struct {
        const Self = @This();

        var pool: utils.DynArray(T) = undefined;
        var _type_init = false;

        pub var component_name: String = undefined;
        pub var aspect: api.ComponentAspect = undefined;

        pub fn init(name: String) void {
            defer _type_init = true;
            if (_type_init)
                return;

            std.debug.print("FIREFLY : INFO: initialize component: {s}\n", .{name});

            defer {
                _ = COMPONENT_INTERFACE_TABLE.add(ComponentTypeInterface{
                    .activate = if (has_activation) ActivationMixin(T).set else null,
                    .clear = clear,
                    .deinit = Self.deinit,
                    .to_string = toString,
                });
            }

            component_name = name;
            pool = utils.DynArray(T).new(api.COMPONENT_ALLOC);
            api.ComponentAspectGroup.applyAspect(Self, name);

            if (has_activation)
                ActivationMixin(T).init();
            if (has_naming)
                NameMappingMixin(T).init();
            if (has_subscription)
                SubscriptionMixin(T).init();
            if (has_grouping)
                GroupingMixin(T).init();
            if (has_control)
                ControlMixin(T).init();
            if (has_subtypes)
                SubTypingMixin(T).init();

            if (has_component_type_init) {
                T.componentTypeInit() catch
                    std.log.err("Failed to initialize component of type: {any}", .{T});
            }
        }

        fn deinit() void {
            defer _type_init = false;
            if (!_type_init)
                return;

            std.debug.print("FIREFLY : INFO: deinitialize component: {s}\n", .{component_name});

            clearAll();

            if (has_component_type_deinit)
                T.componentTypeDeinit();

            pool.deinit();
            pool = undefined;

            if (has_activation)
                ActivationMixin(T).deinit();
            if (has_naming)
                NameMappingMixin(T).deinit();
            if (has_subscription)
                SubscriptionMixin(T).deinit();
            if (has_grouping)
                GroupingMixin(T).deinit();
            if (has_control)
                ControlMixin(T).deinit();
            if (has_subtypes)
                SubTypingMixin(T).deinit();
        }

        pub fn size() usize {
            return pool.slots.count();
        }

        pub fn new(t: T) *T {
            if (has_subtypes)
                @panic("Use new on specific subtype");

            return register(t);
        }

        fn register(t: T) *T {
            const id = pool.add(t);
            const result: *T = pool.get(id) orelse unreachable;

            result.id = id;
            if (has_naming) {
                if (result.name) |n| {
                    if (NameMappingMixin(T).mapping.contains(n))
                        utils.panic(api.ALLOC, "Component name already exists: {s}", .{n});
                    NameMappingMixin(T).mapping.put(n, id) catch unreachable;
                }
            }

            if (has_construct)
                result.construct();

            if (has_subscription)
                SubscriptionMixin(T).notify(ComponentEvent.Type.CREATED, id);

            return result;
        }

        pub fn exists(id: Index) bool {
            return pool.exists(id);
        }

        pub fn byId(id: Index) *T {
            return pool.get(id).?;
        }

        pub fn getReference(id: Index, owned: bool) ?api.CRef {
            _ = pool.get(id) orelse return null;
            return .{
                .type = aspect,
                .id = id,
                .is_valid = isRefValid,
                .activation = if (has_activation) ActivationMixin(T).set else null,
                .dispose = if (owned) dispose else null,
            };
        }

        fn isRefValid(id: Index) bool {
            if (!_type_init)
                return false;

            return pool.exists(id);
        }

        pub fn nextId(id: Index) ?Index {
            return pool.slots.nextSetBit(id);
        }

        pub fn dispose(id: Index) void {
            if (id != UNDEF_INDEX)
                clear(id);
        }

        fn clearAll() void {
            var i: Index = 0;
            while (pool.slots.nextSetBit(i)) |next| {
                clear(next);
                i = next + 1;
            }
        }

        fn clear(id: Index) void {
            if (id == UNDEF_INDEX)
                return;

            if (has_activation)
                ActivationMixin(T).set(id, false);

            if (has_subscription)
                SubscriptionMixin(T).notify(ComponentEvent.Type.DISPOSING, id);

            if (pool.get(id)) |t| {
                if (has_destruct)
                    t.destruct();

                if (has_naming) {
                    if (t.name) |n| {
                        _ = NameMappingMixin(T).mapping.remove(n);
                        t.name = null;
                    }
                }

                t.id = UNDEF_INDEX;
                pool.delete(id);
            }
        }

        fn toString(string_buffer: *utils.StringBuffer) void {
            string_buffer.print("\n  {s} size: {d}", .{ component_name, pool.slots.count() });
            var next = pool.slots.nextSetBit(0);
            while (next) |i| {
                next = pool.slots.nextSetBit(i + 1);
                var active = "(x)";
                if (has_activation) {
                    if (ActivationMixin(T).mapping.isSet(i)) active = "(a)";
                }
                string_buffer.print("\n    {s} {any}", .{ active, pool.get(i) });
            }
        }
    };
}

pub fn ActivationMixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");
    if (!@hasDecl(T, "Component"))
        @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");

    const has_activation_function: bool = @hasDecl(T, "activation");
    const has_subscription: bool = @hasDecl(T, "Subscription");
    const has_naming: bool = @hasDecl(T, "Naming");
    const mixin = Mixin(T);

    return struct {
        var mapping: utils.BitSet = undefined;
        var _init = false;

        fn init() void {
            defer _init = true;
            if (_init) return;
            _ = @typeName(T); // NOTE: if this is not touched here, memoization brakes for some unknown reason
            mapping = utils.BitSet.newEmpty(api.COMPONENT_ALLOC, 64);
        }

        fn deinit() void {
            defer _init = false;
            if (!_init) return;
            mapping.deinit();
            mapping = undefined;
        }

        fn set(id: Index, active: bool) void {
            if ((active and mapping.isSet(id)) or (!active and !mapping.isSet(id)))
                return; // already active or inactive

            mapping.setValue(id, active);

            if (has_activation_function)
                mixin.byId(id).activation(active);

            if (has_subscription)
                SubscriptionMixin(T).notify(if (active) ComponentEvent.Type.ACTIVATED else ComponentEvent.Type.DEACTIVATING, id);
        }

        pub fn activate(id: Index) void {
            set(id, true);
        }

        pub fn deactivate(id: Index) void {
            set(id, false);
        }

        pub fn activateByName(name: String) void {
            setByName(name, true);
        }

        pub fn deactivateByName(name: String) void {
            setByName(name, false);
        }

        fn setByName(name: String, active: bool) void {
            if (has_naming)
                if (NameMappingMixin(T).getIdOpt(name)) |id|
                    set(id, active);
        }

        pub fn isActive(id: Index) bool {
            return mapping.isSet(id);
        }

        pub fn isActiveByName(name: String) bool {
            if (has_naming) {
                if (NameMappingMixin(T).getIdOpt(name)) |id|
                    return mapping.isSet(id);
            }
            return false;
        }

        pub fn byId(id: Index) ?*T {
            if (mapping.isSet(id))
                return mixin.byId(id);
            return null;
        }

        pub fn count() usize {
            return mapping.count();
        }

        pub fn nextId(id: Index) ?Index {
            return mapping.nextSetBit(id);
        }

        pub fn process(f: *const fn (*T) void) void {
            var next = nextId(0);
            while (next) |i| {
                next = nextId(i + 1);
                f(mixin.byId(i));
            }
        }
    };
}

pub fn NameMappingMixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");
    if (!@hasDecl(T, "Component"))
        @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");
    if (!@hasField(T, "name"))
        @compileError("Expects component type to have optional field: name: ?String, that holds name of the component instance");

    const mixin = Mixin(T);

    return struct {
        pub var mapping: std.StringHashMap(Index) = undefined;
        var _init = false;

        fn init() void {
            defer _init = true;
            if (_init) return;
            _ = @typeName(T); // NOTE: if this is not touched here, memoization brakes for some unknown reason
            mapping = std.StringHashMap(Index).init(api.COMPONENT_ALLOC);
        }

        fn deinit() void {
            defer _init = false;
            if (!_init) return;
            mapping.deinit();
            mapping = undefined;
        }

        pub fn exists(name: String) bool {
            return mapping.contains(name);
        }

        pub fn getId(name: String) Index {
            return getIdOpt(name) orelse missName(name);
        }

        pub fn getIdOpt(name: String) ?Index {
            return mapping.get(name);
        }

        pub fn byName(name: String) ?*T {
            if (getIdOpt(name)) |id|
                return mixin.byId(id);
            return null;
        }

        pub fn getReference(name: String, owned: bool) ?api.CRef {
            if (getIdOpt(name)) |id|
                return mixin.getReference(id, owned);
            return null;
        }

        pub fn dispose(name: String) void {
            if (getIdOpt(name)) |id|
                return mixin.dispose(id);
        }

        inline fn missName(name: String) void {
            utils.panic(api.ALLOC, "no component with name: {s}", .{name});
        }
    };
}

pub fn SubscriptionMixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @panic("Expects component type is a struct.");
    if (!@hasDecl(T, "Component"))
        @panic("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");

    return struct {
        var dispatcher: utils.EventDispatch(ComponentEvent) = undefined;
        var _init = false;

        fn init() void {
            defer _init = true;
            if (_init)
                return;
            _ = @typeName(T); // NOTE: if this is not touched here, memoization brakes for some unknown reason
            //std.debug.print("************* Init SubscriptionMixin for: {any} {s}\n", .{ @intFromPtr(&dispatcher), @typeName(T) });
            dispatcher = utils.EventDispatch(ComponentEvent).new(api.COMPONENT_ALLOC);
        }

        fn deinit() void {
            defer _init = false;
            if (!_init) return;
            //std.debug.print("************** Deinit SubscriptionMixin for: {s}\n", .{@typeName(T)});
            dispatcher.deinit();
            dispatcher = undefined;
        }

        pub fn subscribe(listener: ComponentListener) void {
            //std.debug.print("************** Subscribe for: {s}\n", .{@typeName(T)});
            //std.debug.print("************** Subscribe listener for dispatcher: {any}\n", .{@intFromPtr(&dispatcher)});
            //std.debug.print("************** Subscribe init is: {any}\n", .{_init});
            if (_init) {
                dispatcher.register(listener);
            }
        }

        pub fn unsubscribe(listener: ComponentListener) void {
            if (_init) {
                dispatcher.unregister(listener);
            }
        }

        fn notify(event_type: ComponentEvent.Type, id: Index) void {
            //std.debug.print("************* Notify for: {any} {s}\n", .{ @intFromPtr(&dispatcher), @typeName(T) });
            //_ = @typeName(T);
            if (_init) {
                dispatcher.notify(.{ .event_type = event_type, .c_id = id });
            }
        }
    };
}

pub fn GroupingMixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");
    if (!@hasDecl(T, "Component"))
        @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");
    if (!@hasDecl(T, "Grouping"))
        @compileError("Expects component type to have declaration: const Grouping = GroupingMixin(T).");
    if (!@hasField(T, "groups"))
        @compileError("Expects component type to have optional field: groups: ?api.GroupKind, that holds the group aspects of component instance");

    const mixin = Mixin(T);

    return struct {
        var _init = false;

        fn init() void {
            defer _init = true;
            if (_init) return;
            _ = @typeName(T); // NOTE: if this is not touched here, memoization brakes for some unknown reason
        }

        fn deinit() void {
            defer _init = false;
            if (!_init) return;
        }

        pub fn get(id: Index) ?api.GroupKind {
            const c = mixin.byId(id) orelse return null;
            return c.groups;
        }

        pub fn add(id: Index, aspect: api.GroupAspect) void {
            var comp: *T = mixin.byId(id);
            if (comp.groups == null)
                comp.groups = api.GroupAspectGroup.newKind();

            if (comp.groups) |*g|
                g.addAspect(aspect);
        }

        pub fn remove(id: Index, aspect: api.GroupAspect) void {
            const comp: *T = mixin.byId(id);
            if (comp.groups) |g|
                g.removeAspect(aspect);
        }

        pub fn isInGroup(id: Index, aspect: api.GroupAspect) void {
            const comp: *T = mixin.byId(id);
            if (comp.groups) |g|
                return g.isIn(aspect);
            return false;
        }

        fn process(group: api.GroupAspect, f: *const fn (*T) void) void {
            var next = mixin.nextId(0);
            while (next) |i| {
                next = mixin.nextId(i + 1);
                const c = mixin.byId(i) orelse continue;
                const g = c.groups orelse continue;
                if (g.hasAspect(group))
                    f(c);
            }
        }
    };
}

pub fn ControlMixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");
    if (!@hasDecl(T, "Component"))
        @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");
    if (!@hasDecl(T, "Control"))
        @compileError("Expects component type to have declaration: const Control = ControlMixin(T).");

    const has_activation: bool = @hasDecl(T, "Activation");
    const mixin = Mixin(T);
    const activation_mixin = ActivationMixin(T);
    const control_mixin = Mixin(api.Control);

    return struct {
        var indexes: utils.DynIndexMap = undefined;
        var _init = false;

        fn init() void {
            defer _init = true;
            if (_init) return;
            _ = @typeName(T); // NOTE: if this is not touched here, memoization brakes for some unknown reason
            indexes = utils.DynIndexMap.new(api.COMPONENT_ALLOC);
            api.subscribeUpdate(_update);
        }

        fn deinit() void {
            defer _init = false;
            if (!_init) return;
            api.unsubscribeUpdate(_update);
            indexes.deinit();
            indexes = undefined;
        }

        pub fn addActive(id: Index, update: api.CallFunction, name: ?String) void {
            add(id, update, name, true);
        }

        pub fn add(id: Index, update: api.CallFunction, name: ?String, active: bool) void {
            const c_sub = api.VoidControl.new(
                .{ .name = name },
                update,
            );
            indexes.map(id, c_sub.id);
            ActivationMixin(api.Control).set(c_sub.id, active);
        }

        pub fn addActiveOf(id: Index, subtype: anytype) void {
            addOf(id, subtype, true);
        }

        pub fn addOf(id: Index, subtype: anytype, active: bool) void {
            const c_subtype_type = @TypeOf(subtype);
            const c_subtype = c_subtype_type.new(subtype, c_subtype_type.update);
            indexes.map(id, c_subtype.id);

            if (@hasDecl(c_subtype_type, "initForComponent"))
                c_subtype_type.initForComponent(id);

            ActivationMixin(api.Control).set(c_subtype.id, active);
        }

        pub fn addById(id: Index, control_id: Index) void {
            const c: *api.Control = control_mixin.byId(control_id);
            if (c.controlled_component_type == T.aspect)
                indexes.map(id, c.id);
        }

        pub fn addByName(id: Index, name: String) void {
            const c: *api.Control = api.Control.naming.byName(name) orelse return;
            if (c.controlled_component_type == mixin.aspect)
                indexes.map(id, c.id);
        }

        fn _update(_: api.UpdateEvent) void {
            var iterator = indexes.mapping.iterator();
            while (iterator.next()) |e| {
                const c_id = e.key_ptr.*;

                if (has_activation and !activation_mixin.isActive(c_id))
                    continue;

                for (0..e.value_ptr.size_pointer) |i| {
                    const control_id = e.value_ptr.items[i];
                    var control: *api.Control = control_mixin.byId(control_id);
                    control.call_context.id_1 = c_id;
                    control.update(&control.call_context);
                }
            }
        }
    };
}

pub fn SubTypingMixin(comptime T: type) type {
    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects component type is a struct.");
        if (!@hasDecl(T, "Component"))
            @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");
    }

    const has_naming: bool = @hasDecl(T, "Naming");

    return struct {
        var _init = false;

        fn init() void {
            defer _init = true;
            if (_init) return;
            _ = @typeName(T); // NOTE: if this is not touched here, memoization brakes for some unknown reason
        }

        fn deinit() void {
            defer _init = false;
            if (!_init) return;
        }

        pub fn register(comptime SubType: type) void {
            ComponentSubType(T, SubType).init();
        }

        pub fn dataById(id: Index, comptime SubType: type) ?@TypeOf(SubType) {
            return SubType.dataById(id);
        }

        pub fn dataByName(name: String, comptime SubType: type) ?@TypeOf(SubType) {
            if (has_naming)
                return null;

            return SubType.dataByName(name);
        }
    };
}

//////////////////////////////////////////////////////////////////////////
//// Component Subtype
//////////////////////////////////////////////////////////////////////////

const SubComponentTypeInterface = struct {
    deinit: api.DeinitFunction,
};
var SUB_COMPONENT_INTERFACE_TABLE: utils.DynArray(SubComponentTypeInterface) = undefined;

pub fn SubTypeMixin(comptime T: type, comptime SubType: type) type {
    // comptime {
    //     if (!T.allowSubtypes())
    //         @compileError("Component of type does not support subtypes");
    // }
    return struct {
        const subtype = ComponentSubType(T, SubType);

        pub fn newSubType(t: T, st: SubType) *SubType {
            const id = T.Component.register(t).id;
            const result = subtype.data.getOrPut(id) catch unreachable;
            if (result.found_existing)
                utils.panic(api.ALLOC, "Component Subtype with id already exists: {d}", .{id});

            result.value_ptr.* = st;
            result.value_ptr.*.id = id;

            if (@hasDecl(SubType, "construct"))
                result.value_ptr.*.construct();

            return result.value_ptr;
        }

        pub fn activateById(id: Index, active: bool) void {
            T.Activation.set(id, active);
        }

        pub fn activate(self: *SubType) void {
            T.Activation.set(self.id, true);
        }

        pub fn deactivate(self: *SubType) void {
            T.Activation.set(self.id, false);
        }

        pub fn byId(id: Index) *SubType {
            return subtype.data.getPtr(id).?;
        }

        pub fn existsByName(name: String) bool {
            return T.Naming.exists(name);
        }

        pub fn byName(name: String) ?*SubType {
            if (T.Naming.byName(name)) |c|
                return subtype.data.getPtr(c.id);

            return null;
        }

        pub fn idByName(name: String) ?Index {
            return T.Naming.getIdOpt(name);
        }

        pub fn activateByName(name: String, active: bool) void {
            T.Activation.setByName(name, active);
        }

        pub fn idIterator() std.AutoHashMap(Index, SubType).KeyIterator {
            return subtype.data.keyIterator();
        }
    };
}

fn ComponentSubType(comptime T: type, comptime SubType: type) type {
    comptime {
        if (@typeInfo(SubType) != .Struct)
            @compileError("Expects component sub type is a struct.");
        if (!@hasField(SubType, "id"))
            @compileError("Expects component sub type to have field: id: Index, that holds the index-id of the component");
        if (!@hasDecl(T, "Subscription"))
            @compileError("Expects component type to have declaration: const Subscription = SubscriptionMixin(T).");
    }
    return struct {
        pub var data: std.AutoHashMap(Index, SubType) = undefined;

        fn init() void {
            data = std.AutoHashMap(Index, SubType).init(api.COMPONENT_ALLOC);
            // subscribe to T and dispatch activation and dispose
            T.Subscription.subscribe(notifyComponentChange);
            // create and register SubComponentTypeInterface
            _ = SUB_COMPONENT_INTERFACE_TABLE.add(.{
                .deinit = _deinit,
            });
        }

        fn _deinit() void {
            // unsubscribe from base Component events
            T.Subscription.unsubscribe(notifyComponentChange);
            // destruct and clear subtype data
            if (@hasDecl(SubType, "destruct")) {
                var it = data.iterator();
                while (it.next()) |r|
                    r.value_ptr.destruct();
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
                    if (@hasDecl(SubType, "destruct"))
                        sub_type.destruct();

                    _ = data.remove(event.c_id.?);
                },
                else => {},
            }
        }
    };
}
