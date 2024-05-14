const std = @import("std");
const firefly = @import("../firefly.zig");

const AssetTrait = firefly.api.AssetTrait;
const DynArray = firefly.utils.DynArray;
const DynIndexArray = firefly.utils.DynIndexArray;
const Asset = firefly.api.Asset;
const String = firefly.utils.String;
const Component = firefly.api.Component;
const ComponentEvent = firefly.api.Component.ComponentEvent;
const ActionType = firefly.api.Component.ActionType;
const Texture = firefly.graphics.Texture;
const EComponent = firefly.api.EComponent;
const EComponentAspectGroup = firefly.api.EComponentAspectGroup;
const EntityCondition = firefly.api.EntityCondition;
const EView = firefly.graphics.EView;
const EMultiplier = firefly.api.EMultiplier;
const ETransform = firefly.graphics.ETransform;
const ViewLayerMapping = firefly.graphics.ViewLayerMapping;
const ViewRenderEvent = firefly.graphics.ViewRenderEvent;
const System = firefly.api.System;
const BindingId = firefly.api.BindingId;
const Index = firefly.utils.Index;
const Float = firefly.utils.Float;
const RectF = firefly.utils.RectF;
const PosF = firefly.utils.PosF;
const Vector2f = firefly.utils.Vector2f;
const Color = firefly.utils.Color;
const BlendMode = firefly.api.BlendMode;

const NO_NAME = firefly.utils.NO_NAME;
const NO_BINDING = firefly.api.NO_BINDING;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

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
    System(DefaultSpriteRenderer).createSystem(
        firefly.Engine.DefaultRenderer.SPRITE,
        "Render Entities with ETransform and ESprite components",
        true,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit renderer
    System(DefaultSpriteRenderer).disposeSystem();
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
            if (tex._binding) |b| {
                self.texture_binding = b.id;
            }
        }
    }

    fn notifyAssetEvent(e: ComponentEvent) void {
        const asset: *Asset(Texture) = Asset(Texture).byId(e.c_id.?);
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
            if (r._binding) |b| {
                var next = SpriteTemplate.nextId(0);
                while (next) |id| {
                    var template = SpriteTemplate.byId(id);
                    if (asset.name) |an| {
                        if (firefly.utils.stringEquals(template.texture_name, an)) {
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
                if (firefly.utils.stringEquals(template.texture_name, an)) {
                    template.texture_binding = NO_BINDING;
                }
            }
            next = SpriteTemplate.nextId(id + 1);
        }
    }

    fn onTextureDispose(asset: *Asset(Texture)) void {
        var next = SpriteTemplate.nextId(0);
        while (next) |id| {
            const template = SpriteTemplate.byId(id);
            if (asset.name) |an| {
                if (firefly.utils.stringEquals(template.texture_name, an)) {
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

            const template = SpriteTemplate.byId(self.template_id);
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

    pub const Property = struct {
        pub fn FrameId(id: Index) *Index {
            return &ESprite.byId(id).?.id;
        }
        pub fn TintColor(id: Index) *Color {
            var sprite = ESprite.byId(id).?;
            if (sprite.tint_color == null) {
                sprite.tint_color = Color{};
            }
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
    pub usingnamespace AssetTrait(SpriteSet, "SpriteSet");

    _stamps: DynArray(SpriteStamp) = undefined,
    _loaded_sprite_template_refs: DynIndexArray = undefined,

    name: String,
    texture_name: String,
    default_stamp: ?SpriteStamp = null,
    set_dimensions: ?Vector2f = null,

    pub fn construct(self: SpriteSet) void {
        self._stamps = DynArray(SpriteStamp).new(firefly.api.COMPONENT_ALLOC);
        self._sprite_template_refs = DynIndexArray.init(firefly.api.COMPONENT_ALLOC, 32);
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

            const default_stamp = resource.default_stamp.?;
            if (default_stamp.sprite_dim == null)
                @panic("SpriteSet needs default_stamp with sprite_dim");

            const width: usize = @intFromFloat(dim[0]);
            const height: usize = @intFromFloat(dim[1]);
            const default_dim = default_stamp.sprite_dim.?;
            const default_prefix = if (default_stamp.name) |p| p else resource.name;

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
            const default_prefix = if (resource.default_stamp.?.name) |p| p else resource.name;
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
            return std.fmt.allocPrint(firefly.api.ALLOC, "{s}_{d}_{d}", .{ prefix, x, _y }) catch unreachable;
        } else {
            return std.fmt.allocPrint(firefly.api.ALLOC, "{s}_{d}", .{ prefix, x }) catch unreachable;
        }
    }
};

//////////////////////////////////////////////////////////////
//// Default Sprite Renderer System
//////////////////////////////////////////////////////////////

const DefaultSpriteRenderer = struct {
    pub var entity_condition: EntityCondition = undefined;
    var sprite_refs: ViewLayerMapping = undefined;

    pub fn systemInit() void {
        sprite_refs = ViewLayerMapping.new();
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{ ETransform, ESprite }),
        };
    }

    pub fn systemDeinit() void {
        entity_condition = undefined;
        sprite_refs.deinit();
        sprite_refs = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (register)
            sprite_refs.addWithEView(EView.byId(id), id)
        else
            sprite_refs.removeWithEView(EView.byId(id), id);
    }

    pub fn renderView(e: ViewRenderEvent) void {
        if (sprite_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                const es = ESprite.byId(id).?;
                const trans = ETransform.byId(id).?;
                if (es.template_id != NO_BINDING) {
                    const multi = if (EMultiplier.byId(id)) |m| m.positions else null;
                    firefly.api.rendering.renderSprite(
                        es._texture_binding,
                        es._texture_bounds,
                        trans.position,
                        trans.pivot,
                        trans.scale,
                        trans.rotation,
                        es.tint_color,
                        es.blend_mode,
                        multi,
                    );
                }
                i = all.nextSetBit(id + 1);
            }
        }
    }
};
