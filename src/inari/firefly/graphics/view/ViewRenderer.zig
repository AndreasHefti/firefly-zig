const std = @import("std");

const graphics = @import("../graphics.zig");
const utils = graphics.utils;
const api = graphics.api;
const Index = api.Index;
const View = graphics.View;
const RenderEvent = api.RenderEvent;
const Component = api.Component;
const System = api.System;
const UNDEF_INDEX = api.UNDEF_INDEX;

pub const ViewRenderEvent = struct {
    view_id: Index,
    layer_id: Index,
};
pub const ViewRenderListener = *const fn (*const ViewRenderEvent) void;

var system_id = UNDEF_INDEX;
var VIEW_RENDER_EVENT_DISPATCHER: utils.EventDispatch(*const ViewRenderEvent) = undefined;
var VIEW_RENDER_EVENT = ViewRenderEvent{
    .view_id = UNDEF_INDEX,
    .layer_id = UNDEF_INDEX,
};

pub fn init() void {
    if (system_id != UNDEF_INDEX)
        return;

    system_id = System.new(System{
        .name = "ViewRenderer",
        .info =
        \\View Renderer emits ViewRenderEvent in order of active Views and its activeLayers
        \\Individual or specialized renderer systems can subscribe to this events and render its parts
        ,
        .onActivation = onActivation,
    }).id;
}

pub fn deinit() void {
    if (system_id == UNDEF_INDEX)
        return;

    System.activateById(system_id, false);
    System.disposeById(system_id);
    system_id = UNDEF_INDEX;
}

pub fn subscribeUpdate(listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.register(listener);
}

pub fn subscribeUpdateAt(index: usize, listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.register(index, listener);
}

pub fn unsubscribeUpdate(listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.unregister(listener);
}

fn onActivation(active: bool) void {
    if (active) {
        api.subscribeRender(render);
    } else {
        api.unsubscribeRender(render);
    }
}

fn render(event: *const RenderEvent) void {
    if (event.type != api.RenderEventType.RENDER)
        return;

    if (View.ordered_active_views.slots.nextSetBit(0) == null) {
        // in this case we have only the screen, no FBO
        api.RENDERING_API.startRendering(null, &View.screen_projection);
        VIEW_RENDER_EVENT.view_id = UNDEF_INDEX;
        VIEW_RENDER_EVENT.layer_id = UNDEF_INDEX;
        VIEW_RENDER_EVENT_DISPATCHER.notify(&VIEW_RENDER_EVENT);
        api.RENDERING_API.endRendering();
    } else {
        // render to all FBO
        var view_it = View.ordered_active_views.iterator();
        while (view_it.next()) |view_id| {
            renderView(View.byId(view_id));
        }

        // rendering all FBO to screen
        view_it = View.ordered_active_views.iterator();
        api.RENDERING_API.startRendering(null, &View.screen_projection);
        while (view_it.next()) |view_id| {
            var view: *View = View.byId(view_id);
            api.RENDERING_API.renderTexture(
                view.render_texture.binding,
                view.transform,
                view.render_data,
                null,
            );
        }
        api.RENDERING_API.endRendering();
    }
}

fn renderView(view: *const View) void {
    // first start rendering to view (FBO)
    api.RENDERING_API.startRendering(view.render_texture.binding, &view.projection);
    // emit render events for all layers of the view in order
    if (view.ordered_active_layer) |layers| {
        var layer_it = layers.iterator();
        while (layer_it.next()) |layer_id| {
            VIEW_RENDER_EVENT.view_id = view.id;
            VIEW_RENDER_EVENT.layer_id = layer_id;
            VIEW_RENDER_EVENT_DISPATCHER.notify(&VIEW_RENDER_EVENT);
        }
    } else {
        VIEW_RENDER_EVENT.view_id = view.id;
        VIEW_RENDER_EVENT.layer_id = UNDEF_INDEX;
        VIEW_RENDER_EVENT_DISPATCHER.notify(&VIEW_RENDER_EVENT);
    }

    api.RENDERING_API.endRendering();
}
