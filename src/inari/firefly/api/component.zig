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

    TYPE_REFERENCES = utils.DynArray(TypeReference).newWithRegisterSize(
        api.COMPONENT_ALLOC,
        20,
    );
    Subtype.TYPE_REFERENCES = utils.DynArray(Subtype.TypeReference).newWithRegisterSize(
        api.COMPONENT_ALLOC,
        20,
    );
}

pub fn deinit() void {
    defer INIT = false;
    if (!INIT)
        return;

    // deinit all registered component pools
    var next = TYPE_REFERENCES.slots.prevSetBit(TYPE_REFERENCES.size());
    while (next) |i| {
        if (TYPE_REFERENCES.get(i)) |interface| {
            interface.deinit();
            TYPE_REFERENCES.delete(i);
        }
        next = TYPE_REFERENCES.slots.prevSetBit(i);
    }
    TYPE_REFERENCES.deinit();
    TYPE_REFERENCES = undefined;

    // deinit all registered sub-component types
    next = Subtype.TYPE_REFERENCES.slots.prevSetBit(Subtype.TYPE_REFERENCES.size());
    while (next) |i| {
        if (Subtype.TYPE_REFERENCES.get(i)) |interface| {
            interface.deinit();
            Subtype.TYPE_REFERENCES.delete(i);
        }
        next = Subtype.TYPE_REFERENCES.slots.prevSetBit(i);
    }
    Subtype.TYPE_REFERENCES.deinit();
    Subtype.TYPE_REFERENCES = undefined;
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

const TypeReference = struct {
    activate: ?*const fn (Index, bool) void,
    clear: *const fn (Index) void,
    deinit: api.DeinitFunction,
    to_string: *const fn (*utils.StringBuffer) void,
};
var TYPE_REFERENCES: utils.DynArray(TypeReference) = undefined;

pub fn register(comptime T: type, comptime name: String) void {
    Mixin(T).init(name);
}

pub fn print(string_buffer: *utils.StringBuffer) void {
    string_buffer.print("\nComponents:", .{});
    var next = TYPE_REFERENCES.slots.nextSetBit(0);
    while (next) |i| {
        if (TYPE_REFERENCES.get(i)) |interface| interface.to_string(string_buffer);
        next = TYPE_REFERENCES.slots.nextSetBit(i + 1);
    }
}

//////////////////////////////////////////////////////////////
//// Component Mixins
//////////////////////////////////////////////////////////////

pub fn Mixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");
    if (!@hasField(T, api.FIELD_NAMES.COMPONENT_ID_FIELD))
        @compileError("Expects component type to have field: id: Index, that holds the index-id of the component instance");

    const has_activation: bool = @hasDecl(T, api.DECLARATION_NAMES.ACTIVATION_MIXIN);
    const has_naming: bool = @hasDecl(T, api.DECLARATION_NAMES.NAMING_MIXIN);
    const has_subscription: bool = @hasDecl(T, api.DECLARATION_NAMES.SUBSCRIPTION_MIXIN);
    const has_call_context: bool = @hasDecl(T, api.DECLARATION_NAMES.CALL_CONTEXT_MIXIN);
    const has_attributes: bool = @hasDecl(T, api.DECLARATION_NAMES.ATTRIBUTE_MIXIN);
    const has_grouping: bool = @hasDecl(T, api.DECLARATION_NAMES.GROUPING_MIXIN);
    const has_control: bool = @hasDecl(T, api.DECLARATION_NAMES.CONTROL_MIXIN);
    const has_subtypes: bool = @hasDecl(T, api.DECLARATION_NAMES.SUBTYPE_MIXIN);

    const has_component_type_init: bool = @hasDecl(T, api.FUNCTION_NAMES.COMPONENT_TYPE_INIT_FUNCTION);
    const has_component_type_deinit: bool = @hasDecl(T, api.FUNCTION_NAMES.COMPONENT_TYPE_DEINIT_FUNCTION);
    const has_construct: bool = @hasDecl(T, api.FUNCTION_NAMES.COMPONENT_CONSTRUCTOR_FUNCTION);
    const has_destruct = @hasDecl(T, api.FUNCTION_NAMES.COMPONENT_DESTRUCTOR_FUNCTION);

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

            api.Logger.info("Initialize component: {s}", .{name});

            defer {
                _ = TYPE_REFERENCES.add(TypeReference{
                    .activate = if (has_activation) ActivationMixin(T).set else null,
                    .clear = clear,
                    .deinit = Self.deinit,
                    .to_string = toString,
                });
            }

            component_name = name;
            pool = utils.DynArray(T).newWithRegisterSize(api.COMPONENT_ALLOC, 512);
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

            api.Logger.info("Deinitialize component: {s}", .{component_name});

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

        pub fn newAndGet(t: T) *T {
            return byId(new(t));
        }

        pub fn newActive(t: T) Index {
            const c_id = new(t);
            if (has_activation)
                T.Activation.activate(c_id);
            return c_id;
        }

        pub fn new(t: T) Index {
            if (has_subtypes)
                @panic("Use new on specific subtype");

            return @This().register(t).id;
        }

        pub fn newForSubType(t: T) *T {
            return @This().register(t);
        }

        fn register(t: T) *T {
            if (!_type_init)
                @panic("Type is not initialized yet");

            const id = pool.add(t);
            const result: *T = pool.get(id) orelse unreachable;

            result.id = id;
            if (has_naming) {
                if (result.name) |n| {
                    if (NameMappingMixin(T).mapping.contains(n))
                        std.debug.panic("Component name already exists: {s}", .{n});

                    NameMappingMixin(T).mapping.put(n, id) catch |err| api.handleUnknownError(err);
                }
            }

            if (has_call_context)
                CallContextMixin(T).construct(result);

            if (has_attributes)
                AttributeMixin(T).construct(result);

            if (has_construct)
                result.construct();

            if (has_subscription)
                SubscriptionMixin(T).notify(ComponentEvent.Type.CREATED, id);

            return result;
        }

        pub fn byId(id: Index) *T {
            return pool.get(id).?;
        }

        pub fn byIdOptional(id: Index) ?*T {
            if (!_type_init)
                return null;

            return pool.get(id);
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
            if (!_type_init)
                return;

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

                if (has_call_context)
                    CallContextMixin(T).destruct(t);

                if (has_attributes)
                    AttributeMixin(T).destruct(t);

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
    if (!@hasDecl(T, api.DECLARATION_NAMES.COMPONENT_MIXIN))
        @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");

    const has_activation_function: bool = @hasDecl(T, api.FUNCTION_NAMES.COMPONENT_ACTIVATION_FUNCTION);
    const has_subscription: bool = @hasDecl(T, api.DECLARATION_NAMES.SUBSCRIPTION_MIXIN);
    const has_naming: bool = @hasDecl(T, api.DECLARATION_NAMES.NAMING_MIXIN);
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
    if (!@hasDecl(T, api.DECLARATION_NAMES.COMPONENT_MIXIN))
        @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");
    if (!@hasField(T, api.FIELD_NAMES.COMPONENT_NAME_FIELD))
        @compileError("Expects component type to have optional field: name: ?String, that holds name of the component instance");

    const mixin = Mixin(T);

    return struct {
        pub var mapping: std.StringHashMap(Index) = undefined;
        var _init = false;

        fn init() void {
            defer _init = true;
            if (_init)
                return;

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
            std.debug.panic("no component with name: {s}", .{name});
        }
    };
}

pub fn SubscriptionMixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @panic("Expects component type is a struct.");
    if (!@hasDecl(T, api.DECLARATION_NAMES.COMPONENT_MIXIN))
        @panic("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");

    return struct {
        var dispatcher: utils.EventDispatch(ComponentEvent) = undefined;
        var _init = false;

        fn init() void {
            defer _init = true;
            if (_init)
                return;

            _ = @typeName(T); // NOTE: if this is not touched here, memoization brakes for some unknown reason
            dispatcher = utils.EventDispatch(ComponentEvent).new(api.COMPONENT_ALLOC);
        }

        fn deinit() void {
            defer _init = false;
            if (!_init)
                return;

            dispatcher.deinit();
            dispatcher = undefined;
        }

        pub fn subscribe(listener: ComponentListener) void {
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
            if (_init) {
                dispatcher.notify(.{ .event_type = event_type, .c_id = id });
            }
        }
    };
}

pub fn CallContextMixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");
    if (!@hasField(T, api.FIELD_NAMES.CALL_CONTEXT_FIELD))
        @compileError("Expects component type to have field: call_context: api.CallContext, that holds the call context for a component");

    return struct {
        pub const Attributes = AttributeMixin(T);

        pub fn construct(self: *T) void {
            self.call_context = .{
                .caller_id = self.id,
            };
            if (@hasField(T, "name"))
                self.call_context.caller_name = self.name;

            Attributes.construct(self);
        }

        pub fn destruct(self: *T) void {
            Attributes.destruct(self);
        }
    };
}

pub fn AttributeMixin(comptime T: type) type {
    const has_attributes_id: bool = @hasField(T, api.FIELD_NAMES.ATTRIBUTE_ID_FIELD);
    const has_init_attributes: bool = @hasDecl(T, api.FIELD_NAMES.ATTRIBUTE_INIT_FLAG_FIELD);
    const has_call_context: bool = @hasField(T, api.FIELD_NAMES.CALL_CONTEXT_FIELD);

    if (!has_attributes_id and !has_call_context)
        @panic("Expecting type has one of the following fields: attributes_id: ?Index, call_context: CallContext");
    if (!@hasField(T, api.FIELD_NAMES.COMPONENT_ID_FIELD))
        @panic("Expecting type has fields: id: Index");

    return struct {
        fn construct(self: *T) void {
            if (has_init_attributes) {
                const name = getAttributesName(self);
                if (T.init_attributes) {
                    if (has_call_context) {
                        self.call_context.attributes_id = api.Attributes.Component.new(.{ .name = name });
                    } else if (has_attributes_id) {
                        self.attributes_id = api.Attributes.Component.new(.{ .name = name });
                    }
                }
            }
        }

        fn getAttributesName(self: *T) ?String {
            return api.format("{s}_{d}_{?s}", .{
                if (@hasDecl(T, "aspect")) T.aspect.name else @typeName(T),
                self.id,
                self.name,
            });
        }

        fn destruct(self: *T) void {
            if (has_call_context) {
                if (self.call_context.attributes_id) |aid|
                    api.Attributes.Component.dispose(aid);
                self.call_context.attributes_id = null;
            } else if (has_attributes_id) {
                if (self.attributes_id) |aid|
                    api.Attributes.Component.dispose(aid);
                self.attributes_id = null;
            }
        }

        pub fn getAttributes(component_id: Index) ?*api.Attributes {
            if (getAttributesId(component_id)) |id|
                return api.Attributes.Component.byId(id);
            return null;
        }

        pub fn getAttribute(component_id: Index, name: String) ?String {
            if (getAttributesId(component_id)) |id|
                return api.Attributes.Component.byId(id)._dict.get(name);
            return null;
        }

        pub fn setAttribute(component_id: Index, name: String, value: String) void {
            if (getAttributesId(component_id)) |id|
                api.Attributes.Component.byId(id).set(name, value);
        }

        pub fn setAttributes(component_id: Index, attributes: anytype) void {
            if (getAttributesId(component_id)) |id| {
                var attrs = api.Attributes.Component.byId(id);
                inline for (attributes) |v|
                    attrs.set(v[0], v[1]);
            }
        }

        pub fn setAllAttributes(component_id: Index, attributes: *api.Attributes) void {
            if (getAttributesId(component_id)) |id|
                api.Attributes.Component.byId(id).setAll(attributes);
        }

        pub fn setAllAttributesById(component_id: Index, attributes_id: ?Index) void {
            if (attributes_id) |aid|
                if (getAttributesId(component_id)) |id|
                    api.Attributes.Component.byId(id).setAll(api.Attributes.Component.byId(aid));
        }

        fn getAttributesId(component_id: Index) ?Index {
            if (has_attributes_id) {
                return T.Component.byId(component_id).attributes_id;
            } else if (has_call_context) {
                return T.Component.byId(component_id).call_context.attributes_id;
            }
        }
    };
}

pub fn GroupingMixin(comptime T: type) type {
    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");
    if (!@hasDecl(T, api.DECLARATION_NAMES.COMPONENT_MIXIN))
        @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");
    if (!@hasDecl(T, api.DECLARATION_NAMES.GROUPING_MIXIN))
        @compileError("Expects component type to have declaration: const Grouping = GroupingMixin(T).");
    if (!@hasField(T, api.FIELD_NAMES.COMPONENT_GROUPS_FIELD))
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
    if (!@hasDecl(T, api.DECLARATION_NAMES.COMPONENT_MIXIN))
        @compileError("Expects component type to have declaration: const Component = Mixin(T), used to referencing component mixin.");
    if (!@hasDecl(T, api.DECLARATION_NAMES.CONTROL_MIXIN))
        @compileError("Expects component type to have declaration: const Control = ControlMixin(T).");

    const has_activation: bool = @hasDecl(T, api.DECLARATION_NAMES.ACTIVATION_MIXIN);
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
            const c_sub_id = api.VoidControl.Component.new(.{
                .name = name,
                .update = update,
            });

            indexes.map(id, c_sub_id);
            ActivationMixin(api.Control).set(c_sub_id, active);
        }

        pub fn addActiveOf(id: Index, subtype: anytype) void {
            addOf(id, subtype, true);
        }

        pub fn addOf(id: Index, subtype: anytype, active: bool) void {
            const c_subtype_type = @TypeOf(subtype);
            const c_sub_id = c_subtype_type.Component.new(subtype);
            indexes.map(id, c_sub_id);

            // if (@hasDecl(c_subtype_type, "initForComponent"))
            //     c_subtype_type.initForComponent(id);

            ActivationMixin(api.Control).set(c_sub_id, active);
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
        // if (!@hasDecl(T, "createForSubType"))
        //     @compileError("Expects component type to have function: createForSubType(SubType) *T, used to create Component for Subtype.");
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

        pub fn isOfType(id: Index, comptime SubType: type) bool {
            return SubType.Component.exists(id);
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

pub const Subtype = struct {
    const TypeReference = struct {
        deinit: api.DeinitFunction,
    };
    var TYPE_REFERENCES: utils.DynArray(Subtype.TypeReference) = undefined;

    pub fn register(comptime T: type, comptime SubType: type, name: String) void {
        SubTypeMixin(T, SubType).init(name);
    }
};

pub fn SubTypeMixin(comptime T: type, comptime SubType: type) type {
    if (!@hasDecl(T, "Subscription"))
        @compileError("Expects component type to have declaration: const Subscription = SubscriptionMixin(T).");

    return struct {
        var _init = false;
        var data: std.AutoHashMap(Index, SubType) = undefined;

        pub var sub_type_type: api.SubTypeAspect = undefined;

        fn init(name: String) void {
            defer _init = true;
            if (_init)
                return;

            sub_type_type = api.SubTypeAspectGroup.getAspect(name);
            data = std.AutoHashMap(Index, SubType).init(api.COMPONENT_ALLOC);
            // subscribe to T and dispatch activation and dispose
            T.Subscription.subscribe(notifyComponentChange);
            // create and register TypeReference
            _ = Subtype.TYPE_REFERENCES.add(.{
                .deinit = _deinit,
            });
        }

        fn _deinit() void {
            defer _init = false;
            if (!_init)
                return;

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

        pub fn exists(id: Index) bool {
            return data.contains(id);
        }

        pub fn createSubtype(base: T, subtype: SubType) *SubType {
            return _register(T.Component.register(base), subtype);
        }

        pub fn newActive(st: SubType) Index {
            const id = new(st);
            ActivationMixin(T).activate(id);
            return id;
        }

        pub fn newGet(subtype: SubType) *SubType {
            return byId(new(subtype));
        }

        pub fn new(subtype: SubType) Index {
            return _register(T.createForSubType(subtype), subtype).id;
        }

        fn _register(base_type: *T, subtype: SubType) *SubType {
            const result = data.getOrPut(base_type.id) catch |err| api.handleUnknownError(err);
            if (result.found_existing)
                std.debug.panic("Component Subtype with id already exists: {d}", .{base_type.id});

            result.value_ptr.* = subtype;
            result.value_ptr.*.id = base_type.id;

            if (@hasDecl(SubType, "construct"))
                result.value_ptr.*.construct();

            return result.value_ptr;
        }

        pub fn activateById(id: Index) void {
            ActivationMixin(T).activate(id);
        }

        pub fn deactivateById(id: Index) void {
            ActivationMixin(T).deactivate(id);
        }

        pub fn byId(id: Index) *SubType {
            return data.getPtr(id).?;
        }

        pub fn existsByName(name: String) bool {
            return NameMappingMixin(T).exists(name);
        }

        pub fn byName(name: String) ?*SubType {
            if (NameMappingMixin(T).byName(name)) |c|
                return data.getPtr(c.id);

            return null;
        }

        pub fn idByName(name: String) ?Index {
            return NameMappingMixin(T).getIdOpt(name);
        }

        pub fn activateByName(name: String) void {
            ActivationMixin(T).activateByName(name);
        }

        pub fn deactivateByName(name: String) void {
            ActivationMixin(T).deactivateByName(name);
        }

        pub fn idIterator() std.AutoHashMap(Index, SubType).KeyIterator {
            return data.keyIterator();
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
