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

    api.Component.Subtype.register(api.Asset, Font, "Font");
    api.Entity.registerComponent(EText, "EText");
    api.System.register(DefaultTextRenderer);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Font Asset
//////////////////////////////////////////////////////////////

pub const Font = struct {
    pub const Component = api.Component.SubTypeMixin(api.Asset, Font);

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    resource: String,
    size: ?CInt = null,
    char_num: ?CInt,
    code_points: ?CInt,

    _binding: ?BindingId = null,

    pub fn activation(self: *Font, active: bool) void {
        if (active) {
            if (self._binding != null)
                return; // already loaded

            self._binding = firefly.api.rendering.loadFont(
                self.resource,
                self.size,
                self.char_num,
                self.code_points,
            );
        } else {
            if (self._binding) |b| {
                firefly.api.rendering.disposeFont(b);
                self._binding = null;
            }
        }
    }
};

//////////////////////////////////////////////////////////////
//// EText
//////////////////////////////////////////////////////////////

pub const EText = struct {
    pub const Component = api.EntityComponentMixin(EText);

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

pub const DefaultTextRenderer = struct {
    pub const System = api.SystemMixin(DefaultTextRenderer);
    pub const EntityRenderer = graphics.EntityRendererMixin(DefaultTextRenderer);

    pub const accept = .{ graphics.ETransform, EText };

    pub fn renderEntities(entities: *firefly.utils.BitSet, _: graphics.ViewRenderEvent) void {
        var i = entities.nextSetBit(0);
        while (i) |id| {
            // render the sprite
            if (EText.Component.byIdOptional(id)) |text| {
                const trans = graphics.ETransform.Component.byId(id);
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

            i = entities.nextSetBit(id + 1);
        }
    }
};
