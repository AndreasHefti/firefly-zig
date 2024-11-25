const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;

const String = firefly.utils.String;
const Index = firefly.utils.Index;
const Vector2f = firefly.utils.Vector2f;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    INTERFACE_TABLE = utils.DynArray(EComponentTypeInterface).new(firefly.api.ENTITY_ALLOC);
}

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

pub const Entity = struct {
    pub const Component = api.Component.Mixin(Entity);
    pub const Naming = api.Component.NameMappingMixin(Entity);
    pub const Activation = api.Component.ActivationMixin(Entity);
    pub const Subscription = api.Component.SubscriptionMixin(Entity);
    pub const Control = api.Component.ControlMixin(Entity);
    pub const Grouping = api.Component.GroupingMixin(Entity);

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    groups: ?api.GroupKind = null,

    kind: api.EComponentKind = undefined,

    pub fn construct(self: *Entity) void {
        self.kind = api.EComponentAspectGroup.newKind();
    }

    pub fn destruct(self: *Entity) void {
        var next = INTERFACE_TABLE.slots.nextSetBit(0);
        while (next) |i| {
            if (INTERFACE_TABLE.get(i)) |ref| ref.clear(self.id);
            next = INTERFACE_TABLE.slots.nextSetBit(i + 1);
        }
        self.kind = undefined;
    }

    pub fn registerComponent(comptime T: type, name: String) void {
        EntityComponentMixin(T).init(name);
    }

    pub fn newActive(entity: Entity, components: anytype) Index {
        const id = new(entity, components);
        Entity.Activation.activate(id);
        return id;
    }

    pub fn new(template: Entity, components: anytype) Index {
        const entity_id = Component.new(template);

        inline for (components) |c| {
            const T = @TypeOf(c);
            if (@hasDecl(T, "createEComponent")) {
                T.createEComponent(entity_id, c);
            } else if (@hasDecl(T, "Component")) {
                EntityComponentMixin(T).new(entity_id, c);
            } else {
                @panic("unknown type");
            }
        }
        return entity_id;
    }

    pub fn hasEntityComponent(entity_id: Index, ect: api.EComponentAspect) bool {
        return Component.byId(entity_id).kind.hasAspect(ect);
    }

    pub fn activation(self: *Entity, active: bool) void {
        activateEntityComponents(self, active);
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
        for (0..api.EComponentAspectGroup.size()) |i| {
            if (self.kind.has(@intCast(i))) {
                try writer.print(" {s} ", .{api.EComponentAspectGroup.getAspectById(i).name});
            }
        }
    }
};

pub const EntityTypeCondition = struct {
    accept_kind: ?api.EComponentKind = null,
    accept_full_only: bool = true,
    dismiss_kind: ?api.EComponentKind = null,

    pub fn check(self: *EntityTypeCondition, id: Index) bool {
        const e_kind = Entity.Component.byId(id).kind;
        if (self.accept_kind) |ak| {
            if (self.dismiss_kind) |dk| {
                if (e_kind.hasAnyAspect(dk)) {
                    return false;
                }
            }

            if (self.accept_full_only) {
                return ak.isPartOf(e_kind);
            } else if (e_kind.hasAnyAspect(ak)) {
                return true;
            }
            return false;
        }
        if (self.dismiss_kind) |dk| {
            if (e_kind.hasAnyAspect(dk)) {
                return false;
            }
        }

        return true;
    }
};

//////////////////////////////////////////////////////////////////////////
//// Entity Component
//////////////////////////////////////////////////////////////////////////
const EComponentTypeInterface = struct {
    activate: *const fn (Index, bool) void,
    clear: *const fn (Index) void,
    deinit: api.DeinitFunction,
    to_string: *const fn (*utils.StringBuffer) void,
};
var INTERFACE_TABLE: utils.DynArray(EComponentTypeInterface) = undefined;

fn activateEntityComponents(entity: *Entity, active: bool) void {
    if (!initialized)
        return;

    for (0..api.EComponentAspectGroup.size()) |i| {
        const aspect = api.EComponentAspectGroup.getAspectById(i);
        if (entity.kind.hasAspect(aspect)) {
            if (INTERFACE_TABLE.get(aspect.id)) |ref|
                ref.activate(entity.id, active);
        }
    }
}

pub inline fn checkValidEntityComponentInstance(any_component: anytype) void {
    if (!isValid(any_component))
        @panic("Invalid Entity Component");
}

fn isValid(any_component: anytype) bool {
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

pub fn EntityComponentMixin(comptime T: type) type {
    // component function interceptors
    const has_init: bool = @hasDecl(T, "typeInit");
    const has_deinit: bool = @hasDecl(T, "typeDeinit");
    // component struct based interceptors / methods
    const has_construct: bool = @hasDecl(T, "construct");
    const has_destruct: bool = @hasDecl(T, "destruct");
    const has_activation: bool = @hasDecl(T, "activation");
    const has_call_context: bool = @hasDecl(T, "CallContext");

    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects component type is a struct.");
        if (!@hasField(T, "id"))
            @compileError("Expects component type to have field named id");
    }

    return struct {
        var _init = false;

        pub var entity_component_name: String = undefined;
        pub var pool: utils.DynArray(T) = undefined;
        pub var aspect: api.EComponentAspect = undefined;

        pub fn init(name: String) void {
            defer _init = true;
            if (_init)
                return;

            entity_component_name = name;
            api.EComponentAspectGroup.applyAspect(@This(), name);
            pool = utils.DynArray(T).newWithRegisterSize(firefly.api.ENTITY_ALLOC, 512);
            _ = INTERFACE_TABLE.add(EComponentTypeInterface{
                .activate = _activate,
                .clear = clear,
                .deinit = @This().deinit,
                .to_string = toString,
            });
            if (has_init)
                T.typeInit();
        }

        pub fn deinit() void {
            defer _init = false;
            if (!_init)
                return;

            if (has_destruct) {
                var next = pool.slots.nextSetBit(0);
                while (next) |i| {
                    if (pool.get(i)) |item| item.destruct();
                    next = pool.slots.nextSetBit(i + 1);
                }
            }

            if (has_deinit)
                T.typeDeinit();

            pool.clear();
            pool.deinit();

            aspect = undefined;
        }

        pub fn count() usize {
            return pool.slots.count();
        }

        pub fn byId(id: Index) *T {
            return pool.get(id).?;
        }

        pub fn byIdOptional(id: Index) ?*T {
            return pool.get(id);
        }

        pub fn byName(name: String) ?*T {
            if (Entity.Naming.byName(name)) |e|
                return byId(e.id);
            return null;
        }

        pub fn new(entity_id: Index, component: T) void {
            _ = newAndGet(entity_id, component);
        }

        pub fn newAndGet(entity_id: Index, component: T) *T {
            checkValidEntityComponentInstance(component);

            if (component.id != UNDEF_INDEX)
                @panic("Entity Component id mismatch");

            if (pool.exists(entity_id))
                utils.panic(api.ALLOC, "Entity {d} has already component of type {any}\n", .{ entity_id, T });

            var comp = pool.set(component, entity_id);
            comp.id = entity_id;

            var entity = Entity.Component.byId(entity_id);
            entity.kind = entity.kind.withAspect(aspect);

            if (has_construct)
                comp.construct();

            if (has_call_context)
                api.Component.CallContextMixin(T).construct(comp);

            return comp;
        }

        fn _activate(id: Index, active: bool) void {
            if (has_activation)
                if (pool.get(id)) |item|
                    item.activation(active);
        }

        fn clearAll() void {
            var i: usize = 0;
            while (pool.slots.nextSetBit(i)) |next| {
                clear(i);
                i = next + 1;
            }
        }

        fn clear(id: Index) void {
            if (!pool.slots.isSet(id))
                return;

            if (has_destruct)
                if (pool.get(id)) |item|
                    item.destruct();

            if (has_call_context)
                if (pool.get(id)) |item|
                    api.Component.CallContextMixin(T).destruct(item);

            pool.delete(id);
        }

        fn toString(string_buffer: *utils.StringBuffer) void {
            string_buffer.print("\n  {s} size: {d}", .{ aspect.name, pool.size() });
            var next = pool.slots.nextSetBit(0);
            while (next) |i| {
                string_buffer.print("\n   {any}", .{pool.get(i)});
                next = pool.slots.nextSetBit(i + 1);
            }
        }
    };
}

pub const EMultiplier = struct {
    pub const Component = EntityComponentMixin(EMultiplier);

    id: Index = UNDEF_INDEX,
    positions: []const Vector2f = undefined,

    pub fn destruct(self: *EMultiplier) void {
        firefly.api.ALLOC.free(self.positions);
        self.positions = undefined;
    }

    pub fn add(entity_id: Index, c: EMultiplier) void {
        Component.new(entity_id, c);
    }
};

pub fn EntityUpdateSystemMixin(comptime T: type) type {
    return struct {
        comptime {
            if (@typeInfo(T) != .Struct)
                @compileError("Expects component type is a struct.");
            if (!@hasDecl(T, "updateEntities"))
                @compileError("Expects type has fn: updateEntities(*utils.BitSet)");
        }

        pub var entity_condition: api.EntityTypeCondition = undefined;
        pub var entities: firefly.utils.BitSet = undefined;

        pub fn init() void {
            entities = firefly.utils.BitSet.new(api.ALLOC);
            if (@hasDecl(T, "accept") or @hasDecl(T, "dismiss")) {
                entity_condition = api.EntityTypeCondition{
                    .accept_kind = if (@hasDecl(T, "accept")) api.EComponentAspectGroup.newKindOf(T.accept) else null,
                    .accept_full_only = if (@hasDecl(T, "accept_full_only")) T.accept_full_only else true,
                    .dismiss_kind = if (@hasDecl(T, "dismiss")) api.EComponentAspectGroup.newKindOf(T.dismiss) else null,
                };
            }
        }

        pub fn deinit() void {
            entity_condition = undefined;
            entities.deinit();
            entities = undefined;
        }

        pub fn entityRegistration(id: Index, register: bool) void {
            if (!entity_condition.check(id))
                return;

            entities.setValue(id, register);
        }

        pub fn update(_: api.UpdateEvent) void {
            T.updateEntities(&entities);
        }
    };
}
