const std = @import("std");
const inari = @import("../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const CString = utils.CString;

const Allocator = std.mem.Allocator;
const UpdateEvent = api.UpdateEvent;
const RenderEvent = api.RenderEvent;
const RenderEventType = api.RenderEventType;
const EventDispatch = utils.EventDispatch;
const UpdateListener = api.UpdateListener;
const RenderListener = api.RenderListener;
const Timer = api.Timer;
//const rl = @cImport(@cInclude("raylib.h"));

// private state
var UPDATE_EVENT_DISPATCHER: EventDispatch(UpdateEvent) = undefined;
var RENDER_EVENT_DISPATCHER: EventDispatch(RenderEvent) = undefined;
var UPDATE_EVENT = UpdateEvent{};
var RENDER_EVENT = RenderEvent{ .type = RenderEventType.PRE_RENDER };

var initialized = false;
pub fn init() void {
    UPDATE_EVENT_DISPATCHER = EventDispatch(UpdateEvent).new(api.ALLOC);
    RENDER_EVENT_DISPATCHER = EventDispatch(RenderEvent).new(api.ALLOC);
}

pub fn deinit() void {
    UPDATE_EVENT_DISPATCHER.deinit();
    RENDER_EVENT_DISPATCHER.deinit();
}

pub fn start(
    w: c_int,
    h: c_int,
    fps: c_int,
    title: CString,
    init_callback: ?*const fn () void,
) void {
    api.window.openWindow(.{ .width = w, .height = h, .title = title, .fps = fps });
    defer api.window.closeWindow();

    if (init_callback) |ic|
        ic();

    while (!api.window.hasWindowClosed()) {
        tick();
    }
}

pub fn subscribeUpdate(listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.register(listener);
}

pub fn subscribeUpdateAt(index: usize, listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.register(index, listener);
}

pub fn unsubscribeUpdate(listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.unregister(listener);
}

pub fn subscribeRender(listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.register(listener);
}

pub fn subscribeRenderAt(index: usize, listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.register(index, listener);
}

pub fn unsubscribeRender(listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.unregister(listener);
}

/// Performs a tick.Update the Timer, notify UpdateEvent, notify Pre-Render, Render, Post-Render events
pub fn tick() void {
    // update
    Timer.tick();
    UPDATE_EVENT_DISPATCHER.notify(UPDATE_EVENT);

    // rendering
    RENDER_EVENT.type = RenderEventType.PRE_RENDER;
    RENDER_EVENT_DISPATCHER.notify(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.RENDER;
    RENDER_EVENT_DISPATCHER.notify(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.POST_RENDER;
    RENDER_EVENT_DISPATCHER.notify(RENDER_EVENT);
}