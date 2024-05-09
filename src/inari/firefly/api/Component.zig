const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;

const ControlNode = api.ControlNode;
const UpdateEvent = api.UpdateEvent;
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
pub const ComponentAspect = *const ComponentAspectGroup.Aspect;

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
        pub var aspect: ComponentAspect = undefined;

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
        const empty_struct = struct {};
        pub usingnamespace if (context.name_mapping) NameMappingTrait(T, @This()) else empty_struct;
        pub usingnamespace if (context.activation) ActivationTrait(T, @This()) else empty_struct;
        pub usingnamespace if (context.subscription) SubscriptionTrait(T, @This()) else empty_struct;
        pub usingnamespace if (context.processing) ProcessingTrait(T, @This()) else empty_struct;
        pub usingnamespace if (@hasField(T, "controls")) ControlTrait(T, @This()) else empty_struct;
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
    };
}

fn ProcessingTrait(comptime T: type, comptime adapter: anytype) type {
    return struct {
        pub fn processActive(f: *const fn (*T) void) void {
            if (adapter.pool.active_mapping) |*am| {
                var next = am.nextSetBit(0);
                while (next) |i| {
                    f(adapter.pool.items.get(i).?);
                    next = am.nextSetBit(i + 1);
                }
            }
        }

        pub fn processBitSet(indices: *BitSet, f: *const fn (*T) void) void {
            var i: Index = 0;
            while (indices.nextSetBit(i)) |next| {
                f(adapter.pool.items.get(next));
                i = next + 1;
            }
        }

        fn processIndexed(indices: []Index, f: *const fn (*T) void) void {
            for (indices) |i| {
                f(adapter.pool.items.get(i));
            }
        }
    };
}

fn ControlTrait(comptime T: type, comptime adapter: anytype) type {
    return struct {
        fn update(self: *T, id: Index) void {
            if (self.controls) |c| c.update(adapter.byId(id));
        }

        pub fn withControl(self: *T, control: ControlNode(T).Control) *T {
            if (self.controls) |c|
                c.add(control)
            else
                self.controls = ControlNode(T).new(control);
            return self;
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
    //const has_aspect: bool = @hasDecl(T, "type_aspect");
    const has_subscribe: bool = @hasDecl(T, "subscribe");
    const has_active_mapping: bool = @hasDecl(T, "activeCount");
    const has_name_mapping: bool = @hasField(T, "name");

    // component type init/deinit functions
    const has_component_type_init: bool = @hasDecl(T, "componentTypeInit");
    const has_component_type_deinit: bool = @hasDecl(T, "componentTypeDeinit");

    // component member function interceptors
    const has_construct: bool = @hasDecl(T, "construct");
    const has_activation: bool = @hasDecl(T, "activation");
    const has_destruct = @hasDecl(T, "destruct");

    // control
    const has_controls: bool = @hasField(T, "controls");

    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects component type is a struct.");
        if (!@hasDecl(T, "COMPONENT_TYPE_NAME"))
            @compileError("Expects component type to have field: COMPONENT_TYPE_NAME: String, that defines a unique name of the component type.");
        if (!@hasField(T, "id"))
            @compileError("Expects component type to have field: id: Index, that holds the index-id of the component");

        // const typeInfo = @typeInfo(T);
        // @compileLog(.{typeInfo.Struct.fields});
        // if (has_name_mapping and @TypeOf(@field(T, "name")) != std.builtin.Type.Optional) {
        //     @compileError("Expects component type to have optional field: name: ?String, that holds the name of the component");
        // }
    }

    return struct {
        const Self = @This();

        // ensure type based singleton
        var _type_init = false;

        // internal state
        var items: DynArray(T) = undefined;
        // mappings
        var active_mapping: ?BitSet = undefined;
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
            ComponentAspectGroup.applyAspect(T, T.COMPONENT_TYPE_NAME);

            if (has_active_mapping)
                active_mapping = BitSet.newEmpty(api.COMPONENT_ALLOC, 64) catch @panic("Init active mapping failed");

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

            if (has_controls)
                api.subscribeUpdate(update);
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
                event = null;
            }

            if (name_mapping) |*nm| nm.deinit();
            //if (has_aspect) T.type_aspect = undefined;
            if (has_controls) api.unsubscribeUpdate(update);
        }

        fn update(_: UpdateEvent) void {
            if (active_mapping) |*am| {
                var next = am.nextSetBit(0);
                while (next) |i| {
                    if (items.get(i)) |c|
                        c.update(c.id);
                    next = am.nextSetBit(i + 1);
                }
            }
        }

        fn register(c: T) *T {
            const id = items.add(c);
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
            if (active_mapping) |*am| {
                am.setValue(id, a);
                if (has_activation)
                    if (items.get(id)) |v| v.activation(a);
                notify(if (a) ActionType.ACTIVATED else ActionType.DEACTIVATING, id);
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
                notify(ActionType.DISPOSING, id);
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

        fn toString(string_buffer: *StringBuffer) void {
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
