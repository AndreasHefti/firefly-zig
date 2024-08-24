const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;

const String = utils.String;
const BindingId = api.BindingId;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const Float = utils.Float;
const RectF = utils.RectF;
const PosF = utils.PosF;
const Vector2f = utils.Vector2f;
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

    api.Asset.registerSubtype(SpriteSet);
    api.Component.registerComponent(SpriteTemplate);
    api.EComponent.registerEntityComponent(ESprite);
    DefaultSpriteRenderer.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Sprite Template Components
//////////////////////////////////////////////////////////////

pub const SpriteTemplate = struct {
    pub usingnamespace api.Component.Trait(
        @This(),
        .{
            .name = "SpriteTemplate",
            .activation = false,
            .subscription = false,
        },
    );

    id: Index = utils.UNDEF_INDEX,
    name: ?String = null,
    texture_name: String,
    texture_bounds: RectF,
    texture_binding: BindingId = utils.UNDEF_INDEX,

    _flippedX: bool = false,
    _flippedY: bool = false,

    pub fn flipX(self: *SpriteTemplate) *SpriteTemplate {
        self.texture_bounds[2] = -self.texture_bounds[2];
        self._flippedX = !self._flippedX;
        return self;
    }

    pub fn flipY(self: *SpriteTemplate) *SpriteTemplate {
        self.texture_bounds[3] = -self.texture_bounds[3];
        self._flippedY = !self._flippedY;
        return self;
    }

    pub fn componentTypeInit() !void {
        api.Asset.subscribe(notifyAssetEvent);
    }

    pub fn componentTypeDeinit() void {
        api.Asset.unsubscribe(notifyAssetEvent);
    }

    pub fn construct(self: *SpriteTemplate) void {
        if (graphics.Texture.byName(self.texture_name)) |tex| {
            if (tex._binding) |b| {
                self.texture_binding = b.id;
            }
        }
    }

    fn notifyAssetEvent(e: api.ComponentEvent) void {
        if (e.c_id) |id| {
            switch (e.event_type) {
                .ACTIVATED => onTextureLoad(graphics.Texture.byId(id)),
                .DEACTIVATING => onTextureClose(api.Asset.byId(id).name.?),
                .DISPOSING => onTextureDispose(api.Asset.byId(id).name.?),
                else => {},
            }
        }
    }

    fn onTextureLoad(texture: *graphics.Texture) void {
        if (texture._binding) |b| {
            var next = SpriteTemplate.nextId(0);
            while (next) |id| {
                var template = SpriteTemplate.byId(id);
                if (firefly.utils.stringEquals(template.texture_name, texture.name))
                    template.texture_binding = b.id;

                next = SpriteTemplate.nextId(id + 1);
            }
        }
    }

    fn onTextureClose(name: String) void {
        var next = SpriteTemplate.nextId(0);
        while (next) |id| {
            var template = SpriteTemplate.byId(id);
            if (firefly.utils.stringEquals(template.texture_name, name))
                template.texture_binding = utils.UNDEF_INDEX;

            next = SpriteTemplate.nextId(id + 1);
        }
    }

    fn onTextureDispose(name: String) void {
        var next = SpriteTemplate.nextId(0);
        while (next) |id| {
            const template = SpriteTemplate.byId(id);
            if (firefly.utils.stringEquals(template.texture_name, name))
                SpriteTemplate.disposeById(id);

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
    pub usingnamespace api.EComponent.Trait(@This(), "ESprite");

    id: Index = utils.UNDEF_INDEX,
    template_id: Index = utils.UNDEF_INDEX,
    tint_color: ?Color = null,
    blend_mode: ?BlendMode = null,

    pub fn destruct(self: *ESprite) void {
        self.template_id = utils.UNDEF_INDEX;
        self.tint_color = null;
        self.blend_mode = null;
    }

    pub const Property = struct {
        pub fn FrameId(id: Index) *Index {
            return &ESprite.byId(id).?.template_id;
        }
        pub fn TintColor(id: Index) *Color {
            var sprite = ESprite.byId(id).?;
            if (sprite.tint_color == null)
                sprite.tint_color = Color{ 255, 255, 255, 255 };

            return &sprite.tint_color.?;
        }
    };
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
    pub usingnamespace firefly.api.AssetTrait(SpriteSet, "SpriteSet");

    _stamps: utils.DynArray(SpriteStamp) = undefined,
    _loaded_sprite_template_refs: utils.DynIndexArray = undefined,

    id: Index = UNDEF_INDEX,
    name: String,
    texture_name: String,
    default_stamp: ?SpriteStamp = null,
    set_dimensions: ?Vector2f = null,

    pub fn construct(self: *SpriteSet) void {
        self._stamps = utils.DynArray(SpriteStamp).new(firefly.api.COMPONENT_ALLOC);
        self._sprite_template_refs = utils.DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 32);
    }

    pub fn destruct(self: *SpriteSet) void {
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

    pub fn activation(self: *SpriteSet, active: bool) void {
        if (active) {
            load(self);
        } else {
            close(self);
        }
    }

    fn load(res: *SpriteSet) void {
        if (res.set_dimensions) |dim| {
            // in this case we interpret the texture as a grid-map of sprites and use default stamp
            if (res.default_stamp == null)
                @panic("SpriteSet needs default_stamp when loading with set_dimensions");

            const default_stamp = res.default_stamp.?;
            if (default_stamp.sprite_dim == null)
                @panic("SpriteSet needs default_stamp with sprite_dim");

            const width: usize = @intFromFloat(dim[0]);
            const height: usize = @intFromFloat(dim[1]);
            const default_dim = default_stamp.sprite_dim.?;
            const default_prefix = if (default_stamp.name) |p| p else res.name;

            for (0..height) |y| { // 0..height
                for (0..width) |x| { // 0..width
                    if (res._stamps.get(y * width + x)) |stamp| {
                        // use the stamp merged with default stamp
                        res._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                            .name = getMapName(stamp.name, default_prefix, x, y),
                            .texture_name = res.texture_name,
                            .texture_bounds = stamp.sprite_dim.?,
                            ._flippedX = stamp.flip_x,
                            ._flippedY = stamp.flip_y,
                        }).id);
                    } else {
                        // use the default stamp
                        res._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                            .name = getMapName(null, default_prefix, x, y),
                            .texture_name = res.texture_name,
                            .texture_bounds = RectF{
                                @as(Float, @floatFromInt(x)) * default_dim[2],
                                @as(Float, @floatFromInt(y)) * default_dim[3],
                                default_dim[2],
                                default_dim[3],
                            },
                            ._flippedX = default_stamp.flip_x,
                            ._flippedY = default_stamp.flip_y,
                        }).id);
                    }
                }
            }
        } else {
            // in this case just load the existing stamps that has defined sprite_dim (others are ignored)
            const default_prefix = if (res.default_stamp.?.name) |p| p else res.name;
            var next = res._stamps.slots.nextSetBit(0);
            while (next) |i| {
                if (res._stamps.get(i)) |stamp| {
                    if (stamp.sprite_dim) |s_dim| {
                        res._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                            .name = getMapName(stamp.name, default_prefix, i, null),
                            .texture_name = res.texture_name,
                            .texture_bounds = s_dim,
                            ._flippedX = stamp.flip_x,
                            ._flippedY = stamp.flip_y,
                        }).id);
                    }
                }
                next = res._stamps.slots.nextSetBit(i + 1);
            }
        }
    }

    fn close(res: *SpriteSet) void {
        for (res._loaded_sprite_template_refs.items) |index|
            SpriteTemplate.disposeById(index);
        res._loaded_sprite_template_refs.clear();
    }

    fn getMapName(name: ?String, prefix: String, x: usize, y: ?usize) String {
        if (name) |n| return n;

        if (y) |_y| {
            return std.fmt.allocPrint(firefly.api.ALLOC, "{s}_{d}_{d}", .{ prefix, x, _y }) catch unreachable;
        } else {
            return std.fmt.allocPrint(firefly.api.ALLOC, "{s}_{d}", .{ prefix, x }) catch unreachable;
        }
    }
};

//////////////////////////////////////////////////////////////
//// Default Sprite Renderer System
//////////////////////////////////////////////////////////////

pub const DefaultSpriteRenderer = struct {
    pub usingnamespace api.SystemTrait(DefaultSpriteRenderer);
    pub var entity_condition: api.EntityTypeCondition = undefined;
    var sprite_refs: graphics.ViewLayerMapping = undefined;

    pub fn systemInit() void {
        sprite_refs = graphics.ViewLayerMapping.new();
        entity_condition = api.EntityTypeCondition{
            .accept_kind = api.EComponentAspectGroup.newKindOf(.{ graphics.ETransform, ESprite }),
        };
    }

    pub fn systemDeinit() void {
        entity_condition = undefined;
        sprite_refs.deinit();
        sprite_refs = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (register)
            sprite_refs.addWithEView(graphics.EView.byId(id), id)
        else
            sprite_refs.removeWithEView(graphics.EView.byId(id), id);
    }

    pub fn renderView(e: graphics.ViewRenderEvent) void {
        if (sprite_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                const es: *ESprite = ESprite.byId(id).?;
                const trans: *graphics.ETransform = graphics.ETransform.byId(id).?;

                const sprite_template: *SpriteTemplate = SpriteTemplate.byId(es.template_id);
                const multi = if (api.EMultiplier.byId(id)) |m| m.positions else null;
                firefly.api.rendering.renderSprite(
                    sprite_template.texture_binding,
                    sprite_template.texture_bounds,
                    trans.position,
                    trans.pivot,
                    trans.scale,
                    trans.rotation,
                    es.tint_color,
                    es.blend_mode,
                    multi,
                );

                i = all.nextSetBit(id + 1);
            }
        }
    }
};
