const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const Component = api.Component;
const Entity = api.Entity;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(SystemComponent);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

pub fn System(comptime T: type) type {
    comptime var has_init: bool = false;
    comptime var has_activation: bool = false;
    comptime var has_deinit: bool = false;

    comptime var has_render_order: bool = false;
    comptime var has_view_render_order: bool = false;
    comptime var has_update_order: bool = false;

    comptime var has_update_event_subscription: bool = false;
    comptime var has_render_event_subscription: bool = false;
    comptime var has_view_render_event_subscription: bool = false;
    comptime var has_entity_event_subscription: bool = false;

    comptime {
        if (!trait.is(.Struct)(T))
            @compileError("Expects component type is a struct.");

        has_init = trait.hasDecls(T, .{"systemInit"});
        has_activation = trait.hasDecls(T, .{"systemActivation"});
        has_deinit = trait.hasDecls(T, .{"systemDeinit"});
        has_render_order = trait.hasDecls(T, .{"render_order"});
        has_view_render_order = trait.hasDecls(T, .{"view_render_order"});
        has_update_order = trait.hasDecls(T, .{"update_order"});

        has_update_event_subscription = trait.hasDecls(T, .{"update"});
        has_render_event_subscription = trait.hasDecls(T, .{"render"});
        has_view_render_event_subscription = trait.hasDecls(T, .{"renderView"});
        has_entity_event_subscription = trait.hasDecls(T, .{"notifyEntityChange"});
    }

    return struct {
        const Self = @This();

        var type_init = false;
        var component_ref: ?*SystemComponent = null;

        pub fn createSystem(name: String, info: String, active: bool) void {
            defer type_init = true;
            if (type_init)
                return;

            component_ref = SystemComponent.newAnd(.{
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

        fn activation(active: bool) void {
            if (active) {
                if (has_entity_event_subscription) {
                    Entity.subscribe(T.notifyEntityChange);
                }
                if (has_update_event_subscription) {
                    if (has_update_order) {
                        api.subscribeUpdateAt(T.update_order, T.update);
                    } else {
                        api.subscribeUpdate(T.update);
                    }
                }
                if (has_render_event_subscription) {
                    if (has_render_order) {
                        api.subscribeRenderAt(T.render_order, T.render);
                    } else {
                        api.subscribeRender(T.render);
                    }
                }
                if (has_view_render_event_subscription) {
                    if (has_view_render_order) {
                        api.subscribeViewRenderAt(T.view_render_order, T.renderView);
                    } else {
                        api.subscribeViewRender(T.renderView);
                    }
                }
            } else {
                if (has_entity_event_subscription) {
                    Entity.unsubscribe(T.notifyEntityChange);
                }
                if (has_update_event_subscription) {
                    api.unsubscribeUpdate(T.update);
                }
                if (has_render_event_subscription) {
                    api.unsubscribeRender(T.render);
                }
                if (has_view_render_event_subscription) {
                    api.unsubscribeViewRender(T.renderView);
                }
            }

            if (has_activation)
                T.systemActivation(active);
        }

        fn activate() void {
            if (component_ref) |c| {
                SystemComponent.activateById(c.id, true);

                if (has_entity_event_subscription) {
                    Entity.subscribe(T.notifyEntityChange);
                }
                if (has_update_event_subscription) {
                    if (has_update_order) {
                        api.subscribeUpdateAt(T.update_order, T.update);
                    } else {
                        api.subscribeUpdate(T.update);
                    }
                }
                if (has_render_event_subscription) {
                    if (has_render_order) {
                        api.subscribeRenderAt(T.render_order, T.render);
                    } else {
                        api.subscribeRender(T.render);
                    }
                }
                if (has_view_render_event_subscription) {
                    if (has_view_render_order) {
                        api.subscribeViewRenderAt(T.view_render_order, T.renderView);
                    } else {
                        api.subscribeViewRender(T.renderView);
                    }
                }
            }
        }

        fn deactivate() void {
            if (component_ref) |c| {
                if (has_entity_event_subscription) {
                    Entity.unsubscribe(T.notifyEntityChange);
                }
                if (has_update_event_subscription) {
                    api.unsubscribeUpdate(T.update);
                }
                if (has_render_event_subscription) {
                    api.unsubscribeRender(T.render);
                }
                if (has_view_render_event_subscription) {
                    api.unsubscribeViewRender(T.renderView);
                }

                SystemComponent.activateById(c.id, false);
            }
        }
    };
}

pub fn activateSystem(name: String, active: bool) void {
    SystemComponent.activateByName(name, active);
}

const SystemComponent = struct {
    pub usingnamespace Component.Trait(SystemComponent, .{ .name = "System", .subscription = false });
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
