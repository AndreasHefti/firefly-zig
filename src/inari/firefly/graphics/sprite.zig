const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const graphics = inari.firefly.graphics;

const DynArray = utils.DynArray;
const DynIndexArray = utils.DynIndexArray;
const Asset = api.Asset;
const SpriteData = api.SpriteData;
const RenderData = api.RenderData;
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
const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const RectF = utils.RectF;
const Vec2f = utils.Vector2f;

//////////////////////////////////////////////////////////////
//// sprite init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    // init Asset
    //SpriteSetAsset.init();
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
    // deinit Assets
    //SpriteSetAsset.deinit();
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
    sprite_data: SpriteData,

    pub fn componentTypeInit() !void {
        Asset(Texture).subscribe(notifyAssetEvent);
    }

    pub fn componentTypeDeinit() void {
        Asset(Texture).unsubscribe(notifyAssetEvent);
    }

    // TODO add construct to automatically bind the texture if it is already loaded

    fn notifyAssetEvent(e: ComponentEvent) void {
        var asset: *Asset(Texture) = Asset(Texture).byId(e.c_id);
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
                        if (utils.stringEquals(template.texture_name, an)) {
                            template.sprite_data.texture_binding = b.id;
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
                    template.sprite_data.texture_binding = NO_BINDING;
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
            "SpriteTemplate[ id:{d}, name:{any}, texture_name:{s}, {any} ]",
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
    template_id: Index,
    render_data: ?RenderData = null,
    offset: ?Vec2f = null,

    pub fn destruct(self: *ESprite) void {
        self.template_id = UNDEF_INDEX;
        self.render_data = null;
        self.offset = null;
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
    pub usingnamespace api.AssetTrait(Texture, "SpriteSet");

    _stamps: DynArray(SpriteStamp) = undefined,
    _loaded_sprite_template_refs: DynIndexArray = undefined,

    name: ?String = null,
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

    pub fn doLoad(asset: *Asset(SpriteSet)) void {
        if (@This().getResourceById(asset.resource_id)) |set| {
            if (set.set_dimensions) |dim| {
                // in this case we interpret the texture as a grid-map of sprites and use default stamp
                for (0..dim[1]) |y| { // 0..height
                    for (0..dim[0]) |x| { // 0..width
                        if (set._stamps.get(y * dim[0] + x)) |stamp| {
                            // use the stamp merged with default stamp
                            set._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                                .name = getMapName(stamp.name, set.default_stamp.name, x, y),
                                .texture_name = set.texture_name,
                                .sprite_data = SpriteData{ .texture_bounds = .{
                                    x,
                                    y,
                                    set.default_stamp.sprite_dim[2],
                                    set.default_stamp.sprite_dim[3],
                                } },
                            }));
                        } else {
                            // use the default stamp
                            set._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                                .name = getMapName(null, set.default_stamp.name, x, y),
                                .texture_name = set.texture_name,
                                .sprite_data = SpriteData{ .texture_bounds = .{
                                    x,
                                    y,
                                    set.default_stamp.sprite_dim[2],
                                    set.default_stamp.sprite_dim[3],
                                } },
                            }));
                        }
                    }
                }
            } else {
                // in this case just load the existing stamps that has defined sprite_dim (others are ignored)
                var next = set._stamps.slots.nextSetBit(0);
                while (next) |i| {
                    if (set._stamps.get(i)) |stamp| {
                        if (stamp.sprite_dim) |s_dim| {
                            set._loaded_sprite_template_refs.add(SpriteTemplate.new(.{
                                .name = getMapName(stamp.name, set.default_stamp.name, i, null),
                                .texture_name = set.texture_name,
                                .sprite_data = SpriteData{ .texture_bounds = s_dim },
                            }));
                        }
                    }
                    next = set._stamps.slots.nextSetBit(i + 1);
                }
            }
        }
    }

    fn getMapName(name: ?String, prefix: String, x: usize, y: ?usize) String {
        if (name) |n| return n;

        if (y) |_y| {
            return std.fmt.allocPrint(api.ALLOC, "{s}_{d}_{d}", .{ prefix, x, _y }) catch unreachable;
        } else {
            return std.fmt.allocPrint(api.ALLOC, "{s}_{d}", .{ prefix, x }) catch unreachable;
        }
    }

    fn applyFlip(spriteTemplate: *SpriteTemplate, flip_x: bool, flip_y: bool) void {
        if (flip_x)
            spriteTemplate.sprite_data.flip_x();
        if (flip_y)
            spriteTemplate.sprite_data.flip_y();
    }

    pub fn doUnload(asset: *Asset(SpriteSet)) void {
        if (@This().getResourceById(asset.resource_id)) |set| {
            for (set._loaded_sprite_template_refs.items) |index| {
                SpriteTemplate.disposeById(index);
            }
            set._loaded_sprite_template_refs.clear();
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
        if (!entity_condition.check(e.c_id))
            return;

        var transform = ETransform.byId(e.c_id);
        switch (e.event_type) {
            ActionType.ACTIVATED => sprite_refs.add(transform.view_id, transform.layer_id, e.c_id),
            ActionType.DEACTIVATING => sprite_refs.remove(transform.view_id, transform.layer_id, e.c_id),
            else => {},
        }
    }

    pub fn renderView(e: ViewRenderEvent) void {
        if (sprite_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                var es = ESprite.byId(id);
                if (es.template_id != UNDEF_INDEX) {
                    api.rendering.renderSprite(
                        &SpriteTemplate.byId(es.template_id).sprite_data,
                        &ETransform.byId(id).transform,
                        es.render_data,
                        es.offset,
                    );
                }
                i = all.nextSetBit(id + 1);
            }
        }
    }
};
