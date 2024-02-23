const std = @import("std");
const Allocator = std.mem.Allocator;

const api = @import("api.zig");
const utils = api.utils;
const UpdateEvent = api.UpdateEvent;
const RenderEvent = api.RenderEvent;
const RenderEventType = api.RenderEventType;
const EventDispatch = utils.EventDispatch;
const UpdateListener = api.UpdateListener;
const RenderListener = api.RenderListener;
const Timer = api.Timer;

// private state
var UPDATE_EVENT_DISPATCHER: EventDispatch(UpdateEvent) = undefined;
var RENDER_EVENT_DISPATCHER: EventDispatch(RenderEvent) = undefined;
var UPDATE_EVENT = UpdateEvent{};
var RENDER_EVENT = RenderEvent{ .type = RenderEventType.PRE_RENDER };

var initialized = false;
pub fn init() void {
    UPDATE_EVENT_DISPATCHER = EventDispatch(UpdateEvent).init(api.ALLOC);
    RENDER_EVENT_DISPATCHER = EventDispatch(RenderEvent).init(api.ALLOC);
}

pub fn deinit() void {
    UPDATE_EVENT_DISPATCHER.deinit();
    RENDER_EVENT_DISPATCHER.deinit();
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
    Timer.tick();
    UPDATE_EVENT_DISPATCHER.notify(UPDATE_EVENT);

    RENDER_EVENT.type = RenderEventType.PRE_RENDER;
    RENDER_EVENT_DISPATCHER.notify(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.RENDER;
    RENDER_EVENT_DISPATCHER.notify(RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.POST_RENDER;
    RENDER_EVENT_DISPATCHER.notify(RENDER_EVENT);
}
