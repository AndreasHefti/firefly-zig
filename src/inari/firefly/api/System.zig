const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const Component = api.Component;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.API.registerComponent(SystemComponent);
}

pub fn deinit() void {
    defer initialized = true;
    if (!initialized)
        return;

    Component.API.deinitComponent(SystemComponent);
}

pub fn System(comptime T: type) type {
    comptime var has_construct: bool = false;
    comptime var has_activation: bool = false;
    comptime var has_destruct: bool = false;

    comptime var has_update_event_subscription: bool = false;
    comptime var has_render_event_subscription: bool = false;
    comptime var has_entity_event_subscription: bool = false;

    comptime {
        if (!trait.is(.Struct)(T))
            @compileError("Expects component type is a struct.");

        has_construct = trait.hasDecls(T, .{"onConstruct"});
        has_activation = trait.hasDecls(T, .{"onActivation"});
        has_destruct = trait.hasDecls(T, .{"onDestruct"});

        has_update_event_subscription = trait.hasDecls(T, .{"update_event_subscription"});
        has_render_event_subscription = trait.hasDecls(T, .{"render_event_subscription"});
        has_entity_event_subscription = trait.hasDecls(T, .{"entity_event_subscription"});
    }

    return struct {
        const Self = @This();

        var type_init = false;
        var component_ref: ?*SystemComponent = null;

        pub fn init(name: String, info: String) void {
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
            if (has_entity_event_subscription)
                T.entity_event_subscription.subscribe();
        }

        pub fn deinit() void {
            defer type_init = false;
            if (!type_init)
                return;

            if (has_entity_event_subscription)
                T.entity_event_subscription.unsubscribe();

            if (component_ref) |ref| {
                component_ref = null;
                SystemComponent.disposeById(ref.id);
            }
        }

        fn destruct() void {
            if (has_destruct)
                T.onDestruct();
        }

        pub fn activate() void {
            if (component_ref) |c| SystemComponent.activateById(c.id, true);
        }

        pub fn deactivate() void {
            if (component_ref) |c| SystemComponent.activateById(c.id, false);
        }
    };
}

pub const SystemComponent = struct {
    pub usingnamespace Component.API.ComponentTrait(SystemComponent, .{ .name = "System", .subscription = false });
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
