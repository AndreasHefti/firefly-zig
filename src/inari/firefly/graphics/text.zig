const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;

const Color = utils.Color;
const BlendMode = api.BlendMode;
const Index = utils.Index;
const Float = utils.Float;
const String = utils.String;
const CInt = utils.CInt;
const CString = utils.CString;
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

    // init Asset types
    api.Asset(Font).init();
    // init components and entities
    api.EComponent.registerEntityComponent(EText);

    // init renderer
    api.System(DefaultTextRenderer).createSystem(
        firefly.Engine.DefaultRenderer.TEXT,
        "Render Entities with ETransform and EText components",
        true,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit Asset types
    api.Asset(Font).deinit();
    // deinit renderer
    api.System(DefaultTextRenderer).disposeSystem();
}

//////////////////////////////////////////////////////////////
//// Font Asset
//////////////////////////////////////////////////////////////

pub const Font = struct {
    pub usingnamespace firefly.api.AssetTrait(Font, "Font");

    name: ?String = null,
    resource: String,
    size: ?CInt = null,
    char_num: ?CInt,
    code_points: ?CInt,

    _binding: ?BindingId = null,

    pub fn loadResource(component: *api.AssetComponent) void {
        if (Font.resourceById(component.resource_id)) |res| {
            if (res._binding != null)
                return; // already loaded

            res._binding = firefly.api.rendering.loadFont(
                res.resource,
                res.size,
                res.char_num,
                res.code_points,
            );
        }
    }

    pub fn disposeResource(component: *api.AssetComponent) void {
        if (Font.resourceById(component.resource_id)) |res| {
            if (res._binding) |b| {
                firefly.api.rendering.disposeFont(b);
                res._binding = null;
            }
        }
    }
};

//////////////////////////////////////////////////////////////
//// EText
//////////////////////////////////////////////////////////////

pub const EText = struct {
    pub usingnamespace api.EComponent.Trait(@This(), "EText");

    id: Index = UNDEF_INDEX,
    font_id: Index = UNDEF_INDEX,
    text: CString,
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
    pub var entity_condition: api.EntityTypeCondition = undefined;
    var text_refs: graphics.ViewLayerMapping = undefined;

    pub fn systemInit() void {
        text_refs = graphics.ViewLayerMapping.new();
        entity_condition = api.EntityTypeCondition{
            .accept_kind = api.EComponentAspectGroup.newKindOf(.{ graphics.ETransform, EText }),
        };
    }

    pub fn systemDeinit() void {
        text_refs.deinit();
        text_refs = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (register)
            text_refs.addWithEView(graphics.EView.byId(id), id)
        else
            text_refs.removeWithEView(graphics.EView.byId(id), id);
    }

    pub fn renderView(e: graphics.ViewRenderEvent) void {
        if (text_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                if (EText.byId(id)) |text| {
                    const trans = graphics.ETransform.byId(id).?;
                    firefly.api.rendering.renderText(
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
