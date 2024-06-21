const std = @import("std");
const firefly = @import("../firefly.zig");

const System = firefly.api.System;
const EComponentAspectGroup = firefly.api.EComponentAspectGroup;
const EntityTypeCondition = firefly.api.EntityTypeCondition;
const ViewLayerMapping = firefly.graphics.ViewLayerMapping;
const EView = firefly.graphics.EView;
const ViewRenderEvent = firefly.graphics.ViewRenderEvent;
const Component = firefly.api.Component;
const EComponent = firefly.api.EComponent;
const AssetComponent = firefly.api.AssetComponent;
const Asset = firefly.api.Asset;
const Color = firefly.utils.Color;
const BlendMode = firefly.api.BlendMode;
const ETransform = firefly.graphics.ETransform;
const Index = firefly.utils.Index;
const Float = firefly.utils.Float;
const String = firefly.utils.String;
const CInt = firefly.utils.CInt;
const CString = firefly.utils.CString;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const BindingId = firefly.api.BindingId;

//////////////////////////////////////////////////////////////
//// text init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    // init Asset types
    Asset(Font).init();
    // init components and entities
    EComponent.registerEntityComponent(EText);

    // init renderer
    System(DefaultTextRenderer).createSystem(
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
    Asset(Font).deinit();
    // deinit renderer
    System(DefaultTextRenderer).disposeSystem();
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

    pub fn loadResource(component: *AssetComponent) void {
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

    pub fn disposeResource(component: *AssetComponent) void {
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
    pub usingnamespace EComponent.Trait(@This(), "EText");

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
    pub var entity_condition: EntityTypeCondition = undefined;
    var text_refs: ViewLayerMapping = undefined;

    pub fn systemInit() void {
        text_refs = ViewLayerMapping.new();
        entity_condition = EntityTypeCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{ ETransform, EText }),
        };
    }

    pub fn systemDeinit() void {
        text_refs.deinit();
        text_refs = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (register)
            text_refs.addWithEView(EView.byId(id), id)
        else
            text_refs.removeWithEView(EView.byId(id), id);
    }

    pub fn renderView(e: ViewRenderEvent) void {
        if (text_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                if (EText.byId(id)) |text| {
                    const trans = ETransform.byId(id).?;
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
