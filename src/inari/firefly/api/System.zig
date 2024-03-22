const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const Component = api.Component;
const Engine = inari.firefly.Engine;
const ViewRenderer = inari.firefly.graphics.ViewRenderer;
const Entity = api.Entity;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(SystemComponent);
}

pub fn deinit() void {
    defer initialized = true;
    if (!initialized)
        return;

    Component.deinitComponent(SystemComponent);
}

pub fn System(comptime T: type) type {
    comptime var has_construct: bool = false;
    comptime var has_activation: bool = false;
    comptime var has_destruct: bool = false;
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

        has_construct = trait.hasDecls(T, .{"onConstruct"});
        has_activation = trait.hasDecls(T, .{"onActivation"});
        has_destruct = trait.hasDecls(T, .{"onDestruct"});
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

        pub fn init(name: String, info: String, active: bool) void {
            defer type_init = true;
            if (type_init)
                return;

            component_ref = SystemComponent.newAnd(.{
                .name = name,
                .info = info,
                .onActivation = if (has_activation) T.onActivation else null,
                .onDestruct = destruct,
            });

            if (has_construct)
                T.onConstruct();

            if (active)
                activate();
        }

        pub fn deinit() void {
            defer type_init = false;
            if (!type_init)
                return;

            if (component_ref) |ref| {
                defer component_ref = null;
                SystemComponent.disposeById(ref.id);
            }
        }

        fn destruct() void {
            if (has_destruct)
                T.onDestruct();
        }

        pub fn activate() void {
            if (component_ref) |c| {
                SystemComponent.activateById(c.id, true);

                if (has_entity_event_subscription) {
                    Entity.subscribe(T.notifyEntityChange);
                }
                if (has_update_event_subscription) {
                    if (has_update_order) {
                        Engine.subscribeUpdateAt(T.update_order, T.update);
                    } else {
                        Engine.subscribeUpdate(T.update);
                    }
                }
                if (has_render_event_subscription) {
                    if (has_render_order) {
                        Engine.subscribeRenderAt(T.render_order, T.render);
                    } else {
                        Engine.subscribeRender(T.render);
                    }
                }
                if (has_view_render_event_subscription) {
                    if (has_view_render_order) {
                        ViewRenderer.subscribeAt(T.view_render_order, T.renderView);
                    } else {
                        ViewRenderer.subscribe(T.renderView);
                    }
                }
            }
        }

        pub fn deactivate() void {
            if (component_ref) |c| {
                if (has_entity_event_subscription) {
                    Entity.unsubscribe(T.notifyEntityChange);
                }
                if (has_update_event_subscription) {
                    Engine.unsubscribeUpdate(T.update);
                }
                if (has_render_event_subscription) {
                    Engine.unsubscribeRender(T.render);
                }
                if (has_view_render_event_subscription) {
                    ViewRenderer.unsubscribe(T.renderView);
                }

                SystemComponent.activateById(c.id, false);
            }
        }
    };
}

pub const SystemComponent = struct {
    pub usingnamespace Component.Trait(SystemComponent, .{ .name = "System", .subscription = false });
    // struct fields of a System
    id: Index = UNDEF_INDEX,
    name: ?String = null,
    info: String = NO_NAME,
    onActivation: ?*const fn (bool) void = null,
    onDestruct: ?*const fn () void = null,

    pub fn init() !void {}

    pub fn activation(self: *SystemComponent, active: bool) void {
        if (self.onActivation) |onActivation| {
            onActivation(active);
        }
    }

    pub fn destruct(self: *SystemComponent) void {
        if (self.onDestruct) |onDestruct| {
            onDestruct();
        }
    }

    pub fn format(
        self: SystemComponent,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "{?s}[ id:{d}, info:{s} ]",
            .{ self.name, self.id, self.info },
        );
    }
};
