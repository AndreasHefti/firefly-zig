const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const StringBuffer = utils.StringBuffer;
const Aspect = utils.Aspect;
const AspectGroup = utils.AspectGroup;
const EventDispatch = utils.EventDispatch;
const DynArray = utils.DynArray;
const BitSet = utils.BitSet;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;
const String = utils.String;

//////////////////////////////////////////////////////////////
//// Component global
//////////////////////////////////////////////////////////////
var INIT = false;
pub fn init() !void {
    defer INIT = true;
    if (INIT)
        return;

    API.COMPONENT_INTERFACE_TABLE = try DynArray(API.ComponentTypeInterface).new(api.COMPONENT_ALLOC, null);
    API.COMPONENT_ASPECT_GROUP = try AspectGroup.new("COMPONENT_ASPECT_GROUP");
}

pub fn deinit() void {
    defer INIT = false;
    if (!INIT)
        return;

    // deinit all registered component pools via aspect interface mapping
    for (0..API.COMPONENT_ASPECT_GROUP._size) |i| {
        API.COMPONENT_INTERFACE_TABLE.get(API.COMPONENT_ASPECT_GROUP.aspects[i].index).deinit();
    }
    API.COMPONENT_INTERFACE_TABLE.deinit();
    API.COMPONENT_INTERFACE_TABLE = undefined;

    AspectGroup.dispose("COMPONENT_ASPECT_GROUP");
    API.COMPONENT_ASPECT_GROUP = undefined;
}

//////////////////////////////////////////////////////////////
//// Component API
//////////////////////////////////////////////////////////////
pub const API = struct {
    var COMPONENT_INTERFACE_TABLE: DynArray(ComponentTypeInterface) = undefined;
    pub var COMPONENT_ASPECT_GROUP: *AspectGroup = undefined;

    const SUBSCRIBE_DECL = *const fn (ComponentListener) void;
    const UNSUBSCRIBE_DECL = *const fn (ComponentListener) void;

    pub const ComponentTypeInterface = struct {
        activate: *const fn (Index, bool) void,
        clear: *const fn (Index) void,
        deinit: *const fn () void,
        to_string: *const fn (*StringBuffer) void,
    };

    pub const Context = struct {
        name: String,
        activation: bool = true,
        name_mapping: bool = true,
        subscription: bool = true,
    };

    fn SubscriptionAPI(comptime _: type) type {
        return struct {
            pub var subscribe: SUBSCRIBE_DECL = undefined;
            pub var unsubscribe: UNSUBSCRIBE_DECL = undefined;
        };
    }

    fn NameMappingAPI(comptime T: type) type {
        return struct {
            pub var existsName: *const fn (String) bool = undefined;
            pub var byName: *const fn (String) *const T = undefined;
            pub var disposeByName: *const fn (String) void = undefined;
        };
    }

    fn ActivationAPI(comptime _: type) type {
        return struct {
            pub var activateById: *const fn (Index, bool) void = undefined;
            pub var activateByName: *const fn (String, bool) void = undefined;
        };
    }

    pub fn Adapter(comptime T: type, comptime context: Context) type {
        return struct {

            // component type fields
            pub const NULL_VALUE = T{};
            pub const COMPONENT_TYPE_NAME = context.name;
            pub const pool = ComponentPool(T);
            pub var type_aspect: *Aspect = undefined;

            // component type pool function references
            pub var new: *const fn (T) *T = undefined;
            pub var exists: *const fn (Index) bool = undefined;
            pub var get: *const fn (Index) *T = undefined;
            pub var byId: *const fn (Index) *const T = undefined;
            pub var disposeById: *const fn (Index) void = undefined;

            // optional component type feature function references
            pub usingnamespace if (context.name_mapping) NameMappingAPI(T) else struct {};
            pub usingnamespace if (context.activation) ActivationAPI(T) else struct {};
            pub usingnamespace if (context.subscription) SubscriptionAPI(T) else struct {};
        };
    }

    pub fn registerComponent(comptime T: type) void {
        ComponentPool(T).init();
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
            std.log.err("Invalid component. No id field: {any}", .{any_component});
            return false;
        }

        if (@intFromPtr(c_type.type_aspect) == 0) {
            std.log.err("Invalid component. aspect not initialized: {any}", .{any_component});
            return false;
        } else if (!c_type.type_aspect.isOfGroup(COMPONENT_ASPECT_GROUP)) {
            std.log.err("Invalid component. AspectGroup mismatch: {any}", .{any_component});
            return false;
        }

        if (any_component.id == utils.UNDEF_INDEX) {
            std.log.err("Invalid component. Undefined id: {any}", .{any_component});
            return false;
        }

        return true;
    }
};

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
    event_type: ActionType = ActionType.NONE,
    c_id: Index = UNDEF_INDEX,

    pub fn format(
        self: ComponentEvent,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Event[ type: {any}, id: {d}]", .{ self.event_type, self.c_id });
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
    comptime var has_get: bool = false;
    comptime var has_byId: bool = false;
    comptime var has_byName: bool = false;
    comptime var has_activateById: bool = false;
    comptime var has_activateByName: bool = false;
    comptime var has_disposeById: bool = false;
    comptime var has_disposeByName: bool = false;
    comptime var has_subscribe: bool = false;
    comptime var has_name_mapping: bool = false;

    // component type init/deinit functions
    comptime var has_init: bool = false;
    comptime var has_deinit: bool = false;

    // component member function interceptors
    comptime var has_construct: bool = false;
    comptime var has_activation: bool = false;
    comptime var has_destruct: bool = false;

    comptime {
        if (!trait.is(.Struct)(T))
            @compileError("Expects component type is a struct.");
        if (!trait.hasDecls(T, .{"NULL_VALUE"}))
            @compileError("Expects component type to have member named 'NULL_VALUE' that is the types null value.");
        if (!trait.hasDecls(T, .{"COMPONENT_TYPE_NAME"}))
            @compileError("Expects component type to have member named 'COMPONENT_TYPE_NAME' that defines a unique name of the component type.");
        if (!trait.hasField("id")(T))
            @compileError("Expects component type to have field named id");

        has_name_mapping = trait.hasField("name")(T);
        has_aspect = trait.hasDecls(T, .{"type_aspect"});
        has_new = trait.hasDecls(T, .{"new"});
        has_exists = trait.hasDecls(T, .{"exists"});
        has_existsName = trait.hasDecls(T, .{"existsName"});
        has_get = trait.hasDecls(T, .{"get"});
        has_disposeById = trait.hasDecls(T, .{"disposeById"});
        has_disposeByName = trait.hasDecls(T, .{"disposeByName"});
        has_byId = trait.hasDecls(T, .{"byId"});
        has_byName = has_name_mapping and trait.hasDecls(T, .{"byName"});
        has_activateById = trait.hasDecls(T, .{"activateById"});
        has_activateByName = has_name_mapping and trait.hasDecls(T, .{"activateByName"});
        has_subscribe = trait.hasDecls(T, .{"subscribe"}) and @TypeOf(T.subscribe) == API.SUBSCRIBE_DECL;
        if (has_subscribe)
            if (!trait.hasDecls(T, .{"unsubscribe"}) or @TypeOf(T.unsubscribe) != API.UNSUBSCRIBE_DECL)
                @compileError("Expects component type to have member named 'unsubscribe' when there is subscribe.");

        has_init = trait.hasDecls(T, .{"init"});
        has_deinit = trait.hasDecls(T, .{"deinit"});
        has_construct = trait.hasDecls(T, .{"construct"});
        has_activation = trait.hasDecls(T, .{"activation"});
        has_destruct = trait.hasDecls(T, .{"destruct"});
    }

    return struct {
        const Self = @This();
        // ensure type based singleton
        var initialized = false;
        // internal state
        var items: DynArray(T) = undefined;
        // mappings
        var active_mapping: BitSet = undefined;
        var name_mapping: ?StringHashMap(Index) = null;
        // events
        var event: ?ComponentEvent = null;
        var eventDispatch: ?EventDispatch(ComponentEvent) = null;
        // external state
        pub var c_aspect: *Aspect = undefined;

        pub fn init() void {
            if (initialized)
                return;

            errdefer Self.deinit();
            defer {
                API.COMPONENT_INTERFACE_TABLE.set(
                    API.ComponentTypeInterface{
                        .activate = Self.activate,
                        .clear = Self.clear,
                        .deinit = Self.deinit,
                        .to_string = toString,
                    },
                    c_aspect.index,
                );
                initialized = true;
            }

            items = DynArray(T).new(api.COMPONENT_ALLOC, T.NULL_VALUE) catch @panic("Init items failed");
            active_mapping = BitSet.newEmpty(api.COMPONENT_ALLOC, 64) catch @panic("Init active mapping failed");
            c_aspect = API.COMPONENT_ASPECT_GROUP.getAspect(T.COMPONENT_TYPE_NAME);

            if (has_subscribe) {
                event = ComponentEvent{};
                eventDispatch = EventDispatch(ComponentEvent).new(api.COMPONENT_ALLOC);
                T.subscribe = Self.subscribe;
                T.unsubscribe = Self.unsubscribe;
            }

            if (has_name_mapping) name_mapping = StringHashMap(Index).init(api.COMPONENT_ALLOC);
            if (has_aspect) T.type_aspect = c_aspect;
            if (has_new) T.new = Self.register;
            if (has_exists) T.exists = Self.exists;
            if (has_existsName) T.existsName = Self.existsName;
            if (has_get) T.get = Self.get;
            if (has_disposeById) T.disposeById = Self.clear;
            if (has_name_mapping and has_disposeByName) T.disposeByName = Self.clearByName;
            if (has_byId) T.byId = Self.byId;
            if (has_name_mapping and has_byName) T.byName = Self.byName;
            if (has_activateById) T.activateById = Self.activate;
            if (has_name_mapping and has_activateByName) T.activateByName = Self.activateByName;

            if (has_init) T.init() catch {
                std.log.err("Failed to initialize component of type: {any}", .{T});
            };
        }

        /// Release all allocated memory.
        pub fn deinit() void {
            defer initialized = false;
            if (!initialized)
                return;

            if (has_deinit)
                T.deinit();

            c_aspect = undefined;
            items.deinit();
            active_mapping.deinit();

            if (eventDispatch) |*ed| {
                ed.deinit();
                eventDispatch = null;
                event = null;
            }

            if (name_mapping) |*nm| nm.deinit();
            if (has_aspect) T.type_aspect = undefined;
            if (has_new) T.new = undefined;
            if (has_disposeById) T.disposeById = undefined;
            if (has_name_mapping and has_disposeByName) T.disposeByName = undefined;
            if (has_byId) T.byId = undefined;
            if (has_name_mapping and has_byName) T.byName = undefined;
            if (has_activateById) T.activateById = undefined;
            if (has_name_mapping and has_activateByName) T.activateByName = undefined;
        }

        pub fn typeCheck(a: *Aspect) bool {
            if (!initialized)
                return false;

            return c_aspect.index == a.index;
        }

        pub fn count() usize {
            return items.slots.count();
        }

        pub fn activeCount() usize {
            return active_mapping.count();
        }

        pub fn subscribe(listener: ComponentListener) void {
            if (eventDispatch) |*ed| ed.register(listener);
        }

        pub fn unsubscribe(listener: ComponentListener) void {
            if (eventDispatch) |*ed| ed.unregister(listener);
        }

        pub fn register(c: T) *T {
            var id = items.add(c);
            var result = items.get(id);
            result.id = id;

            if (name_mapping) |*nm| {
                if (!std.mem.eql(u8, c.name, NO_NAME))
                    nm.put(result.name, id) catch unreachable;
            }

            if (has_construct)
                result.construct();

            notify(ActionType.CREATED, id);
            return result;
        }

        pub fn nextId(index: usize) ?usize {
            return items.slots.nextSetBit(index);
        }

        pub fn nextActiveId(index: usize) ?usize {
            return active_mapping.nextSetBit(index);
        }

        pub fn exists(id: Index) bool {
            return items.exists(id);
        }

        pub fn get(id: Index) *T {
            const ret = items.get(id);
            if (ret.id == UNDEF_INDEX) {
                std.log.err("No Component with id: {d} of type: {s}", .{ id, T.COMPONENT_TYPE_NAME });
                @panic("Component does not exist");
            }
            return ret;
        }

        pub fn byId(id: Index) *const T {
            return items.get(id);
        }

        pub fn existsName(name: String) bool {
            if (name_mapping) |*nm| {
                return nm.contains(name);
            }
            return false;
        }

        pub fn byName(name: String) *const T {
            if (name_mapping) |*nm| {
                if (nm.get(name)) |id| {
                    return items.get(id);
                }
            }
            return &T.NULL_VALUE;
        }

        pub fn activate(id: Index, a: bool) void {
            active_mapping.setValue(id, a);
            if (has_activation)
                get(id).activation(a);
            notify(if (a) ActionType.ACTIVATED else ActionType.DEACTIVATING, id);
        }

        pub fn activateByName(name: String, a: bool) void {
            if (name_mapping) |*nm| {
                if (nm.get(name)) |id| {
                    activate(id, a);
                }
            }
        }

        pub fn isActive(id: Index) bool {
            return active_mapping.isSet(id);
        }

        pub fn clearAll() void {
            var i: Index = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(next);
                i = next + 1;
            }
        }

        pub fn clear(id: Index) void {
            if (isActive(id))
                activate(id, false);
            notify(ActionType.DISPOSING, id);
            if (has_destruct)
                get(id).destruct();
            active_mapping.setValue(id, false);
            items.reset(id);
        }

        pub fn clearByName(name: String) void {
            if (name_mapping) |*nm| {
                if (nm.get(name)) |id| clear(id);
            }
        }

        pub fn processActive(f: *const fn (*const T) void) void {
            var i: Index = 0;
            while (active_mapping.nextSetBit(i)) |next| {
                f(items.get(next));
                i = next + 1;
            }
        }

        pub fn processBitSet(indices: *BitSet, f: *const fn (*const T) void) void {
            var i: Index = 0;
            while (indices.nextSetBit(i)) |next| {
                f(items.get(next));
                i = next + 1;
            }
        }

        pub fn processIndexed(indices: []Index, f: *const fn (*const T) void) void {
            for (indices) |i| {
                f(items.get(i));
            }
        }

        fn toString(string_buffer: *StringBuffer) void {
            string_buffer.print("\n  {s} size: {d}", .{ c_aspect.name, items.slots.count() });
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
    var next = API.COMPONENT_INTERFACE_TABLE.slots.nextSetBit(0);
    while (next) |i| {
        API.COMPONENT_INTERFACE_TABLE.get(i).to_string(string_buffer);
        next = API.COMPONENT_INTERFACE_TABLE.slots.nextSetBit(i + 1);
    }
}
