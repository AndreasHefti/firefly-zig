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

    api.Component.registerComponent(SystemComponent);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

pub fn System(comptime T: type) type {
    const has_init: bool = @hasDecl(T, "systemInit");
    const has_activation: bool = @hasDecl(T, "systemActivation");
    const has_deinit: bool = @hasDecl(T, "systemDeinit");

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

        var type_init = false;
        var component_ref: ?*SystemComponent = null;

        pub fn createSystem(name: String, info: String, active: bool) void {
            defer type_init = true;
            if (type_init)
                return;

            component_ref = SystemComponent.new(.{
                .name = name,
                .info = info,
                .onActivation = activation,
                .onDestruct = destruct,
            });

            if (has_init)
                T.systemInit();

            if (active)
                SystemComponent.activateByName(name, true);
        }

        pub fn disposeSystem() void {
            defer type_init = false;
            if (!type_init)
                return;

            if (component_ref) |ref| {
                defer component_ref = null;
                SystemComponent.disposeById(ref.id);
            }
        }

        fn destruct() void {
            if (has_deinit)
                T.systemDeinit();
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
                switch (e.event_type) {
                    .ACTIVATED => {
                        if (has_entity_condition and !T.entity_condition.check(id))
                            return;
                        T.entityRegistration(id, true);
                    },
                    .DEACTIVATING => T.entityRegistration(id, false),
                    else => {},
                }
            }
        }

        fn activation(active: bool) void {
            if (active) {
                if (has_entity_registration) {
                    api.Entity.subscribe(notifyEntityChange);
                }
                if (has_component_registration) {
                    T.component_register_type.subscribe(notifyComponentChange);
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
                if (has_entity_registration) {
                    api.Entity.unsubscribe(notifyEntityChange);
                }
                if (has_component_registration) {
                    T.component_register_type.unsubscribe(notifyComponentChange);
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

            if (has_activation)
                T.systemActivation(active);
        }
    };
}

pub fn activateSystem(name: String, active: bool) void {
    SystemComponent.activateByName(name, active);
}

pub fn isSystemActive(name: String) bool {
    SystemComponent.isActiveByName(name);
}

const SystemComponent = struct {
    pub usingnamespace api.Component.Trait(SystemComponent, .{ .name = "System", .subscription = false });
    // struct fields of a System
    id: Index = UNDEF_INDEX,
    name: ?String = null,
    info: ?String = null,
    onActivation: ?*const fn (bool) void = null,
    onDestruct: *const fn () void,

    pub fn activation(self: *SystemComponent, active: bool) void {
        if (self.onActivation) |onActivation| {
            onActivation(active);
        }
    }

    pub fn destruct(self: *SystemComponent) void {
        self.onDestruct();
    }

    pub fn format(
        self: SystemComponent,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "{?s}[ id:{d}, info:{?s} ]",
            .{ self.name, self.id, self.info },
        );
    }
};
