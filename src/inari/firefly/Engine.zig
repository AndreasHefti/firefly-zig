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
var running = false;

// TODO remove this after System refactoring. Use Traits instead
pub const CoreSystems = struct {
    pub const STATE = "StateSystem";
    pub const ENTITY_STATE = "EntityStateSystem";
    pub const ANIMATION = "AnimationSystem";
    pub const MOVEMENT = "MovementSystem";
    pub const CONTACT = "ContactSystem";

    pub const VIEW_RENDERER = "ViewRenderer";
    pub const TILE_RENDERER = "DefaultTileGridRenderer";
    pub const SPRITE_RENDERER = "DefaultSpriteRenderer";
    pub const SHAPE_RENDERER = "DefaultShapeRenderer";
    pub const TEXT_RENDERER = "DefaultTextRenderer";

    pub const DEFAULT_SYSTEM_ORDER = [_]String{
        CoreSystems.ENTITY_STATE,
        CoreSystems.ANIMATION,
        CoreSystems.MOVEMENT,

        CoreSystems.VIEW_RENDERER,
        CoreSystems.TILE_RENDERER,
        CoreSystems.SPRITE_RENDERER,
        CoreSystems.SHAPE_RENDERER,
        CoreSystems.TEXT_RENDERER,
    };
};

pub fn reorderSystems(new_order: []const String) void {
    var next = firefly.api.System.nextActiveId(0);
    while (next) |id| {
        firefly.api.System.activateById(id, false);
        next = firefly.api.System.nextActiveId(id + 1);
    }
    for (new_order) |name| {
        firefly.api.System.activateByName(name, true);
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
    reorderSystems(&CoreSystems.DEFAULT_SYSTEM_ORDER);

    firefly.api.window.openWindow(window);

    View.screen_projection.width = @floatFromInt(window.width);
    View.screen_projection.height = @floatFromInt(window.height);
    defer View.screen_projection = .{};

    if (init_callback) |ic|
        ic();

    running = true;
    while (!firefly.api.window.hasWindowClosed() and running)
        tick();

    firefly.api.window.closeWindow();
}

pub fn stop() void {
    running = false;
}

pub fn registerQuitKey(quit_key: firefly.api.KeyboardKey) void {
    firefly.api.input.setKeyMapping(quit_key, firefly.api.InputButtonType.QUIT);
    firefly.api.subscribeUpdate(update);
}

pub fn update(_: firefly.api.UpdateEvent) void {
    if (firefly.api.input.checkButtonTyped(firefly.api.InputButtonType.QUIT)) {
        firefly.api.unsubscribeUpdate(update);
        firefly.Engine.stop();
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

    if (!running) return;

    // rendering
    RENDER_EVENT.type = RenderEventType.PRE_RENDER;
    firefly.api.render(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.RENDER;
    firefly.api.render(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.POST_RENDER;
    firefly.api.render(RENDER_EVENT);
}
