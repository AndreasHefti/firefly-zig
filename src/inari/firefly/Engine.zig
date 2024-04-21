const std = @import("std");
const inari = @import("../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const CString = utils.CString;
const Float = utils.Float;

const Allocator = std.mem.Allocator;
const UpdateEvent = api.UpdateEvent;
const RenderEvent = api.RenderEvent;
const RenderEventType = api.RenderEventType;
const EventDispatch = utils.EventDispatch;
const UpdateListener = api.UpdateListener;
const RenderListener = api.RenderListener;
const Timer = api.Timer;
const View = inari.firefly.graphics.View;
const String = utils.String;

var UPDATE_EVENT = UpdateEvent{};
var RENDER_EVENT = RenderEvent{ .type = RenderEventType.PRE_RENDER };

pub const DefaultRenderer = struct {
    pub const SHAPE = "DefaultShapeRenderer";
    pub const SPRITE = "DefaultSpriteRenderer";
    pub const TILE = "DefaultTileGridRenderer";
    pub const TEXT = "DefaultTextRenderer";
};

pub fn activateRenderer(name: String, active: bool) void {
    api.activateSystem(name, active);
}

pub fn reorderRenderer(new_order: []const String) void {
    for (new_order) |renderer_name| {
        api.activateSystem(renderer_name, false);
    }
    for (new_order) |renderer_name| {
        api.activateSystem(renderer_name, true);
    }
}

pub fn start(
    w: Float,
    h: Float,
    fps: c_int,
    title: CString,
    init_callback: ?*const fn () void,
) void {
    api.window.openWindow(.{
        .width = @intFromFloat(w),
        .height = @intFromFloat(h),
        .title = title,
        .fps = fps,
    });
    defer api.window.closeWindow();

    View.screen_projection = .{ .plain = .{ 0, 0, w, h } };
    defer View.screen_projection = undefined;

    if (init_callback) |ic|
        ic();

    while (!api.window.hasWindowClosed()) {
        tick();
    }
}

pub inline fn subscribeUpdate(listener: UpdateListener) void {
    api.subscribeUpdate(listener);
}

pub inline fn subscribeUpdateAt(index: usize, listener: UpdateListener) void {
    api.subscribeUpdateAt(index, listener);
}

pub inline fn unsubscribeUpdate(listener: UpdateListener) void {
    api.unsubscribeUpdate(listener);
}

pub inline fn subscribeRender(listener: RenderListener) void {
    api.subscribeRender(listener);
}

pub inline fn subscribeRenderAt(index: usize, listener: RenderListener) void {
    api.subscribeRenderAt(index, listener);
}

pub inline fn unsubscribeRender(listener: RenderListener) void {
    api.unsubscribeRender.unregister(listener);
}

/// Performs a tick.Update the Timer, notify UpdateEvent, notify Pre-Render, Render, Post-Render events
pub fn tick() void {
    // update
    Timer.tick();
    api.update(UPDATE_EVENT);

    // rendering
    RENDER_EVENT.type = RenderEventType.PRE_RENDER;
    api.render(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.RENDER;
    api.render(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.POST_RENDER;
    api.render(RENDER_EVENT);
}
