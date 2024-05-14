const std = @import("std");
const firefly = @import("firefly.zig");

const System = firefly.api.System;
const UpdateEvent = firefly.api.UpdateEvent;
const RenderEvent = firefly.api.RenderEvent;
const RenderEventType = firefly.api.RenderEventType;
const UpdateListener = firefly.api.UpdateListener;
const RenderListener = firefly.api.RenderListener;
const WindowData = firefly.api.WindowData;
const Timer = firefly.api.Timer;
const View = firefly.graphics.View;
const String = firefly.utils.String;
const CString = firefly.utils.CString;
const CInt = firefly.utils.CInt;

var UPDATE_EVENT = UpdateEvent{};
var RENDER_EVENT = RenderEvent{ .type = RenderEventType.PRE_RENDER };

pub const CoreSystems = struct {
    pub const StateSystem = struct {
        pub const name = "StateSystem";
        pub fn isActive() bool {
            return isSystemActive(name);
        }
        pub fn activate() void {
            activateSystem(name, true);
        }
        pub fn deactivate() void {
            activateSystem(name, false);
        }
    };

    pub const EntityStateSystem = struct {
        pub const name = "EntityStateSystem";
        pub fn isActive() bool {
            return isSystemActive(name);
        }
        pub fn activate() void {
            activateSystem(name, true);
        }
        pub fn deactivate() void {
            activateSystem(name, false);
        }
    };

    pub const AnimationSystem = struct {
        pub const name = "AnimationSystem";
        pub fn isActive() bool {
            return isSystemActive(name);
        }
        pub fn activate() void {
            activateSystem(name, true);
        }
        pub fn deactivate() void {
            activateSystem(name, false);
        }
    };

    pub const MovementSystem = struct {
        pub const name = "MovementSystem";
        pub fn isActive() bool {
            return isSystemActive(name);
        }
        pub fn activate() void {
            activateSystem(name, true);
        }
        pub fn deactivate() void {
            activateSystem(name, false);
        }
    };

    pub const EntityControlSystem = struct {
        pub const name = "EntityControlSystem";
        pub fn isActive() bool {
            return isSystemActive(name);
        }
        pub fn activate() void {
            activateSystem(name, true);
        }
        pub fn deactivate() void {
            activateSystem(name, false);
        }
    };

    pub const ContactSystem = struct {
        pub const name = "ContactSystem";
        pub fn isActive() bool {
            return isSystemActive(name);
        }
        pub fn activate() void {
            activateSystem(name, true);
        }
        pub fn deactivate() void {
            activateSystem(name, false);
        }
    };
};

pub fn isSystemActive(name: String) bool {
    return System.isActiveByName(name);
}

pub fn activateSystem(name: String, active: bool) void {
    firefly.api.activateSystem(name, active);
}

pub const DefaultRenderer = struct {
    pub const TILE = "DefaultTileGridRenderer";
    pub const SPRITE = "DefaultSpriteRenderer";
    pub const SHAPE = "DefaultShapeRenderer";
    pub const TEXT = "DefaultTextRenderer";

    pub const DEFAULT_RENDER_ORDER = [_]String{
        DefaultRenderer.TILE,
        DefaultRenderer.SPRITE,
        DefaultRenderer.SHAPE,
        DefaultRenderer.TEXT,
    };
};

pub fn activateRenderer(name: String, active: bool) void {
    firefly.api.activateSystem(name, active);
}

pub fn reorderRenderer(new_order: []const String) void {
    for (new_order) |renderer_name| {
        firefly.api.activateSystem(renderer_name, false);
    }
    for (new_order) |renderer_name| {
        firefly.api.activateSystem(renderer_name, true);
    }
}

pub fn start(
    w: CInt,
    h: CInt,
    fps: CInt,
    title: CString,
    init_callback: ?*const fn () void,
) void {
    startWindow(
        .{ .width = w, .height = h, .fps = fps, .title = title },
        init_callback,
    );
}

pub fn startWindow(
    window: WindowData,
    init_callback: ?*const fn () void,
) void {
    reorderRenderer(&DefaultRenderer.DEFAULT_RENDER_ORDER);

    firefly.api.window.openWindow(window);
    defer firefly.api.window.closeWindow();

    View.screen_projection = .{ .plain = .{
        0,
        0,
        @floatFromInt(window.width),
        @floatFromInt(window.height),
    } };
    defer View.screen_projection = undefined;

    if (init_callback) |ic|
        ic();

    while (!firefly.api.window.hasWindowClosed()) {
        tick();
    }
}

pub inline fn subscribeUpdate(listener: UpdateListener) void {
    firefly.api.subscribeUpdate(listener);
}

pub inline fn subscribeUpdateAt(index: usize, listener: UpdateListener) void {
    firefly.api.subscribeUpdateAt(index, listener);
}

pub inline fn unsubscribeUpdate(listener: UpdateListener) void {
    firefly.api.unsubscribeUpdate(listener);
}

pub inline fn subscribeRender(listener: RenderListener) void {
    firefly.api.subscribeRender(listener);
}

pub inline fn subscribeRenderAt(index: usize, listener: RenderListener) void {
    firefly.api.subscribeRenderAt(index, listener);
}

pub inline fn unsubscribeRender(listener: RenderListener) void {
    firefly.api.unsubscribeRender.unregister(listener);
}

/// Performs a tick.Update the Timer, notify UpdateEvent, notify Pre-Render, Render, Post-Render events
pub fn tick() void {
    // update
    Timer.tick();
    firefly.api.update(UPDATE_EVENT);

    // rendering
    RENDER_EVENT.type = RenderEventType.PRE_RENDER;
    firefly.api.render(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.RENDER;
    firefly.api.render(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.POST_RENDER;
    firefly.api.render(RENDER_EVENT);
}
