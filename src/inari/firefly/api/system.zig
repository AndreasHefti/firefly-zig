const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;

const String = firefly.utils.String;
const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.Component.registerComponent(System, "System");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

pub const System = struct {
    pub const Component = api.Component.Mixin(System);
    pub const Naming = api.Component.NameMappingMixin(System);
    pub const Activation = api.Component.ActivationMixin(System);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    onActivation: ?*const fn (bool) void = null,
    onDestruct: *const fn () void,

    pub fn activation(self: *System, active: bool) void {
        if (self.onActivation) |onActivation| {
            onActivation(active);
        }
    }

    pub fn destruct(self: *System) void {
        self.onDestruct();
    }

    pub fn format(
        self: System,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "{?s}[ id:{d} ]",
            .{ self.name, self.id },
        );
    }
};

pub fn EntityUpdateMixin(comptime T: type) type {
    return struct {
        comptime {
            if (@typeInfo(T) != .Struct)
                @compileError("Expects component type is a struct.");
            if (!@hasDecl(T, "updateEntities"))
                @compileError("Expects type has fn: updateEntities(*utils.BitSet)");
        }

        pub var entity_condition: api.EntityTypeCondition = undefined;
        pub var entities: firefly.utils.BitSet = undefined;

        pub fn systemMixinInit() void {
            entities = firefly.utils.BitSet.new(api.ALLOC);
            if (@hasDecl(T, "accept") or @hasDecl(T, "dismiss")) {
                entity_condition = api.EntityTypeCondition{
                    .accept_kind = if (@hasDecl(T, "accept")) api.EComponentAspectGroup.newKindOf(T.accept) else null,
                    .accept_full_only = if (@hasDecl(T, "accept_full_only")) T.accept_full_only else true,
                    .dismiss_kind = if (@hasDecl(T, "dismiss")) api.EComponentAspectGroup.newKindOf(T.dismiss) else null,
                };
            }
        }

        pub fn systemMixinDeinit() void {
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

pub fn SystemMixin(comptime T: type) type {
    const has_render_order: bool = @hasDecl(T, "render_order");
    const has_view_render_order: bool = @hasDecl(T, "view_render_order");
    const has_update_order: bool = @hasDecl(T, "update_order");

    const has_update_event_subscription: bool = @hasDecl(T, "update");
    const has_render_event_subscription: bool = @hasDecl(T, "render");
    const has_view_render_event_subscription: bool = @hasDecl(T, "renderView");

    const has_entity_registration: bool = @hasDecl(T, "entityRegistration");
    const has_entity_condition: bool = @hasDecl(T, "entity_condition");

    const has_component_registration: bool = @hasDecl(T, "componentRegistration");
    const has_component_condition: bool = @hasDecl(T, "componentCondition");

    comptime {
        if (@typeInfo(T) != .Struct)
            @compileError("Expects component type is a struct.");
        if (has_component_registration and !@hasDecl(T, "component_register_type"))
            @compileError("Expects have field: component_register_type: Type, that holds the type of the component to register for");
    }

    return struct {
        const Self = @This();

        var component_ref: ?Index = null;

        pub fn init() void {
            if (component_ref != null)
                return;

            component_ref = System.Component.new(.{
                .name = @typeName(T),
                .onActivation = activation,
                .onDestruct = destruct,
            }).id;

            if (@hasDecl(T, "systemMixinInit"))
                T.systemMixinInit();
            if (@hasDecl(T, "systemInit"))
                T.systemInit();
        }

        pub fn disposeSystem() void {
            if (component_ref) |id| {
                defer component_ref = null;
                System.Component.dispose(id);
            }
        }

        pub fn activate() void {
            System.Activation.activate(component_ref.?);
        }

        pub fn deactivate() void {
            System.Activation.deactivate(component_ref.?);
        }

        fn destruct() void {
            if (component_ref != null) {
                if (@hasDecl(T, "systemDeinit"))
                    T.systemDeinit();
                if (@hasDecl(T, "systemMixinDeinit"))
                    T.systemMixinDeinit();
            }
            component_ref = null;
        }

        fn notifyComponentChange(e: api.ComponentEvent) void {
            if (e.c_id) |id| {
                if (has_component_condition and !T.componentCondition(id))
                    return;

                switch (e.event_type) {
                    .ACTIVATED => T.componentRegistration(id, true),
                    .DEACTIVATING => T.componentRegistration(id, false),
                    else => {},
                }
            }
        }

        fn notifyEntityChange(e: api.ComponentEvent) void {
            if (e.c_id) |id| {
                if (has_entity_condition) {
                    if (@typeInfo(@TypeOf(T.entity_condition)) == .Optional) {
                        if (T.entity_condition) |*ec| {
                            if (!ec.check(id))
                                return;
                        }
                    } else {
                        if (!T.entity_condition.check(id))
                            return;
                    }
                }

                switch (e.event_type) {
                    .ACTIVATED => T.entityRegistration(id, true),
                    .DEACTIVATING => T.entityRegistration(id, false),
                    else => {},
                }
            }
        }

        fn activation(active: bool) void {
            if (active) {
                std.debug.print("FIREFLY : INFO: Activate System: {?s}\n", .{
                    System.Component.byId(component_ref.?).name,
                });
                if (has_entity_registration) {
                    api.Entity.Subscription.subscribe(notifyEntityChange);
                }
                if (has_component_registration) {
                    T.component_register_type.Subscription.subscribe(notifyComponentChange);
                }
                if (has_update_event_subscription) {
                    if (has_update_order) {
                        firefly.api.subscribeUpdateAt(T.update_order, T.update);
                    } else {
                        firefly.api.subscribeUpdate(T.update);
                    }
                }
                if (has_render_event_subscription) {
                    if (has_render_order) {
                        firefly.api.subscribeRenderAt(T.render_order, T.render);
                    } else {
                        firefly.api.subscribeRender(T.render);
                    }
                }
                if (has_view_render_event_subscription) {
                    if (has_view_render_order) {
                        firefly.api.subscribeViewRenderAt(T.view_render_order, T.renderView);
                    } else {
                        firefly.api.subscribeViewRender(T.renderView);
                    }
                }
            } else {
                std.debug.print("FIREFLY : INFO: Deactivate System: {?s}\n", .{
                    System.Component.byId(component_ref.?).name,
                });
                if (has_entity_registration) {
                    api.Entity.Subscription.unsubscribe(notifyEntityChange);
                }
                if (has_component_registration) {
                    T.component_register_type.Subscription.unsubscribe(notifyComponentChange);
                }
                if (has_update_event_subscription) {
                    firefly.api.unsubscribeUpdate(T.update);
                }
                if (has_render_event_subscription) {
                    firefly.api.unsubscribeRender(T.render);
                }
                if (has_view_render_event_subscription) {
                    firefly.api.unsubscribeViewRender(T.renderView);
                }
            }

            if (@hasDecl(T, "systemActivation"))
                T.systemActivation(active);
        }
    };
}
