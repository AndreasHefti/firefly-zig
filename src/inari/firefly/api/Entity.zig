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
const Condition = utils.Condition;
const AspectGroup = utils.AspectGroup;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const Vector2f = utils.Vector2f;

pub const Entity = struct {
    pub usingnamespace Component.Trait(Entity, .{ .name = "Entity" });

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    kind: EComponentKind = undefined,

    pub fn componentTypeInit() !void {
        if (@This().isInitialized())
            return;

        try EComponent.init();
    }

    pub fn componentTypeDeinit() void {
        if (!@This().isInitialized())
            return;

        EComponent.deinit();
    }

    pub fn construct(self: *Entity) void {
        self.kind = EComponentAspectGroup.newKind();
    }

    pub fn destruct(self: *Entity) void {
        var next = INTERFACE_TABLE.slots.nextSetBit(0);
        while (next) |i| {
            if (INTERFACE_TABLE.get(i)) |ref| ref.clear(self.id);
            next = INTERFACE_TABLE.slots.nextSetBit(i + 1);
        }
    }

    pub fn with(self: *Entity, c: anytype) *Entity {
        EComponent.checkValid(c);

        const T = @TypeOf(c);
        var comp = @as(T, c);
        _ = EComponentPool(T).register(comp, self.id);
        self.kind = self.kind.withAspect(T);
        return self;
    }

    pub fn withAnd(self: *Entity, c: anytype) *@TypeOf(c) {
        _ = self.with(c);
        const T = @TypeOf(c);
        return EComponentPool(T).items.get(self.id).?;
    }

    pub fn activation(self: *Entity, active: bool) void {
        EComponent.activateEntityComponents(self, active);
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
            "Entity[{d}|{?s}|]",
            .{ self.id, self.name },
        );
        for (0..EComponentAspectGroup.size()) |i| {
            if (self.kind.has(@intCast(i))) {
                try writer.print(" {s} ", .{EComponentAspectGroup.getAspectById(i).name});
            }
        }
    }
};

pub const EntityCondition = struct {
    accept_kind: ?EComponentKind = null,
    dismiss_kind: ?EComponentKind = null,
    condition: ?Condition(Index) = null,

    pub fn check(self: *EntityCondition, id: Index) bool {
        const e_kind = Entity.byId(id).kind;
        if (self.accept_kind) |*ak| if (!ak.isPartOf(e_kind))
            return false;
        if (self.dismiss_kind) |*dk| if (!dk.isNotPartOf(e_kind))
            return false;
        if (self.condition) |*c| if (!c.check(id))
            return false;
        return true;
    }
};

//////////////////////////////////////////////////////////////////////////
//// EMultiplier Entity position multiplier
//////////////////////////////////////////////////////////////////////////

pub const EMultiplier = struct {
    pub usingnamespace EComponent.Trait(@This(), "EMultiplier");
    pub const NULL_POS_ENTRY = Vector2f{};

    id: Index = UNDEF_INDEX,
    positions: DynArray(Vector2f) = undefined,

    pub fn construct(self: *EMultiplier) void {
        self.positions = DynArray(Vector2f).init(
            api.COMPONENT_ALLOC,
            NULL_POS_ENTRY,
        ) catch unreachable;
    }

    pub fn destruct(self: *EMultiplier) void {
        self.positions.deinit();
        self.positions = undefined;
    }
};

//////////////////////////////////////////////////////////////////////////
//// Entity Component
//////////////////////////////////////////////////////////////////////////
const EComponentTypeInterface = struct {
    activate: *const fn (Index, bool) void,
    clear: *const fn (Index) void,
    deinit: *const fn () void,
    to_string: *const fn (*StringBuffer) void,
};
var INTERFACE_TABLE: DynArray(EComponentTypeInterface) = undefined;

pub const EComponentAspectGroup = AspectGroup(struct {
    pub const name = "EComponent";
});
pub const EComponentKind = EComponentAspectGroup.Kind;
pub const EComponentAspect = EComponentAspectGroup.Aspect;

pub const EComponent = struct {
    var initialized = false;

    pub fn Trait(comptime T: type, comptime type_name: String) type {
        return struct {
            // component type fields
            pub const COMPONENT_TYPE_NAME = type_name;
            pub const pool = EComponentPool(T);
            // component type pool function references
            pub var aspect: *const EComponentAspect = undefined;
            pub fn byId(id: Index) ?*T {
                return pool.items.get(id);
            }

            pub fn count() usize {
                return pool.items.slots.count();
            }
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

        return true;
    }

    // module init
    pub fn init() !void {
        defer initialized = true;
        if (initialized)
            return;

        INTERFACE_TABLE = try DynArray(EComponentTypeInterface).new(api.ENTITY_ALLOC);
    }

    // module deinit
    pub fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        // deinit all registered entity component pools via aspect interface mapping
        var next = INTERFACE_TABLE.slots.nextSetBit(0);
        while (next) |i| {
            if (INTERFACE_TABLE.get(i)) |ref| ref.deinit();
            INTERFACE_TABLE.delete(i);
            next = INTERFACE_TABLE.slots.nextSetBit(i + 1);
        }
        INTERFACE_TABLE.deinit();
        INTERFACE_TABLE = undefined;
    }

    pub fn registerEntityComponent(comptime T: type) void {
        EComponentPool(T).init();
    }

    fn activateEntityComponents(entity: *Entity, active: bool) void {
        if (!initialized)
            return;

        for (0..EComponentAspectGroup.size()) |i| {
            var aspect = EComponentAspectGroup.getAspectById(i);
            if (entity.kind.hasAspect(aspect)) {
                if (INTERFACE_TABLE.get(aspect.id)) |ref|
                    ref.activate(entity.id, active);
            }
        }
    }
};

pub fn EComponentPool(comptime T: type) type {

    // check component type constraints
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
        if (!trait.hasDecls(T, .{"COMPONENT_TYPE_NAME"}))
            @compileError("Expects component type to have member named 'COMPONENT_TYPE_NAME' that defines a unique name of the component type.");
        if (!trait.hasDecls(T, .{"aspect"}))
            @compileError("Expects component type to have member aspect, that defines the entity component runtime type identifier.");
        if (!trait.hasField("id")(T))
            @compileError("Expects component type to have field named id");

        has_byId = trait.hasDecls(T, .{"byId"});

        has_init = trait.hasDecls(T, .{"ecTypeInit"});
        has_deinit = trait.hasDecls(T, .{"ecTypeDeinit"});

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

        pub fn init() void {
            defer Self.initialized = true;
            if (Self.initialized)
                return;

            errdefer Self.deinit();

            EComponentAspectGroup.applyAspect(T, T.COMPONENT_TYPE_NAME);
            items = DynArray(T).new(api.COMPONENT_ALLOC) catch @panic("Init items failed");
            _ = INTERFACE_TABLE.add(EComponentTypeInterface{
                .activate = Self.activate,
                .clear = Self.clear,
                .deinit = Self.deinit,
                .to_string = toString,
            });
            if (has_init)
                T.ecTypeInit();
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

            if (has_deinit)
                T.ecTypeDeinit();

            items.clear();
            items.deinit();

            T.aspect = undefined;
        }

        fn register(c: T, id: Index) *T {
            checkComponentTrait(c);

            if (c.id != UNDEF_INDEX)
                @panic("Entity Component id mismatch");

            var comp = items.set(c, id);
            comp.id = id;
            if (has_construct)
                comp.construct();

            return comp;
        }

        fn activate(id: Index, active: bool) void {
            if (has_activation) {
                if (items.get(id)) |item| item.activation(active);
            }
        }

        fn clearAll() void {
            var i: usize = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(i);
                i = next + 1;
            }
        }

        fn clear(id: Index) void {
            if (!items.slots.isSet(id))
                return;

            if (has_destruct) {
                if (items.get(id)) |item| {
                    item.destruct();
                }
            }
            items.delete(id);
        }

        fn toString(string_buffer: *StringBuffer) void {
            string_buffer.print("\n  {s} size: {d}", .{ T.aspect.name, items.size() });
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
