const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const graphics = inari.firefly.graphics;

const System = api.System;
const Entity = api.Entity;
const EComponentAspectGroup = api.EComponentAspectGroup;
const EntityCondition = api.EntityCondition;
const ViewLayerMapping = graphics.ViewLayerMapping;
const EView = graphics.EView;
const ViewRenderEvent = graphics.ViewRenderEvent;
const Component = api.Component;
const ComponentEvent = api.ComponentEvent;
const ActionType = api.Component.ActionType;
const EComponent = api.EComponent;
const Asset = api.Asset;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const ETransform = graphics.ETransform;

const Index = utils.Index;
const Float = utils.Float;
const String = utils.String;
const CInt = utils.CInt;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const BindingId = api.BindingId;

//////////////////////////////////////////////////////////////
//// text init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    // register Assets
    Component.registerComponent(Asset(Font));
    // init components and entities
    EComponent.registerEntityComponent(EText);

    // init renderer
    System(DefaultTextRenderer).createSystem(
        graphics.DefaultRenderer.TEXT,
        "Render Entities with ETransform and EText components",
        true,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit renderer
    System(DefaultTextRenderer).disposeSystem();
}

//////////////////////////////////////////////////////////////
//// Font Asset
//////////////////////////////////////////////////////////////

pub const Font = struct {
    pub usingnamespace api.AssetTrait(Font, "Font");

    name: ?String = null,
    resource: String,
    size: ?CInt = null,
    char_num: ?CInt,
    code_points: ?CInt,

    _binding: ?BindingId = null,

    pub fn doLoad(_: *Asset(Font), resource: *Font) void {
        if (resource._binding != null)
            return; // already loaded

        resource._binding = api.rendering.loadFont(
            resource.resource,
            resource.size,
            resource.char_num,
            resource.code_points,
        );
    }

    pub fn doUnload(_: *Asset(Font), resource: *Font) void {
        if (resource._binding) |b| {
            api.rendering.disposeFont(b);
            resource._binding = null;
        }
    }
};

//////////////////////////////////////////////////////////////
//// EText
//////////////////////////////////////////////////////////////

pub const EText = struct {
    pub usingnamespace EComponent.Trait(@This(), "EText");

    id: Index = UNDEF_INDEX,
    font_id: Index = UNDEF_INDEX,
    text: String,
    tint_color: ?Color = null,
    blend_mode: ?BlendMode = null,
    size: ?Float = null,
    char_spacing: ?Float = null,
    line_spacing: ?Float = null,

    pub fn destruct(self: *EText) void {
        self.font_id = UNDEF_INDEX;
        self.tint_color = null;
        self.blend_mode = null;
        self.size = null;
        self.char_spacing = null;
        self.line_spacing = null;
    }
};

//////////////////////////////////////////////////////////////
//// Default Text Renderer System
//////////////////////////////////////////////////////////////

const DefaultTextRenderer = struct {
    var entity_condition: EntityCondition = undefined;
    var text_refs: ViewLayerMapping = undefined;

    pub fn systemInit() void {
        text_refs = ViewLayerMapping.new();
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{ ETransform, EText }),
        };
    }

    pub fn systemDeinit() void {
        text_refs.deinit();
        text_refs = undefined;
    }

    pub fn notifyEntityChange(e: ComponentEvent) void {
        if (e.c_id) |id| {
            if (!entity_condition.check(id))
                return;

            var eView = EView.byId(id);
            var view_id = if (eView) |v| v.view_id else null;
            var layer_id = if (eView) |v| v.layer_id else null;
            switch (e.event_type) {
                ActionType.ACTIVATED => text_refs.add(view_id, layer_id, id),
                ActionType.DEACTIVATING => text_refs.remove(view_id, layer_id, id),
                else => {},
            }
        }
    }

    pub fn renderView(e: ViewRenderEvent) void {
        if (text_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                if (EText.byId(id)) |text| {
                    var trans = ETransform.byId(id).?;
                    api.rendering.renderText(
                        text.font_id,
                        text.text,
                        trans.position,
                        trans.pivot,
                        trans.rotation,
                        text.size,
                        text.char_spacing,
                        text.line_spacing,
                        text.tint_color,
                        text.blend_mode,
                    );
                }

                i = all.nextSetBit(id + 1);
            }
        }
    }
};