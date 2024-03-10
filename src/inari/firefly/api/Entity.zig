const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const Allocator = std.mem.Allocator;
const StringBuffer = utils.StringBuffer;
const DynArray = utils.DynArray;
const ArrayList = std.ArrayList;
const Component = api.Component;
const ComponentListener = Component.ComponentListener;
const ComponentEvent = Component.ComponentEvent;
const ComponentTypeInterface = Component.API.ComponentTypeInterface;
const Condition = utils.Condition;
const Kind = utils.Kind;
const Aspect = utils.Aspect;
const AspectGroup = utils.AspectGroup;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;

pub const Entity = struct {
    pub usingnamespace Component.API.ComponentTrait(Entity, .{ .name = "Entity" });

    id: Index = UNDEF_INDEX,
    name: String = NO_NAME,
    kind: Kind = undefined,

    pub fn init() !void {
        try EntityComponent.init();
    }

    pub fn deinit() void {
        EntityComponent.deinit();
    }

    pub fn construct(self: *Entity) void {
        self.kind = Kind.ofGroup(EntityComponent.ENTITY_KIND_ASP_GROUP);
    }

    pub fn destruct(self: *Entity) void {
        for (0..EntityComponent.ENTITY_KIND_ASP_GROUP._size) |i| {
            var index = EntityComponent.ENTITY_KIND_ASP_GROUP.aspects[i].index;
            if (EntityComponent.INTERFACE_TABLE.get(index)) |ref| ref.clear(self.id);
        }
    }

    pub fn withComponent(self: *Entity, c: anytype) *Entity {
        EntityComponent.API.checkValid(c);

        const T = @TypeOf(c);
        var comp = @as(T, c);
        _ = EntityComponentPool(T).register(comp, self.id);
        self.kind = self.kind.with(T.type_aspect);
        return self;
    }

    pub fn withComponentAnd(self: *Entity, c: anytype) *@TypeOf(c) {
        _ = self.withComponent(c);
        const T = @TypeOf(c);
        return EntityComponentPool(T).byId(self.id);
    }

    pub fn activation(self: *Entity, active: bool) void {
        EntityComponent.activateEntityComponents(self, active);
    }

    pub fn activate(self: *Entity) *Entity {
        if (self.id == UNDEF_INDEX)
            return self;

        Entity.activateById(self.id, true);
        return self;
    }

    pub fn deactivate(self: *Entity) *Entity {
        if (self.id == UNDEF_INDEX)
            return self;

        Entity.activateById(self.id, false);
        return self;
    }

    pub fn format(
        self: Entity,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Entity[{d}|{s}|{any}]",
            .{ self.id, self.name, self.kind },
        );
    }
};

//////////////////////////////////////////////////////////////////////////
//// Entity Components
//////////////////////////////////////////////////////////////////////////

pub const EntityComponent = struct {
    var initialized = false;

    var INTERFACE_TABLE: DynArray(ComponentTypeInterface) = undefined;
    pub var ENTITY_KIND_ASP_GROUP: *AspectGroup = undefined;

    // module init
    pub fn init() !void {
        defer initialized = true;
        if (initialized)
            return;

        INTERFACE_TABLE = try DynArray(ComponentTypeInterface).new(api.ENTITY_ALLOC);
        ENTITY_KIND_ASP_GROUP = try AspectGroup.new("ENTITY_KIND_ASP_GROUP");
    }

    // module deinit
    pub fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        // deinit all registered entity component pools via aspect interface mapping
        for (0..ENTITY_KIND_ASP_GROUP._size) |i| {
            var index = ENTITY_KIND_ASP_GROUP.aspects[i].index;
            if (INTERFACE_TABLE.get(index)) |ref| ref.deinit();
            INTERFACE_TABLE.delete(index);
        }
        INTERFACE_TABLE.deinit();
        INTERFACE_TABLE = undefined;

        AspectGroup.dispose("ENTITY_KIND_ASP_GROUP");
        ENTITY_KIND_ASP_GROUP = undefined;
    }

    pub fn registerEntityComponent(comptime T: type) void {
        EntityComponentPool(T).init();
    }

    fn activateEntityComponents(entity: *Entity, active: bool) void {
        for (0..ENTITY_KIND_ASP_GROUP._size) |i| {
            var aspect = &ENTITY_KIND_ASP_GROUP.aspects[i];
            if (entity.kind.hasAspect(aspect)) {
                if (INTERFACE_TABLE.get(aspect.index)) |ref|
                    ref.activate(entity.id, active);
            }
        }
    }

    pub const API = struct {
        pub fn Adapter(comptime T: type, comptime type_name: String) type {
            return struct {
                // component type fields
                pub const NULL_VALUE = T{};
                pub const COMPONENT_TYPE_NAME = type_name;
                pub const pool = Entity.EntityComponentPool(T);
                // component type pool function references
                pub var type_aspect: *Aspect = undefined;
                pub var byId: *const fn (Index) *T = undefined;
            };
        }

        pub inline fn checkValid(any_component: anytype) void {
            if (!isValid(any_component))
                @panic("Invalid Entity Component");
        }

        pub fn isValid(any_component: anytype) bool {
            const info: std.builtin.Type = @typeInfo(@TypeOf(any_component));
            const c_type = switch (info) {
                .Pointer => @TypeOf(any_component.*),
                .Struct => @TypeOf(any_component),
                else => {
                    std.log.err("No valid type entity component: {any}", .{any_component});
                    return false;
                },
            };

            if (!@hasField(c_type, "id")) {
                std.log.err("No valid entity component. No id field: {any}", .{any_component});
                return false;
            }

            if (!EntityComponentPool(c_type).c_aspect.isOfGroup(ENTITY_KIND_ASP_GROUP)) {
                std.log.err("No valid entity component. AspectGroup mismatch: {any}", .{any_component});
                return false;
            }

            return true;
        }
    };
};

pub fn EntityComponentPool(comptime T: type) type {

    // check component type constraints
    comptime var has_aspect: bool = false;
    comptime var has_byId: bool = false;
    // component function interceptors
    comptime var has_init: bool = false;
    comptime var has_deinit: bool = false;
    // component struct based interceptors / methods
    comptime var has_construct: bool = false;
    comptime var has_destruct: bool = false;
    comptime var has_activation: bool = false;

    comptime {
        if (!trait.is(.Struct)(T))
            @compileError("Expects component type is a struct.");
        if (!trait.hasDecls(T, .{"NULL_VALUE"}))
            @compileError("Expects component type to have member named 'NULL_VALUE' that is the types null value.");
        if (!trait.hasDecls(T, .{"COMPONENT_TYPE_NAME"}))
            @compileError("Expects component type to have member named 'COMPONENT_TYPE_NAME' that defines a unique name of the component type.");
        if (!trait.hasField("id")(T))
            @compileError("Expects component type to have field named id");

        has_aspect = trait.hasDecls(T, .{"type_aspect"});
        has_byId = trait.hasDecls(T, .{"byId"});

        has_init = trait.hasDecls(T, .{"init"});
        has_deinit = trait.hasDecls(T, .{"deinit"});

        has_construct = trait.hasDecls(T, .{"construct"});
        has_destruct = trait.hasDecls(T, .{"destruct"});
        has_activation = trait.hasDecls(T, .{"activation"});
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
                _ = EntityComponent.INTERFACE_TABLE.set(
                    ComponentTypeInterface{
                        .activate = Self.activate,
                        .clear = Self.clear,
                        .deinit = Self.deinit,
                        .to_string = toString,
                    },
                    c_aspect.index,
                );
                Self.initialized = true;
            }

            items = DynArray(T).new(api.COMPONENT_ALLOC) catch @panic("Init items failed");
            c_aspect = EntityComponent.ENTITY_KIND_ASP_GROUP.getAspect(T.COMPONENT_TYPE_NAME);

            if (has_aspect) T.type_aspect = c_aspect;
            if (has_byId) T.byId = Self.byId;
            if (has_init) T.init();
        }

        pub fn deinit() void {
            defer Self.initialized = false;
            if (!Self.initialized)
                return;

            if (has_destruct) {
                var next = items.slots.nextSetBit(0);
                while (next) |i| {
                    if (items.get(i)) |item| item.destruct();
                    next = items.slots.nextSetBit(i + 1);
                }
            }

            if (has_deinit) T.deinit();
            c_aspect = undefined;
            items.clear();
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

        pub fn register(c: T, id: Index) *T {
            checkComponentTrait(c);

            var comp = items.set(c, id);
            comp.id = id;
            if (has_construct)
                comp.construct();

            return comp;
        }

        // TODO make optional?
        pub fn byId(id: Index) *T {
            return items.get(id).?;
        }

        pub fn activate(id: Index, active: bool) void {
            if (has_activation)
                byId(id).activation(active);
        }

        pub fn clearAll() void {
            var i: usize = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(i);
                i = next + 1;
            }
        }

        pub fn clear(id: Index) void {
            if (!items.slots.isSet(id))
                return;

            if (has_destruct) {
                byId(id).destruct();
            }
            items.delete(id);
        }

        fn toString(string_buffer: *StringBuffer) void {
            string_buffer.print("\n  {s} size: {d}", .{ c_aspect.name, items.size() });
            var next = items.slots.nextSetBit(0);
            while (next) |i| {
                string_buffer.print("\n   {any}", .{items.get(i)});
                next = items.slots.nextSetBit(i + 1);
            }
        }

        fn checkComponentTrait(c: T) void {
            comptime {
                if (!trait.is(.Struct)(@TypeOf(c))) @compileError("Expects component is a struct.");
                if (!trait.hasField("id")(@TypeOf(c))) @compileError("Expects component to have field 'id'.");
            }
        }
    };
}

pub fn EntityEventSubscription(comptime _: type) type {
    return struct {
        const Self = @This();

        var _listener: ComponentListener = undefined;
        var _order: ?usize = null;
        var _accept_kind: ?Kind = null;
        var _dismiss_kind: ?Kind = null;
        var _condition: ?Condition(ComponentEvent) = null;

        pub fn of(listener: ComponentListener) Self {
            _listener = listener;
            return Self{};
        }

        pub fn withCondition(self: Self, condition: Condition(ComponentEvent)) Self {
            _condition = condition;
            return self;
        }

        pub fn withAcceptKind(self: Self, accept_kind: Kind) Self {
            _accept_kind = accept_kind;
            return self;
        }

        pub fn withDismissKind(self: Self, dismiss_kind: Kind) Self {
            _dismiss_kind = dismiss_kind;
            return self;
        }

        pub fn subscribe(self: Self) Self {
            Entity.subscribe(adapt);
            return self;
        }

        pub fn unsubscribe(self: Self) Self {
            Entity.unsubscribe(adapt);
            return self;
        }

        fn adapt(e: ComponentEvent) void {
            const e_kind = &Entity.byId(e.c_id).kind;
            if (_accept_kind) |*ak| if (!ak.isKindOf(e_kind))
                return;
            if (_dismiss_kind) |*dk| if (!dk.isNotKindOf(e_kind))
                return;
            if (_condition) |*c| if (!c.check(e))
                return;

            _listener(e);
        }
    };
}
