const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const graphics = inari.firefly.graphics;

const DynArray = utils.DynArray;
const DynIndexArray = utils.DynIndexArray;
const Asset = api.Asset;
const String = utils.String;
const Component = api.Component;
const ComponentEvent = api.Component.ComponentEvent;
const ActionType = api.Component.ActionType;
const Texture = graphics.Texture;
const EComponent = api.EComponent;
const EComponentAspectGroup = api.EComponentAspectGroup;
const EntityCondition = api.EntityCondition;
const ETransform = graphics.ETransform;
const EMultiplier = graphics.EMultiplier;
const ViewLayerMapping = graphics.ViewLayerMapping;
const ViewRenderEvent = graphics.ViewRenderEvent;
const System = api.System;
const BindingId = api.BindingId;
const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const Float = utils.Float;
const RectF = utils.RectF;
const Vec2f = utils.Vector2f;
const Color = utils.Color;
const BlendMode = api.BlendMode;

//////////////////////////////////////////////////////////////
//// sprite init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    // register Assets
    Component.registerComponent(Asset(SpriteSet));
    // init components and entities
    Component.registerComponent(SpriteTemplate);
    EComponent.registerEntityComponent(ESprite);
    // init renderer
    System(SimpleSpriteRenderer).createSystem(
        "SimpleSpriteRenderer",
        "Render Entities with ETransform and ESprite components",
        true,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit renderer
    System(SimpleSpriteRenderer).disposeSystem();
}

//////////////////////////////////////////////////////////////
//// Sprite Template Components
//////////////////////////////////////////////////////////////

pub const SpriteTemplate = struct {
    pub usingnamespace Component.Trait(
        @This(),
        .{
            .name = "SpriteTemplate",
            .activation = false,
            .processing = false,
            .subscription = false,
        },
    );

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    texture_name: String,
    texture_bounds: RectF,
    texture_binding: BindingId = NO_BINDING,
    flip_x: bool = false,
    flip_y: bool = false,

    pub fn componentTypeInit() !void {
        Asset(Texture).subscribe(notifyAssetEvent);
    }

    pub fn componentTypeDeinit() void {
        Asset(Texture).unsubscribe(notifyAssetEvent);
    }

    // TODO add construct to automatically bind the texture if it is already loaded
    pub fn construct(self: *SpriteTemplate) void {
        if (Texture.getResourceByName(self.texture_name)) |tex| {
            if (tex.binding) |b| {
                self.texture_binding = b.id;
            }
        }
    }

    fn notifyAssetEvent(e: ComponentEvent) void {
        var asset: *Asset(Texture) = Asset(Texture).byId(e.c_id.?);
        if (asset.name == null)
            return;

        switch (e.event_type) {
            ActionType.ACTIVATED => onTextureLoad(asset),
            ActionType.DEACTIVATING => onTextureUnload(asset),
            ActionType.DISPOSING => onTextureDispose(asset),
            else => {},
        }
    }

    fn onTextureLoad(asset: *Asset(Texture)) void {
        if (asset.getResource()) |r| {
            if (r.binding) |b| {
                var next = SpriteTemplate.nextId(0);
                while (next) |id| {
                    var template = SpriteTemplate.byId(id);
                    if (asset.name) |an| {
                        if (utils.stringEquals(template.texture_name, an)) {
                            template.texture_binding = b.id;
                        }
                    }
                    next = SpriteTemplate.nextId(id + 1);
                }
            }
        }
    }

    fn onTextureUnload(asset: *Asset(Texture)) void {
        var next = SpriteTemplate.nextId(0);
        while (next) |id| {
            var template = SpriteTemplate.byId(id);
            if (asset.name) |an| {
                if (utils.stringEquals(template.texture_name, an)) {
                    template.texture_binding = NO_BINDING;
                }
            }
            next = SpriteTemplate.nextId(id + 1);
        }
    }

    fn onTextureDispose(asset: *Asset(Texture)) void {
        var next = SpriteTemplate.nextId(0);
        while (next) |id| {
            var template = SpriteTemplate.byId(id);
            if (asset.name) |an| {
                if (utils.stringEquals(template.texture_name, an)) {
                    SpriteTemplate.disposeById(id);
                }
            }
            next = SpriteTemplate.nextId(id + 1);
        }
    }

    pub fn format(
        self: SpriteTemplate,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "SpriteTemplate[ id:{d}, name:{?s}, texture_name:{?s}, bounds:{any}, binding:{any}, flip_x:{any}, flip_y:{any} ]",
            self,
        );
    }
};

//////////////////////////////////////////////////////////////
//// ESprite Sprite Entity Component
//////////////////////////////////////////////////////////////

pub const ESprite = struct {
    pub usingnamespace EComponent.Trait(@This(), "ESprite");

    id: Index = UNDEF_INDEX,
    template_id: Index = UNDEF_INDEX,
    tint_color: ?Color = null,
    blend_mode: ?BlendMode = null,

    _texture_bounds: RectF = undefined,
    _texture_binding: BindingId = NO_BINDING,

    pub fn activation(self: *ESprite, active: bool) void {
        if (active) {
            if (self.template_id == UNDEF_INDEX)
                @panic("Missing template_id");

            var template = SpriteTemplate.byId(self.template_id);
            self._texture_bounds = template.texture_bounds;
            self._texture_binding = template.texture_binding;

            if (template.flip_x) {
                self._texture_bounds[2] = -self._texture_bounds[2];
            }
            if (template.flip_y) {
                self._texture_bounds[3] = -self._texture_bounds[3];
            }
        } else {
            self._texture_bounds = undefined;
            self._texture_binding = UNDEF_INDEX;
        }
    }

    pub fn destruct(self: *ESprite) void {
        self.template_id = UNDEF_INDEX;
        self._texture_bounds = undefined;
        self._texture_binding = NO_BINDING;
        self.tint_color = null;
        self.blend_mode = null;
    }
};

//////////////////////////////////////////////////////////////
//// Sprite Set Asset
//////////////////////////////////////////////////////////////

pub const SpriteStamp = struct {
    name: ?String = null,
    sprite_dim: ?RectF = null,
    flip_x: bool = false,
    flip_y: bool = false,
};

pub const SpriteSet = struct {
    pub usingnamespace api.AssetTrait(SpriteSet, "SpriteSet");

    _stamps: DynArray(SpriteStamp) = undefined,
    _loaded_sprite_template_refs: DynIndexArray = undefined,

    name: String,
    texture_name: String,
    default_stamp: ?SpriteStamp = null,
    set_dimensions: ?Vec2f = null,

    pub fn construct(self: SpriteSet) void {
        self._stamps = DynArray(SpriteStamp).new(api.COMPONENT_ALLOC);
        self._sprite_template_refs = DynIndexArray.init(api.COMPONENT_ALLOC, 32);
    }

    pub fn deconstruct(self: SpriteSet) void {
        self._stamps.deinit();
        self._stamps = undefined;
        self._sprite_template_refs.deinit();
        self._sprite_template_refs = undefined;
    }

    pub fn addStamp(self: *SpriteSet, stamp: SpriteStamp) void {
        self._stamps.add(stamp);
    }
    pub fn setStamp(self: *SpriteSet, index: usize, stamp: SpriteStamp) void {
        self._stamps.set(index, stamp);
    }
    pub fn setStampOnMap(self: *SpriteSet, x: usize, y: usize, stamp: SpriteStamp) void {
        if (self.set_dimensions) |d| {
            self.setStamp(y * d[0] + x, stamp);
        }
    }

    pub fn doLoad(_: *Asset(SpriteSet), resource: *SpriteSet) void {
        if (resource.set_dimensions) |dim| {
            // in this case we interpret the texture as a grid-map of sprites and use default stamp
            if (resource.default_stamp == null)
                @panic("SpriteSet needs default_stamp when loading with set_dimensions");

            var default_stamp = resource.default_stamp.?;
            if (default_stamp.sprite_dim == null)
                @panic("SpriteSet needs default_stamp with sprite_dim");

            var width: usize = @intFromFloat(dim[0]);
            var height: usize = @intFromFloat(dim[1]);
            var default_dim = default_stamp.sprite_dim.?;
            var default_prefix = if (default_stamp.name) |p| p else resource.name;

            for (0..height) |y| { // 0..height
                for (0..width) |x| { // 0..width
                    if (resource._stamps.get(y * width + x)) |stamp| {
                        // use the stamp merged with default stamp
                        resource._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                            .name = getMapName(stamp.name, default_prefix, x, y),
                            .texture_name = resource.texture_name,
                            .texture_bounds = stamp.sprite_dim.?,
                            .flip_x = stamp.flip_x,
                            .flip_y = stamp.flip_y,
                        }));
                    } else {
                        // use the default stamp
                        resource._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                            .name = getMapName(null, default_prefix, x, y),
                            .texture_name = resource.texture_name,
                            .texture_bounds = RectF{
                                @as(Float, @floatFromInt(x)) * default_dim[2],
                                @as(Float, @floatFromInt(y)) * default_dim[3],
                                default_dim[2],
                                default_dim[3],
                            },
                            .flip_x = default_stamp.flip_x,
                            .flip_y = default_stamp.flip_y,
                        }));
                    }
                }
            }
        } else {
            // in this case just load the existing stamps that has defined sprite_dim (others are ignored)
            var default_prefix = if (resource.default_stamp.?.name) |p| p else resource.name;
            var next = resource._stamps.slots.nextSetBit(0);
            while (next) |i| {
                if (resource._stamps.get(i)) |stamp| {
                    if (stamp.sprite_dim) |s_dim| {
                        resource._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                            .name = getMapName(stamp.name, default_prefix, i, null),
                            .texture_name = resource.texture_name,
                            .texture_bounds = s_dim,
                            .flip_x = stamp.flip_x,
                            .flip_y = stamp.flip_y,
                        }));
                    }
                }
                next = resource._stamps.slots.nextSetBit(i + 1);
            }
        }
    }

    pub fn doUnload(_: *Asset(SpriteSet), resource: *SpriteSet) void {
        for (resource._loaded_sprite_template_refs.items) |index| {
            SpriteTemplate.disposeById(index);
        }
        resource._loaded_sprite_template_refs.clear();
    }

    fn getMapName(name: ?String, prefix: String, x: usize, y: ?usize) String {
        if (name) |n| return n;

        if (y) |_y| {
            return std.fmt.allocPrint(api.ALLOC, "{s}_{d}_{d}", .{ prefix, x, _y }) catch unreachable;
        } else {
            return std.fmt.allocPrint(api.ALLOC, "{s}_{d}", .{ prefix, x }) catch unreachable;
        }
    }
};

//////////////////////////////////////////////////////////////
//// Simple Sprite Renderer System
//////////////////////////////////////////////////////////////

const SimpleSpriteRenderer = struct {
    pub const view_render_order: usize = 0;
    var entity_condition: EntityCondition = undefined;
    var sprite_refs: ViewLayerMapping = undefined;

    pub fn systemInit() void {
        sprite_refs = ViewLayerMapping.new();
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{ ETransform, ESprite }),
            .dismiss_kind = EComponentAspectGroup.newKindOf(.{EMultiplier}),
        };
    }

    pub fn systemDeinit() void {
        entity_condition = undefined;
        sprite_refs.deinit();
        sprite_refs = undefined;
    }

    pub fn notifyEntityChange(e: ComponentEvent) void {
        if (e.c_id == null or !entity_condition.check(e.c_id.?))
            return;

        var transform = ETransform.byId(e.c_id.?);
        switch (e.event_type) {
            ActionType.ACTIVATED => sprite_refs.add(transform.view_id, transform.layer_id, e.c_id.?),
            ActionType.DEACTIVATING => sprite_refs.remove(transform.view_id, transform.layer_id, e.c_id.?),
            else => {},
        }
    }

    pub fn renderView(e: ViewRenderEvent) void {
        if (sprite_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                var es = ESprite.byId(id);
                var trans = ETransform.byId(id);
                if (es.template_id != NO_BINDING) {
                    api.rendering.renderSprite(
                        es._texture_binding,
                        &es._texture_bounds,
                        &trans.position,
                        &trans.pivot,
                        &trans.scale,
                        &trans.rotation,
                        &es.tint_color,
                        es.blend_mode,
                    );
                }
                i = all.nextSetBit(id + 1);
            }
        }
    }
};
