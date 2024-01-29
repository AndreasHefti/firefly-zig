const std = @import("std");
const firefly = @import("api.zig").firefly;

const StringBuffer = firefly.utils.StringBuffer;
const trait = std.meta.trait;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const AspectGroup = firefly.utils.aspect.AspectGroup;
const EventDispatch = firefly.utils.event.EventDispatch;
const aspect = firefly.utils.aspect;
const Aspect = aspect.Aspect;
const DynArray = firefly.utils.dynarray.DynArray;
const BitSet = firefly.utils.bitset.BitSet;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_NAME = firefly.utils.NO_NAME;
const String = firefly.utils.String;

// component global variables and state
var INIT = false;
var COMPONENT_INTERFACE_TABLE: DynArray(ComponentTypeInterface) = undefined;
var ENTITY_COMPONENT_INTERFACE_TABLE: DynArray(ComponentTypeInterface) = undefined;

// public aspect groups
pub var COMPONENT_ASPECT_GROUP: *AspectGroup = undefined;
pub var ENTITY_COMPONENT_ASPECT_GROUP: *AspectGroup = undefined;

// module init
pub fn init() !void {
    defer INIT = true;
    if (INIT)
        return;

    COMPONENT_INTERFACE_TABLE = try DynArray(ComponentTypeInterface).init(firefly.COMPONENT_ALLOC, null);
    ENTITY_COMPONENT_INTERFACE_TABLE = try DynArray(ComponentTypeInterface).init(firefly.COMPONENT_ALLOC, null);
    COMPONENT_ASPECT_GROUP = try aspect.newAspectGroup("COMPONENT_ASPECT_GROUP");
    ENTITY_COMPONENT_ASPECT_GROUP = try aspect.newAspectGroup("ENTITY_COMPONENT_ASPECT_GROUP");
}

// module deinit
pub fn deinit() void {
    defer INIT = false;
    if (!INIT)
        return;

    // deinit all registered component pools via aspect interface mapping
    for (0..COMPONENT_ASPECT_GROUP._size) |i| {
        COMPONENT_INTERFACE_TABLE.get(COMPONENT_ASPECT_GROUP.aspects[i].index).deinit();
    }
    COMPONENT_INTERFACE_TABLE.deinit();
    COMPONENT_INTERFACE_TABLE = undefined;

    // deinit all registered entity component pools via aspect interface mapping
    for (0..ENTITY_COMPONENT_ASPECT_GROUP._size) |i| {
        ENTITY_COMPONENT_INTERFACE_TABLE.get(ENTITY_COMPONENT_ASPECT_GROUP.aspects[i].index).deinit();
    }
    ENTITY_COMPONENT_INTERFACE_TABLE.deinit();
    ENTITY_COMPONENT_INTERFACE_TABLE = undefined;

    aspect.disposeAspectGroup("COMPONENT_ASPECT_GROUP");
    COMPONENT_ASPECT_GROUP = undefined;
    aspect.disposeAspectGroup("ENTITY_COMPONENT_TYPE_ASPECT_GROUP");
    ENTITY_COMPONENT_ASPECT_GROUP = undefined;
}

pub const ComponentId = struct {
    aspect: *Aspect = undefined,
    index: usize = undefined,
};

pub const ComponentTypeInterface = struct {
    clear: *const fn (usize) void,
    deinit: *const fn () void,
    to_string: *const fn (*StringBuffer) void,
};

// Component Event Handling
pub const ActionType = enum {
    NONE,
    Created,
    Activated,
    Deactivated,
    Disposing,

    pub fn format(
        self: ActionType,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll(switch (self) {
            .NONE => "NONE",
            .Created => "Created",
            .Activated => "Activated",
            .Deactivated => "Deactivated",
            .Disposing => "Disposing",
        });
    }
};

pub const Event = struct {
    event_type: ActionType = ActionType.NONE,
    c_index: usize = UNDEF_INDEX,

    pub fn format(
        self: Event,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Event[ type: {any}, index: {d}]", .{ self.event_type, self.c_index });
    }
};

pub const EventListener = *const fn (Event) void;

pub fn registerComponent(comptime T: type) void {
    ComponentPool(T).init();
}

pub fn registerEntityComponent(comptime T: type) void {
    EntityComponentPool(T).init();
}

pub fn ComponentPool(comptime T: type) type {
    // check component type constraints and function refs
    comptime var has_aspect: bool = false;
    comptime var has_new: bool = false;
    comptime var has_dispose: bool = false;
    comptime var has_byId: bool = false;
    comptime var has_byName: bool = false;
    comptime var has_activateById: bool = false;
    comptime var has_activateByName: bool = false;
    comptime var has_subscribe: bool = false;
    comptime var has_name_mapping: bool = false;
    comptime var has_deinit: bool = false;
    // component function interceptors
    comptime var has_onNew: bool = false;
    comptime var has_onActivation: bool = false;
    comptime var has_onDispose: bool = false;
    comptime {
        if (!trait.is(.Struct)(T)) @compileError("Expects component type is a struct.");
        if (!trait.hasDecls(T, .{"null_value"})) @compileError("Expects component type to have member named 'null_value' that is the types null value.");
        if (!trait.hasDecls(T, .{"component_name"})) @compileError("Expects component type to have member named 'component_name' that defines a unique name of the component type.");
        has_name_mapping = trait.hasField("name")(T);
        has_aspect = trait.hasDecls(T, .{"type_aspect"});
        has_new = trait.hasDecls(T, .{"new"});
        has_dispose = trait.hasDecls(T, .{"dispose"});
        has_byId = trait.hasDecls(T, .{"byId"});
        has_byName = has_name_mapping and trait.hasDecls(T, .{"byName"});
        has_activateById = trait.hasDecls(T, .{"activateById"});
        has_activateByName = has_name_mapping and trait.hasDecls(T, .{"activateByName"});
        has_subscribe = trait.hasDecls(T, .{"subscribe"});
        if (has_subscribe) {
            if (!trait.hasDecls(T, .{"unsubscribe"})) @compileError("Expects component type to have member named 'unsubscribe' when there is subscribe.");
        }

        has_deinit = trait.hasDecls(T, .{"deinit"});
        has_onNew = trait.hasDecls(T, .{"onNew"});
        has_onActivation = trait.hasDecls(T, .{"onActivation"});
        has_onDispose = trait.hasDecls(T, .{"onDispose"});
    }

    return struct {
        const Self = @This();
        // ensure type based singleton
        var initialized = false;
        // internal state
        var items: DynArray(T) = undefined;
        // mappings
        var active_mapping: BitSet = undefined;
        var name_mapping: ?StringHashMap(usize) = null;
        // events
        var event: ?Event = null;
        var eventDispatch: ?EventDispatch(Event) = null;
        // external state
        pub var c_aspect: *Aspect = undefined;

        pub fn init() void {
            if (initialized)
                return;

            errdefer Self.deinit();
            defer {
                COMPONENT_INTERFACE_TABLE.set(
                    ComponentTypeInterface{
                        .clear = Self.clear,
                        .deinit = if (has_deinit) T.deinit else Self.deinit,
                        .to_string = toString,
                    },
                    c_aspect.index,
                );
                initialized = true;
            }

            items = DynArray(T).init(firefly.COMPONENT_ALLOC, T.null_value) catch @panic("Init items failed");
            active_mapping = BitSet.initEmpty(firefly.COMPONENT_ALLOC, 64) catch @panic("Init active mapping failed");
            c_aspect = COMPONENT_ASPECT_GROUP.getAspect(T.component_name);

            if (has_subscribe) {
                event = Event{};
                eventDispatch = EventDispatch(Event).init(firefly.COMPONENT_ALLOC);
                T.subscribe = Self.subscribe;
                T.unsubscribe = Self.unsubscribe;
            }

            if (has_name_mapping) name_mapping = StringHashMap(usize).init(firefly.COMPONENT_ALLOC);
            if (has_aspect) T.type_aspect = c_aspect;
            if (has_new) T.new = Self.register;
            if (has_dispose) T.dispose = Self.clear;
            if (has_byId) T.byId = Self.byId;
            if (has_byName) T.byName = Self.byName;
            if (has_activateById) T.activateById = Self.activate;
            if (has_activateByName) T.activateByName = Self.activateByName;
        }

        /// Release all allocated memory.
        pub fn deinit() void {
            defer initialized = false;
            if (!initialized)
                return;

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
            if (has_dispose) T.dispose = undefined;
            if (has_byId) T.byId = undefined;
            if (has_byName) T.byName = undefined;
            if (has_activateById) T.activateById = undefined;
            if (has_activateByName) T.activateByName = undefined;
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

        pub fn subscribe(listener: *const fn (Event) void) void {
            if (eventDispatch) |*ed| ed.register(listener);
        }

        pub fn unsubscribe(listener: *const fn (Event) void) void {
            if (eventDispatch) |*ed| ed.unregister(listener);
        }

        pub fn register(c: T) *T {
            checkComponentTrait(c);

            var index = items.add(c);
            var result = items.get(index);
            result.index = index;

            if (name_mapping) |*nm| {
                if (!std.mem.eql(u8, c.name, NO_NAME))
                    nm.put(result.name, index) catch unreachable;
            }

            if (has_onNew) T.onNew(index);
            notify(ActionType.Created, index);
            return result;
        }

        pub fn byId(index: usize) *T {
            return items.get(index);
        }

        pub fn byName(name: String) ?*T {
            if (name_mapping) |*nm| {
                if (nm.get(name)) |index| {
                    return items.get(index);
                }
            }
            return null;
        }

        pub fn activate(index: usize, a: bool) void {
            active_mapping.setValue(index, a);
            if (has_onActivation) T.onActivation(index, a);
            notify(if (a) ActionType.Activated else ActionType.Deactivated, index);
        }

        pub fn activateByName(name: String, a: bool) void {
            if (name_mapping) |*nm| {
                if (nm.get(name)) |index| {
                    activate(index, a);
                }
            }
        }

        pub fn isActive(index: usize) bool {
            return active_mapping.isSet(index);
        }

        pub fn clearAll() void {
            var i: usize = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(i);
                i = next + 1;
            }
        }

        pub fn clear(index: usize) void {
            notify(ActionType.Disposing, index);
            if (has_onDispose) T.onDispose(index);
            active_mapping.setValue(index, false);
            items.reset(index);
        }

        pub fn processActive(f: *const fn (*T) void) void {
            var i: usize = 0;
            while (active_mapping.nextSetBit(i)) |next| {
                f(items.get(i));
                i = next + 1;
            }
        }

        pub fn processBitSet(indices: *BitSet, f: *const fn (*T) void) void {
            var i: usize = 0;
            while (indices.nextSetBit(i)) |next| {
                f(items.get(i));
                i = next + 1;
            }
        }

        pub fn processIndexed(indices: []usize, f: *const fn (*T) void) void {
            for (indices) |i| {
                f(items.get(i));
            }
        }

        fn toString(string_buffer: *StringBuffer) void {
            string_buffer.print("\n  {s} size: {d}", .{ c_aspect.name, items.slots.count() });
            var next = items.slots.nextSetBit(0);
            while (next) |i| {
                string_buffer.print("\n    {s} {any}", .{
                    if (active_mapping.isSet(i)) "a" else "x",
                    items.get(i),
                });
                next = items.slots.nextSetBit(i + 1);
            }
        }

        fn notify(event_type: ActionType, index: usize) void {
            if (event) |*e| {
                // Test if copy here affects performance (but it thread safe?)
                var ce = e.*;
                ce.event_type = event_type;
                ce.c_index = index;
                eventDispatch.?.notify(ce);
            }
        }

        fn checkComponentTrait(c: T) void {
            comptime {
                if (!trait.is(.Struct)(@TypeOf(c))) @compileError("Expects component is a struct.");
                if (!trait.hasField("index")(@TypeOf(c))) @compileError("Expects component to have field 'index'.");
            }
        }
    };
}

// Entity Components
pub fn clearAllEntityComponentsAt(index: usize) void {
    for (0..ENTITY_COMPONENT_ASPECT_GROUP._size) |i| {
        ENTITY_COMPONENT_INTERFACE_TABLE.get(ENTITY_COMPONENT_ASPECT_GROUP.aspects[i].index).clear(index);
    }
}

pub fn EntityComponentPool(comptime T: type) type {

    // check component type constraints
    comptime var has_aspect: bool = false;
    comptime var has_byId: bool = false;
    // component function interceptors
    comptime var has_onNew: bool = false;
    comptime var has_onDispose: bool = false;
    comptime {
        if (!trait.is(.Struct)(T)) @compileError("Expects component type is a struct.");
        if (!trait.hasDecls(T, .{"null_value"})) @compileError("Expects component type to have member named 'null_value' that is the types null value.");
        if (!trait.hasDecls(T, .{"component_name"})) @compileError("Expects component type to have member named 'component_name' that defines a unique name of the component type.");
        has_aspect = trait.hasDecls(T, .{"type_aspect"});
        has_byId = trait.hasDecls(T, .{"byId"});
        has_onNew = trait.hasDecls(T, .{"onNew"});
        has_onDispose = trait.hasDecls(T, .{"onDispose"});
    }

    return struct {
        const Self = @This();
        // ensure type based singleton
        var initialized = false;
        // internal state
        var items: DynArray(T) = undefined;
        // external state
        pub var c_aspect: *Aspect = undefined;

        pub fn init() void {
            if (initialized)
                return;

            errdefer Self.deinit();
            defer {
                ENTITY_COMPONENT_INTERFACE_TABLE.set(
                    ComponentTypeInterface{
                        .clear = Self.i_clear,
                        .deinit = T.deinit,
                        .to_string = toString,
                    },
                    c_aspect.index,
                );
                initialized = true;
            }

            items = DynArray(T).init(firefly.COMPONENT_ALLOC, T.null_value) catch @panic("Init items failed");
            c_aspect = ENTITY_COMPONENT_ASPECT_GROUP.getAspect(@typeName(T));

            if (has_aspect) T.type_aspect = c_aspect;
            if (has_byId) T.byId = Self.byId;
        }

        pub fn deinit() void {
            defer initialized = false;
            if (!initialized)
                return;

            c_aspect = undefined;
            items.deinit();

            if (has_aspect) T.type_aspect = undefined;
            if (has_byId) T.byId = undefined;
        }

        pub fn typeCheck(a: *Aspect) bool {
            if (!initialized)
                return false;

            return c_aspect.index == a.index;
        }

        pub fn count() usize {
            return items.slots.count();
        }

        pub fn register(c: *T, index: usize) *T {
            checkComponentTrait(c);
            c.index = index;
            items.set(c, index);
            if (has_onNew) T.onNew(index);
            return items.get(index);
        }

        pub fn get(index: usize) *T {
            return items.get(index);
        }

        pub fn clearAll() void {
            var i: usize = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(i);
                i = next + 1;
            }
        }

        pub fn clear(index: usize) void {
            if (has_onDispose) T.onDispose(index);
            items.reset(index);
        }

        fn toString() String {
            var string_builder = ArrayList(u8).init(firefly.ALLOC);
            defer string_builder.deinit();

            var writer = string_builder.writer();
            writer.print("\n  {s} size: {d}", .{ c_aspect.name, items.size() }) catch unreachable;
            var next = items.slots.nextSetBit(0);
            while (next) |i| {
                writer.print("\n   {any}", .{ "", items.get(i) }) catch unreachable;
                next = items.slots.nextSetBit(i + 1);
            }

            return string_builder.toOwnedSlice() catch unreachable;
        }

        fn checkComponentTrait(c: T) void {
            comptime {
                if (!trait.is(.Struct)(@TypeOf(c))) @compileError("Expects component is a struct.");
                if (!trait.hasField("index")(@TypeOf(c))) @compileError("Expects component to have field 'index'.");
            }
        }
    };
}

pub fn print(string_buffer: *StringBuffer) void {
    string_buffer.print("\nComponents:", .{});
    var next = COMPONENT_INTERFACE_TABLE.slots.nextSetBit(0);
    while (next) |i| {
        COMPONENT_INTERFACE_TABLE.get(i).to_string(string_buffer);
        next = COMPONENT_INTERFACE_TABLE.slots.nextSetBit(i + 1);
    }
}
