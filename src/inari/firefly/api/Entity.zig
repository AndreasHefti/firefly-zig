const std = @import("std");
const Allocator = std.mem.Allocator;
const trait = std.meta.trait;

const api = @import("api.zig"); // TODO module

const DynArray = api.utils.dynarray.DynArray;
const ArrayList = std.ArrayList;
const Component = api.Component;
const Kind = api.utils.aspect.Kind;
const aspect = api.utils.aspect;
const Aspect = aspect.Aspect;
const AspectGroup = aspect.AspectGroup;
const String = api.utils.String;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;
const Entity = @This();

// component type fields
pub const NULL_VALUE = Entity{};
pub const COMPONENT_NAME = "Entity";
pub const pool = Component.ComponentPool(Entity);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Entity) *Entity = undefined;
pub var exists: *const fn (Index) bool = undefined;
pub var existsName: *const fn (String) bool = undefined;
pub var get: *const fn (Index) *Entity = undefined;
pub var byId: *const fn (Index) *const Entity = undefined;
pub var byName: *const fn (String) *const Entity = undefined;
pub var activateById: *const fn (Index, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (Index) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields of an entity
id: Index = UNDEF_INDEX,
name: String = NO_NAME,
kind: Kind = undefined,
parent_id: Index = UNDEF_INDEX,

pub fn withComponent(self: *Entity, c: anytype) *Entity {
    const T = @TypeOf(c);
    _ = Component.EntityComponentPool(T).register(@as(T, c));
    self.kind.with(T.type_aspect);
    return self;
}

pub fn withParent(self: *Entity, name: String) *Entity {
    self.parent_id = Entity.byName(name).index;
}

pub fn onDispose(id: Index) void {
    for (0..ENTITY_COMPONENT_ASPECT_GROUP._size) |i| {
        ENTITY_COMPONENT_INTERFACE_TABLE.get(ENTITY_COMPONENT_ASPECT_GROUP.aspects[i].index).clear(id);
    }
}

//////////////////////////////////////////////////////////////////////////
//// Entity Components
//////////////////////////////////////////////////////////////////////////
var INIT = false;
var ENTITY_COMPONENT_INTERFACE_TABLE: DynArray(Component.ComponentTypeInterface) = undefined;
pub var ENTITY_COMPONENT_ASPECT_GROUP: *AspectGroup = undefined;

// module init
pub fn init() !void {
    defer INIT = true;
    if (INIT)
        return;

    ENTITY_COMPONENT_INTERFACE_TABLE = try DynArray(Component.ComponentTypeInterface).init(api.ENTITY_ALLOC, null);
    ENTITY_COMPONENT_ASPECT_GROUP = try aspect.newAspectGroup("ENTITY_COMPONENT_ASPECT_GROUP");
}

// module deinit
pub fn deinit() void {
    defer INIT = false;
    if (!INIT)
        return;

    // deinit all registered entity component pools via aspect interface mapping
    for (0..ENTITY_COMPONENT_ASPECT_GROUP._size) |i| {
        ENTITY_COMPONENT_INTERFACE_TABLE.get(ENTITY_COMPONENT_ASPECT_GROUP.aspects[i].index).deinit();
    }
    ENTITY_COMPONENT_INTERFACE_TABLE.deinit();
    ENTITY_COMPONENT_INTERFACE_TABLE = undefined;

    aspect.disposeAspectGroup("ENTITY_COMPONENT_TYPE_ASPECT_GROUP");
    ENTITY_COMPONENT_ASPECT_GROUP = undefined;
}

pub fn registerEntityComponent(comptime T: type) void {
    EntityComponentPool(T).init();
}

pub fn EntityComponentPool(comptime T: type) type {

    // check component type constraints
    comptime var has_aspect: bool = false;
    comptime var has_get: bool = false;
    comptime var has_byId: bool = false;
    // component function interceptors
    comptime var has_onNew: bool = false;
    comptime var has_onDispose: bool = false;
    comptime {
        if (!trait.is(.Struct)(T))
            @compileError("Expects component type is a struct.");
        if (!trait.hasDecls(T, .{"NULL_VALUE"}))
            @compileError("Expects component type to have member named 'NULL_VALUE' that is the types null value.");
        if (!trait.hasDecls(T, .{"COMPONENT_NAME"}))
            @compileError("Expects component type to have member named 'COMPONENT_NAME' that defines a unique name of the component type.");
        if (!trait.hasField("id")(T))
            @compileError("Expects component type to have field named id");

        has_aspect = trait.hasDecls(T, .{"type_aspect"});
        has_get = trait.hasDecls(T, .{"get"});
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
            if (Self.initialized)
                return;

            errdefer Self.deinit();
            defer {
                ENTITY_COMPONENT_INTERFACE_TABLE.set(
                    Component.ComponentTypeInterface{
                        .clear = Self.i_clear,
                        .deinit = T.deinit,
                        .to_string = toString,
                    },
                    c_aspect.index,
                );
                Self.initialized = true;
            }

            items = DynArray(T).init(api.COMPONENT_ALLOC, T.NULL_VALUE) catch @panic("Init items failed");
            c_aspect = ENTITY_COMPONENT_ASPECT_GROUP.getAspect(@typeName(T));

            if (has_aspect) T.type_aspect = c_aspect;
            if (has_get) T.get = Self.get;
            if (has_byId) T.byId = Self.byId;
        }

        pub fn deinit() void {
            defer Self.initialized = false;
            if (!Self.initialized)
                return;

            c_aspect = undefined;
            items.deinit();

            if (has_aspect) T.type_aspect = undefined;
            if (has_byId) T.byId = undefined;
        }

        pub fn typeCheck(a: *Aspect) bool {
            if (!Self.initialized)
                return false;

            return c_aspect.index == a.index;
        }

        pub fn count() usize {
            return items.slots.count();
        }

        pub fn register(c: *T, id: Index) *T {
            checkComponentTrait(c);
            c.id = id;
            items.set(c, id);
            if (has_onNew) T.onNew(id);
            return items.get(id);
        }

        pub fn get(id: Index) *T {
            return items.get(id);
        }

        pub fn byId(id: Index) *const T {
            return items.get(id);
        }

        pub fn clearAll() void {
            var i: usize = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(i);
                i = next + 1;
            }
        }

        pub fn clear(id: Index) void {
            if (has_onDispose) T.onDispose(id);
            items.reset(id);
        }

        fn toString() String {
            var string_builder = ArrayList(u8).init(api.ALLOC);
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
                if (!trait.hasField("id")(@TypeOf(c))) @compileError("Expects component to have field 'id'.");
            }
        }
    };
}
