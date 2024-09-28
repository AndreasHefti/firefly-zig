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

    pub fn build(template: Entity) EntityBuilder {
        return EntityBuilder{ .entity_id = Component.new(template) };
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

pub const EntityBuilder = struct {
    entity_id: Index,

    pub fn addToGroup(self: EntityBuilder, aspect: api.GroupAspect) EntityBuilder {
        Entity.Grouping.add(self.entity_id, aspect);
        return self;
    }

    pub fn withComponent(self: EntityBuilder, component: anytype) EntityBuilder {
        const T = @TypeOf(component);
        EntityComponentMixin(T).new(self.entity_id, component);
        return self;
    }

    pub fn withControl(self: EntityBuilder, update: api.CallFunction, name: ?String, active: bool) EntityBuilder {
        Entity.Control.add(self.entity_id, update, name, active);
        return self;
    }

    pub fn withControlOf(self: EntityBuilder, control: anytype, active: bool) EntityBuilder {
        Entity.Control.addOf(self.entity_id, control, active);
        return self;
    }

    pub fn addFromBuilder(self: EntityBuilder, builder: anytype) EntityBuilder {
        builder.buildForEntity(self.entity_id);
        return self;
    }

    pub fn addToComponent(self: EntityBuilder, c_type: type, c: anytype) EntityBuilder {
        c_type.addToComponent(self.entity_id, c);
        return self;
    }

    pub fn activate(self: EntityBuilder) void {
        Entity.Activation.activate(self.entity_id);
    }

    pub fn activateGet(self: EntityBuilder) *Entity {
        Entity.Activation.activate(self.entity_id);
        return Entity.Component.byId(self.entity_id);
    }

    pub fn activateGetId(self: EntityBuilder) Index {
        Entity.Activation.activate(self.entity_id);
        return self.entity_id;
    }

    pub fn getId(self: EntityBuilder) Index {
        return self.entity_id;
    }

    pub fn get(self: EntityBuilder) *Entity {
        return Entity.Component.byId(self.entity_id);
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
            pool = utils.DynArray(T).new(firefly.api.ENTITY_ALLOC);
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

        pub fn byId(id: Index) ?*T {
            return pool.get(id);
        }

        pub fn byName(name: String) ?*T {
            if (Entity.Naming.byName(name)) |e|
                return byId(e.id);
            return null;
        }

        pub fn new(entity_id: Index, component: T) void {
            checkValidEntityComponentInstance(component);

            if (component.id != UNDEF_INDEX)
                @panic("Entity Component id mismatch");

            var comp = pool.set(component, entity_id);
            comp.id = entity_id;

            var entity = Entity.Component.byId(entity_id);
            entity.kind = entity.kind.withAspect(aspect);

            if (has_construct)
                comp.construct();
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

            if (has_destruct) {
                if (pool.get(id)) |item| {
                    item.destruct();
                }
            }
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
