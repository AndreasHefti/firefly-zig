const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const StringBuffer = utils.StringBuffer;
const AspectGroup = utils.AspectGroup;
const EventDispatch = utils.EventDispatch;
const DynArray = utils.DynArray;
const BitSet = utils.BitSet;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const String = utils.String;

//////////////////////////////////////////////////////////////
//// Component global
//////////////////////////////////////////////////////////////
var INIT = false;
pub fn init() !void {
    defer INIT = true;
    if (INIT)
        return;

    COMPONENT_INTERFACE_TABLE = try DynArray(ComponentTypeInterface).new(api.COMPONENT_ALLOC);
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
pub const ComponentAspectGroup = AspectGroup(struct {
    pub const name = "Component";
});
pub const ComponentKind = ComponentAspectGroup.Kind;
pub const ComponentAspect = ComponentAspectGroup.Aspect;

const ComponentTypeInterface = struct {
    activate: *const fn (Index, bool) void,
    clear: *const fn (Index) void,
    deinit: *const fn () void,
    to_string: *const fn (*StringBuffer) void,
};
var COMPONENT_INTERFACE_TABLE: DynArray(ComponentTypeInterface) = undefined;

pub const Context = struct {
    name: String,
    activation: bool = true,
    name_mapping: bool = true,
    subscription: bool = true,
    processing: bool = true,
};

pub fn Trait(comptime T: type, comptime context: Context) type {
    return struct {

        // component type fields
        pub const COMPONENT_TYPE_NAME = context.name;
        pub const pool = ComponentPool(T);
        pub var aspect: *const ComponentAspect = undefined;

        pub fn isInitialized() bool {
            return pool._type_init;
        }

        pub fn count() usize {
            return pool.items.slots.count();
        }

        pub fn new(t: T) Index {
            return pool.register(t).id;
        }

        pub fn newAnd(t: T) *T {
            return pool.register(t);
        }

        pub fn exists(id: Index) bool {
            return pool.items.exists(id);
        }

        // TODO make it optional?
        pub fn byId(id: Index) *T {
            return pool.items.get(id).?;
        }

        pub fn nextId(id: Index) ?Index {
            return pool.items.slots.nextSetBit(id);
        }

        pub fn disposeById(id: Index) void {
            pool.clear(id);
        }

        // optional component type features
        pub usingnamespace if (context.name_mapping) NameMappingTrait(T, @This()) else struct {};
        pub usingnamespace if (context.activation) ActivationTrait(T, @This()) else struct {};
        pub usingnamespace if (context.subscription) SubscriptionTrait(T, @This()) else struct {};
        pub usingnamespace if (context.processing) ProcessingTrait(T, @This()) else struct {};
    };
}

fn SubscriptionTrait(comptime _: type, comptime adapter: anytype) type {
    return struct {
        pub fn subscribe(listener: ComponentListener) void {
            if (adapter.pool.eventDispatch) |*ed| ed.register(listener);
        }

        pub fn unsubscribe(listener: ComponentListener) void {
            if (adapter.pool.eventDispatch) |*ed| ed.unregister(listener);
        }
    };
}

fn NameMappingTrait(comptime T: type, comptime adapter: anytype) type {
    return struct {
        pub fn existsName(name: String) bool {
            if (adapter.pool.name_mapping) |*nm| {
                return nm.contains(name);
            }
            return false;
        }

        pub fn byName(name: String) ?*T {
            if (adapter.pool.name_mapping) |*nm| {
                if (nm.get(name)) |id|
                    return adapter.pool.items.get(id);
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

fn ActivationTrait(comptime T: type, comptime adapter: anytype) type {
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
            return adapter.pool.active_mapping.isSet(index);
        }
        pub fn isActive(self: T) bool {
            return adapter.pool.active_mapping.isSet(self.id);
        }
        pub fn activeCount() usize {
            return adapter.pool.active_mapping.count();
        }

        pub fn nextActiveId(id: Index) ?Index {
            return adapter.pool.active_mapping.nextSetBit(id);
        }

        pub fn activate(self: *T) *T {
            if (self.id == UNDEF_INDEX)
                return self;

            activateById(self.id, true);
            return self;
        }
    };
}

fn ProcessingTrait(comptime T: type, comptime adapter: anytype) type {
    return struct {
        pub fn processActive(f: *const fn (*const T) void) void {
            var i: Index = 0;
            while (adapter.pool.active_mapping.nextSetBit(i)) |next| {
                f(adapter.pool.items.get(next).?);
                i = next + 1;
            }
        }

        pub fn processBitSet(indices: *BitSet, f: *const fn (*const T) void) void {
            var i: Index = 0;
            while (indices.nextSetBit(i)) |next| {
                f(adapter.pool.items.get(next));
                i = next + 1;
            }
        }

        fn processIndexed(indices: []Index, f: *const fn (*const T) void) void {
            for (indices) |i| {
                f(adapter.pool.items.get(i));
            }
        }
    };
}

pub fn registerComponent(comptime T: type) void {
    ComponentPool(T).init();
}

pub fn deinitComponent(comptime T: type) void {
    ComponentPool(T).deinit();
}

pub inline fn checkValidity(any_component: anytype) void {
    if (!checkComponentValidity(any_component))
        @panic("Invalid component type");
}

pub fn checkComponentValidity(any_component: anytype) bool {
    const info: std.builtin.Type = @typeInfo(@TypeOf(any_component));
    const c_type = switch (info) {
        .Pointer => @TypeOf(any_component.*),
        .Struct => @TypeOf(any_component),
        else => {
            std.log.err("Invalid type component: {any}", .{any_component});
            return false;
        },
    };

    if (!@hasField(c_type, "id")) {
        std.log.warn("Invalid component. No id field: {any}", .{any_component});
        return false;
    }

    if (any_component.id == utils.UNDEF_INDEX) {
        std.log.warn("Invalid component. Undefined id: {any}", .{any_component});
        return false;
    }

    return true;
}

//////////////////////////////////////////////////////////////
//// Component Event Handling
//////////////////////////////////////////////////////////////

pub const ComponentListener = *const fn (ComponentEvent) void;
pub const ActionType = enum {
    NONE,
    CREATED,
    ACTIVATED,
    DEACTIVATING,
    DISPOSING,

    pub fn format(
        self: ActionType,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll(switch (self) {
            .NONE => "NONE",
            .CREATED => "CREATED",
            .ACTIVATED => "ACTIVATED",
            .DEACTIVATING => "DEACTIVATING",
            .DISPOSING => "DISPOSING",
        });
    }
};

pub const ComponentEvent = struct {
    event_type: ActionType = .NONE,
    c_id: ?Index = null,

    pub fn format(
        self: ComponentEvent,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Event[ type: {any}, id: {?d}]", .{ self.event_type, self.c_id });
    }
};

//////////////////////////////////////////////////////////////
//// Component Pooling
//////////////////////////////////////////////////////////////

pub fn ComponentPool(comptime T: type) type {

    // component type constraints and function references
    comptime var has_aspect: bool = false;
    comptime var has_new: bool = false;
    comptime var has_exists: bool = false;
    comptime var has_existsName: bool = false;
    comptime var has_byId: bool = false;
    comptime var has_byName: bool = false;
    comptime var has_activateById: bool = false;
    comptime var has_activateByName: bool = false;
    comptime var has_disposeById: bool = false;
    comptime var has_disposeByName: bool = false;
    comptime var has_subscribe: bool = false;
    comptime var has_name_mapping: bool = false;

    // component type init/deinit functions
    comptime var has_component_type_init: bool = false;
    comptime var has_component_type_deinit: bool = false;

    // component member function interceptors
    comptime var has_construct: bool = false;
    comptime var has_activation: bool = false;
    comptime var has_destruct: bool = false;

    comptime {
        if (!trait.is(.Struct)(T))
            @compileError("Expects component type is a struct.");
        if (!trait.hasDecls(T, .{"COMPONENT_TYPE_NAME"}))
            @compileError("Expects component type to have field: COMPONENT_TYPE_NAME: String, that defines a unique name of the component type.");
        if (!trait.hasField("id")(T))
            @compileError("Expects component type to have field: id: Index, that holds the index-id of the component");
        if (has_name_mapping and !trait.hasField("name")(T))
            @compileError("Expects component type to have field: name: String, that holds the name of the component");

        has_name_mapping = trait.hasField("name")(T);
        has_aspect = trait.hasDecls(T, .{"type_aspect"});
        has_new = trait.hasDecls(T, .{"new"});
        has_exists = trait.hasDecls(T, .{"exists"});
        has_existsName = trait.hasDecls(T, .{"existsName"});
        has_disposeById = trait.hasDecls(T, .{"disposeById"});
        has_disposeByName = trait.hasDecls(T, .{"disposeByName"});
        has_byId = trait.hasDecls(T, .{"byId"});
        has_byName = has_name_mapping and trait.hasDecls(T, .{"byName"});
        has_activateById = trait.hasDecls(T, .{"activateById"});
        has_activateByName = has_name_mapping and trait.hasDecls(T, .{"activateByName"});
        has_subscribe = trait.hasDecls(T, .{"subscribe"});
        has_component_type_init = trait.hasDecls(T, .{"componentTypeInit"});
        has_component_type_deinit = trait.hasDecls(T, .{"componentTypeDeinit"});
        has_construct = trait.hasDecls(T, .{"construct"});
        has_activation = trait.hasDecls(T, .{"activation"});
        has_destruct = trait.hasDecls(T, .{"destruct"});
    }

    return struct {
        const Self = @This();

        // ensure type based singleton
        var _type_init = false;

        // internal state
        var items: DynArray(T) = undefined;
        // mappings
        var active_mapping: BitSet = undefined;
        var name_mapping: ?StringHashMap(Index) = null;
        // events
        var event: ?ComponentEvent = null;
        var eventDispatch: ?EventDispatch(ComponentEvent) = null;

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

            items = DynArray(T).new(api.COMPONENT_ALLOC) catch @panic("Init items failed");
            active_mapping = BitSet.newEmpty(api.COMPONENT_ALLOC, 64) catch @panic("Init active mapping failed");
            ComponentAspectGroup.applyAspect(T, T.COMPONENT_TYPE_NAME);

            if (has_subscribe) {
                event = ComponentEvent{};
                eventDispatch = EventDispatch(ComponentEvent).new(api.COMPONENT_ALLOC);
            }

            if (has_name_mapping)
                name_mapping = StringHashMap(Index).init(api.COMPONENT_ALLOC);

            if (has_component_type_init) {
                T.componentTypeInit() catch {
                    std.log.err("Failed to initialize component of type: {any}", .{T});
                };
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
            active_mapping.deinit();

            if (eventDispatch) |*ed| {
                ed.deinit();
                eventDispatch = null;
                event = null;
            }

            if (name_mapping) |*nm| nm.deinit();
            if (has_aspect) T.type_aspect = undefined;
        }

        fn register(c: T) *T {
            var id = items.add(c);
            if (items.get(id)) |result| {
                result.id = id;

                if (name_mapping) |*nm| {
                    if (result.name) |n| {
                        if (nm.contains(n))
                            @panic("Component name already exists");
                        nm.put(n, id) catch unreachable;
                    }
                }

                if (has_construct)
                    result.construct();

                notify(ActionType.CREATED, id);
                return result;
            } else unreachable;
        }

        fn activate(id: Index, a: bool) void {
            active_mapping.setValue(id, a);
            if (has_activation)
                if (items.get(id)) |v| v.activation(a);
            notify(if (a) ActionType.ACTIVATED else ActionType.DEACTIVATING, id);
        }

        pub fn clearAll() void {
            var i: Index = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(next);
                i = next + 1;
            }
        }

        fn clear(id: Index) void {
            if (active_mapping.isSet(id))
                activate(id, false);
            notify(ActionType.DISPOSING, id);

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
                active_mapping.setValue(id, false);
                items.delete(id);
            }
        }

        fn toString(string_buffer: *StringBuffer) void {
            string_buffer.print("\n  {s} size: {d}", .{ T.COMPONENT_TYPE_NAME, items.slots.count() });
            var next = items.slots.nextSetBit(0);
            while (next) |i| {
                string_buffer.print("\n    {s} {any}", .{
                    if (active_mapping.isSet(i)) "(a)" else "(x)",
                    items.get(i),
                });
                next = items.slots.nextSetBit(i + 1);
            }
        }

        fn notify(event_type: ActionType, id: Index) void {
            if (event) |*e| {
                e.event_type = event_type;
                e.c_id = id;
                eventDispatch.?.notify(e.*);
            }
        }
    };
}

pub fn print(string_buffer: *StringBuffer) void {
    string_buffer.print("\nComponents:", .{});
    var next = COMPONENT_INTERFACE_TABLE.slots.nextSetBit(0);
    while (next) |i| {
        if (COMPONENT_INTERFACE_TABLE.get(i)) |interface| interface.to_string(string_buffer);
        next = COMPONENT_INTERFACE_TABLE.slots.nextSetBit(i + 1);
    }
}
