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

    api.Component.Subtype.register(api.Asset, SpriteSet, "SpriteSet");
    api.Component.register(Sprite, "Sprite");
    api.Entity.registerComponent(ESprite, "ESprite");
    api.System.register(DefaultSpriteRenderer);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Sprite Components
//////////////////////////////////////////////////////////////

pub const Sprite = struct {
    pub const Component = api.Component.Mixin(Sprite);
    pub const Naming = api.Component.NameMappingMixin(Sprite);
    pub const Activation = api.Component.ActivationMixin(Sprite);

    id: Index = utils.UNDEF_INDEX,
    name: ?String = null,

    texture_name: String,
    texture_bounds: RectF,
    texture_binding: BindingId = utils.UNDEF_INDEX,

    _flippedX: bool = false,
    _flippedY: bool = false,

    pub fn flipX(self: *Sprite) *Sprite {
        self.texture_bounds[2] = -self.texture_bounds[2];
        self._flippedX = !self._flippedX;
        return self;
    }

    pub fn flipY(self: *Sprite) *Sprite {
        self.texture_bounds[3] = -self.texture_bounds[3];
        self._flippedY = !self._flippedY;
        return self;
    }

    pub fn activation(self: *Sprite, active: bool) void {
        if (active) {
            graphics.Texture.Component.activateByName(self.texture_name);
            self.texture_binding = graphics.Texture.Component.byName(self.texture_name).?._binding.?.id;
        } else {
            self.texture_binding = utils.UNDEF_INDEX;
        }
    }

    pub fn format(
        self: Sprite,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Sprite[ id:{d}, name:{?s}, texture_name:{?s}, bounds:{any}, binding:{any}, flip_x:{any}, flip_y:{any} ]",
            self,
        );
    }
};

//////////////////////////////////////////////////////////////
//// ESprite Sprite Entity Component
//////////////////////////////////////////////////////////////

pub const ESprite = struct {
    pub const Component = api.EntityComponentMixin(ESprite);

    id: Index = utils.UNDEF_INDEX,
    sprite_id: Index = utils.UNDEF_INDEX,
    tint_color: ?Color = null,
    blend_mode: ?BlendMode = null,

    pub fn destruct(self: *ESprite) void {
        self.sprite_id = utils.UNDEF_INDEX;
        self.tint_color = null;
        self.blend_mode = null;
    }

    pub fn activation(self: *ESprite, active: bool) void {
        if (active) {
            // check if sprite_id is valid
            if (self.sprite_id == UNDEF_INDEX) {
                api.Logger.err("ESprite: No sprite_id is set for sprite", .{});
                return;
            }

            Sprite.Activation.activate(self.sprite_id);
        }
    }

    pub const Property = struct {
        pub fn FrameId(id: Index) *Index {
            return &ESprite.Component.byId(id).sprite_id;
        }
        pub fn TintColor(id: Index) *Color {
            var sprite = ESprite.Component.byId(id);
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
    pub const Component = api.Component.SubTypeMixin(api.Asset, SpriteSet);

    _stamps: utils.DynArray(SpriteStamp) = undefined,
    _loaded_sprite_template_refs: utils.DynIndexArray = undefined,

    id: Index = UNDEF_INDEX,
    name: String,
    texture_name: String,
    default_stamp: ?SpriteStamp = null,
    set_dimensions: ?Vector2f = null,

    pub fn construct(self: *SpriteSet) void {
        self._stamps = utils.DynArray(SpriteStamp).new(firefly.api.COMPONENT_ALLOC);
        self._loaded_sprite_template_refs = utils.DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 32);
    }

    pub fn destruct(self: *SpriteSet) void {
        self._stamps.deinit();
        self._stamps = undefined;
        self._loaded_sprite_template_refs.deinit();
        self._loaded_sprite_template_refs = undefined;
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
                        res._loaded_sprite_template_refs.add(Sprite.Component.new(.{
                            .name = getMapName(stamp.name, default_prefix, x, y),
                            .texture_name = res.texture_name,
                            .texture_bounds = stamp.sprite_dim.?,
                            ._flippedX = stamp.flip_x,
                            ._flippedY = stamp.flip_y,
                        }));
                    } else {
                        // use the default stamp
                        res._loaded_sprite_template_refs.add(Sprite.Component.new(.{
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
                        }));
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
                        res._loaded_sprite_template_refs.add(Sprite.Component.new(.{
                            .name = getMapName(stamp.name, default_prefix, i, null),
                            .texture_name = res.texture_name,
                            .texture_bounds = s_dim,
                            ._flippedX = stamp.flip_x,
                            ._flippedY = stamp.flip_y,
                        }));
                    }
                }
                next = res._stamps.slots.nextSetBit(i + 1);
            }
        }
    }

    fn close(res: *SpriteSet) void {
        for (res._loaded_sprite_template_refs.items) |index|
            Sprite.Component.dispose(index);
        res._loaded_sprite_template_refs.clear();
    }

    fn getMapName(name: ?String, prefix: String, x: usize, y: ?usize) String {
        if (name) |n| return n;

        return if (y) |_y|
            return api.format("{s}_{d}_{d}", .{ prefix, x, _y })
        else
            return api.format("{s}_{d}", .{ prefix, x });
    }
};

//////////////////////////////////////////////////////////////
//// Default Sprite Renderer System
//////////////////////////////////////////////////////////////

pub const DefaultSpriteRenderer = struct {
    pub const System = api.SystemMixin(DefaultSpriteRenderer);
    pub const EntityRenderer = graphics.EntityRendererMixin(DefaultSpriteRenderer);

    pub const accept = .{ graphics.ETransform, ESprite };

    pub fn renderEntities(entities: *firefly.utils.BitSet, _: graphics.ViewRenderEvent) void {
        var i = entities.nextSetBit(0);
        while (i) |id| {
            // render the sprite
            const es = ESprite.Component.byId(id);
            const trans = graphics.ETransform.Component.byId(id);

            const sprite_template = Sprite.Component.byId(es.sprite_id);
            const multi = if (api.EMultiplier.Component.byIdOptional(id)) |m| m.positions else null;
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

            i = entities.nextSetBit(id + 1);
        }
    }
};
