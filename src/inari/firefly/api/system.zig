const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const utils = firefly.utils;

const String = firefly.utils.String;
const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    System.TYPE_REFERENCES = utils.DynArray(System.TypeReference).new(api.COMPONENT_ALLOC);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit all registered systems
    var next = System.TYPE_REFERENCES.slots.prevSetBit(System.TYPE_REFERENCES.size());
    while (next) |i| {
        if (System.TYPE_REFERENCES.get(i)) |interface| {
            interface.deinit();
            System.TYPE_REFERENCES.delete(i);
        }
        next = System.TYPE_REFERENCES.slots.prevSetBit(i);
    }
    System.TYPE_REFERENCES.deinit();
    System.TYPE_REFERENCES = undefined;
}

pub const System = struct {
    const TypeReference = struct {
        name: String,
        deinit: api.DeinitFunction,
        activation: *const fn (bool) void,
        to_string: *const fn (*utils.StringBuffer) void,
    };

    var TYPE_REFERENCES: utils.DynArray(System.TypeReference) = undefined;

    pub fn register(comptime T: type) void {
        SystemMixin(T).init();
    }

    pub fn activate(id: Index, active: bool) void {
        if (TYPE_REFERENCES.get(id)) |ref| ref.activation(active);
    }

    pub fn activateByName(name: String, active: bool) void {
        var next = nextId(0);
        while (next) |i| {
            next = nextId(i + 1);
            if (TYPE_REFERENCES.get(i)) |ref| {
                if (utils.stringEquals(ref.name, name)) {
                    ref.activation(active);
                    return;
                }
            }
        }
    }

    pub fn nextId(index: Index) ?Index {
        return TYPE_REFERENCES.slots.nextSetBit(index);
    }

    pub fn print(string_buffer: *utils.StringBuffer) void {
        string_buffer.print("\nSystems:\n", .{});
        var next = TYPE_REFERENCES.slots.nextSetBit(0);
        while (next) |i| {
            if (TYPE_REFERENCES.get(i)) |interface| interface.to_string(string_buffer);
            next = TYPE_REFERENCES.slots.nextSetBit(i + 1);
        }
    }
};

pub fn SystemMixin(comptime T: type) type {
    const has_entity_update: bool = @hasDecl(T, "EntityUpdate");
    const is_entity_renderer: bool = @hasDecl(T, "EntityRenderer");
    const is_component_renderer: bool = @hasDecl(T, "ComponentRenderer");

    if (@typeInfo(T) != .Struct)
        @compileError("Expects component type is a struct.");

    return struct {
        var system_active = false;
        var entity_condition: ?api.EntityTypeCondition = null;
        var entity_registration: ?*const fn (id: Index, register: bool) void = null;
        var component_condition: ?*const fn (id: Index) bool = null;
        var component_registration: ?*const fn (id: Index, register: bool) void = null;
        var update_listener: ?api.UpdateListener = null;
        var render_listener: ?api.RenderListener = null;
        var view_render_listener: ?api.ViewRenderListener = null;

        pub var system_name: String = undefined;

        fn init() void {
            system_name = @typeName(T);

            _ = System.TYPE_REFERENCES.add(.{
                .name = system_name,
                .deinit = @This().deinit,
                .activation = @This().activation,
                .to_string = @This().print,
            });

            if (@hasDecl(T, "systemInit"))
                T.systemInit();

            if (has_entity_update) {
                T.EntityUpdate.init();
                if (@hasDecl(T.EntityUpdate, "entityRegistration"))
                    entity_registration = T.EntityUpdate.entityRegistration;
                if (@hasDecl(T.EntityUpdate, "entity_condition"))
                    entity_condition = T.EntityUpdate.entity_condition;
                if (@hasDecl(T.EntityUpdate, "update"))
                    update_listener = T.EntityUpdate.update;
            }

            if (is_entity_renderer) {
                T.EntityRenderer.init();
                if (@hasDecl(T.EntityRenderer, "entityRegistration"))
                    entity_registration = T.EntityRenderer.entityRegistration;
                if (@hasDecl(T.EntityRenderer, "entity_condition"))
                    entity_condition = T.EntityRenderer.entity_condition;
                if (@hasDecl(T.EntityRenderer, "render"))
                    render_listener = T.EntityRenderer.render;
                if (@hasDecl(T.EntityRenderer, "renderView"))
                    view_render_listener = T.EntityRenderer.renderView;
            }

            if (is_component_renderer) {
                T.ComponentRenderer.init();
                if (@hasDecl(T.ComponentRenderer, "componentRegistration"))
                    component_registration = T.ComponentRenderer.componentRegistration;
                if (@hasDecl(T.ComponentRenderer, "componentCondition"))
                    component_condition = T.ComponentRenderer.componentCondition;
                if (@hasDecl(T.ComponentRenderer, "render"))
                    render_listener = T.ComponentRenderer.render;
                if (@hasDecl(T.ComponentRenderer, "renderView"))
                    view_render_listener = T.ComponentRenderer.renderView;
            }

            if (@hasDecl(T, "update"))
                update_listener = T.update;
            if (@hasDecl(T, "render"))
                render_listener = T.render;
            if (@hasDecl(T, "renderView"))
                view_render_listener = T.renderView;
            if (@hasDecl(T, "entityRegistration"))
                entity_registration = T.entityRegistration;
            if (@hasDecl(T, "entity_condition"))
                entity_condition = T.entity_condition;
            if (@hasDecl(T, "componentRegistration"))
                component_registration = T.componentRegistration;
            if (@hasDecl(T, "componentCondition"))
                component_condition = T.componentCondition;
        }

        pub fn deinit() void {
            if (system_active)
                deactivate();

            if (@hasDecl(T, "systemDeinit"))
                T.systemDeinit();
            if (has_entity_update)
                T.EntityUpdate.deinit();
            if (is_entity_renderer)
                T.EntityRenderer.deinit();
            if (is_component_renderer)
                T.ComponentRenderer.deinit();

            system_name = undefined;
        }

        pub fn activate() void {
            activation(true);
        }

        pub fn deactivate() void {
            activation(false);
        }

        fn activation(active: bool) void {
            if (active) {
                if (system_active)
                    return;

                std.debug.print("FIREFLY : INFO: Activate System: {?s}\n", .{system_name});
                if (entity_registration) |_| {
                    api.Entity.Subscription.subscribe(notifyEntityChange);
                }
                if (getComponentRegType()) |reg_type| {
                    reg_type.Subscription.subscribe(notifyComponentChange);
                }
                if (update_listener) |listener| {
                    firefly.api.subscribeUpdate(listener);
                }
                if (render_listener) |listener| {
                    firefly.api.subscribeRender(listener);
                }
                if (view_render_listener) |listener| {
                    firefly.api.subscribeViewRender(listener);
                }

                system_active = true;
            } else {
                if (!system_active)
                    return;

                std.debug.print("FIREFLY : INFO: Deactivate System: {?s}\n", .{system_name});
                if (entity_registration) |_| {
                    api.Entity.Subscription.unsubscribe(notifyEntityChange);
                }
                if (getComponentRegType()) |reg_type| {
                    reg_type.Subscription.unsubscribe(notifyComponentChange);
                }
                if (update_listener) |listener| {
                    firefly.api.unsubscribeUpdate(listener);
                }
                if (render_listener) |listener| {
                    firefly.api.unsubscribeRender(listener);
                }
                if (view_render_listener) |listener| {
                    firefly.api.unsubscribeViewRender(listener);
                }

                system_active = false;
            }
            if (@hasDecl(T, "activation"))
                T.activation(active);
        }

        fn getComponentRegType() ?type {
            if (has_entity_update)
                if (@hasDecl(T.EntityUpdate, "component_register_type"))
                    return T.EntityUpdate.component_register_type;
            if (is_component_renderer)
                if (@hasDecl(T.ComponentRenderer, "component_register_type"))
                    return T.ComponentRenderer.component_register_type;

            if (@hasDecl(T, "component_register_type"))
                return T.component_register_type;

            return null;
        }

        fn notifyComponentChange(e: api.ComponentEvent) void {
            if (component_registration) |c_reg| {
                if (e.c_id) |id| {
                    if (component_condition) |cid| {
                        if (!cid(e.c_id.?))
                            return;
                    }

                    switch (e.event_type) {
                        .ACTIVATED => c_reg(id, true),
                        .DEACTIVATING => c_reg(id, false),
                        else => {},
                    }
                }
            }
        }

        fn notifyEntityChange(e: api.ComponentEvent) void {
            if (entity_registration) |e_reg| {
                if (e.c_id) |id| {
                    if (entity_condition) |*etc| {
                        if (@typeInfo(@TypeOf(etc)) == .Optional) {
                            if (etc) |*ec| {
                                if (!ec.check(id))
                                    return;
                            }
                        } else {
                            if (!etc.check(id))
                                return;
                        }
                    }

                    switch (e.event_type) {
                        .ACTIVATED => e_reg(id, true),
                        .DEACTIVATING => e_reg(id, false),
                        else => {},
                    }
                }
            }
        }

        pub fn print(string_buffer: *utils.StringBuffer) void {
            string_buffer.print("  ({s}) {s}\n", .{ if (system_active) "a" else "x", system_name });
        }
    };
}
