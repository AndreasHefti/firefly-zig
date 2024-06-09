const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;

const Composite = firefly.api.Composite;
const NamePool = firefly.api.NamePool;
const Attributes = firefly.api.Attributes;
const Component = firefly.api.Component;
const GroupKind = firefly.api.GroupKind;
const GroupAspectGroup = firefly.api.GroupAspectGroup;
const ContactMaterialAspect = firefly.physics.ContactMaterialAspect;
const ContactMaterialAspectGroup = firefly.physics.ContactMaterialAspectGroup;
const TileTypeKind = firefly.graphics.TileTypeKind;
const BitMask = firefly.utils.BitMask;
const IndexFrameList = firefly.physics.IndexFrameList;
const ContactTypeAspect = firefly.physics.ContactTypeAspect;
const Asset = firefly.api.Asset;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ETile = firefly.graphics.ETile;
const EView = firefly.graphics.EView;
const EAnimation = firefly.physics.EAnimation;
const EContact = firefly.physics.EContact;
const IndexFrameIntegration = firefly.physics.IndexFrameIntegration;
const ImageBinding = firefly.api.ImageBinding;

const StringHashMap = std.StringHashMap;
const DynIndexArray = firefly.utils.DynIndexArray;
const DynArray = firefly.utils.DynArray;
const BlendMode = firefly.api.BlendMode;
const Color = firefly.utils.Color;
const String = firefly.utils.String;
const Index = firefly.utils.Index;
const RectF = firefly.utils.RectF;
const ClipI = firefly.utils.ClipI;
const CInt = firefly.utils.CInt;
const Vector2f = firefly.utils.Vector2f;
const BindingId = firefly.api.BindingId;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// game tile init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    TileContactMaterialType.NONE = ContactMaterialAspectGroup.getAspect("NONE");
    TileContactMaterialType.TERRAIN = ContactMaterialAspectGroup.getAspect("TERRAIN");
    TileContactMaterialType.PROJECTILE = ContactMaterialAspectGroup.getAspect("PROJECTILE");
    TileContactMaterialType.WATER = ContactMaterialAspectGroup.getAspect("WATER");
    TileContactMaterialType.LADDER = ContactMaterialAspectGroup.getAspect("LADDER");
    TileContactMaterialType.ROPE = ContactMaterialAspectGroup.getAspect("ROPE");
    TileContactMaterialType.INTERACTIVE = ContactMaterialAspectGroup.getAspect("INTERACTIVE");

    Component.registerComponent(TileSet);
    Component.registerComponent(TileMapping);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// game tile API
//////////////////////////////////////////////////////////////

pub const TileDimensionType = enum {
    EIGHT,
    SIXTEEN,
    THIRTY_TWO,
};

pub const TileContactMaterialType = struct {
    pub var NONE: ContactMaterialAspect = undefined;
    pub var TERRAIN: ContactMaterialAspect = undefined;
    pub var PROJECTILE: ContactMaterialAspect = undefined;
    pub var WATER: ContactMaterialAspect = undefined;
    pub var LADDER: ContactMaterialAspect = undefined;
    pub var ROPE: ContactMaterialAspect = undefined;
    pub var INTERACTIVE: ContactMaterialAspect = undefined;
};

//////////////////////////////////////////////////////////////
//// TileSet
//////////////////////////////////////////////////////////////

pub const SpriteData = struct {
    texture_bounds: RectF,
    flip_x: bool = false,
    flip_y: bool = false,
};

pub const TileAnimationFrame = struct {
    sprite_data: SpriteData,
    duration: usize = 0,
    _sprite_template_id: ?Index = null,
};

pub const TileTemplate = struct {
    name: ?String = null,
    groups: ?String = null,

    sprite_data: SpriteData,
    animation: ?DynArray(TileAnimationFrame) = null,

    contact_material_type: ?ContactMaterialAspect = null,
    contact_mask_name: ?String = null,

    _sprite_template_id: ?Index = null,

    pub fn hasContact(self: *TileTemplate) bool {
        return self.contact_material_type != null and self.contact_mask_name != null;
    }

    pub fn withAnimationFrame(self: TileTemplate, frame: TileAnimationFrame) TileTemplate {
        var _self = self;
        if (_self.animation == null)
            _self.animation = DynArray(TileAnimationFrame).new(firefly.api.COMPONENT_ALLOC);

        if (_self.animation) |*a|
            _ = a.add(frame);

        return _self;
    }

    pub fn deinit(self: *TileTemplate) void {
        if (self.animation) |*a|
            a.deinit();
    }
};

pub const TileSet = struct {
    pub usingnamespace Component.Trait(
        @This(),
        .{
            .name = "TileSet",
            .subscription = false,
        },
    );

    var contact_mask_cache: StringHashMap(BitMask) = undefined;

    id: Index = UNDEF_INDEX,
    name: ?String = null,
    texture_name: String,
    tile_templates: DynArray(TileTemplate) = undefined,

    pub fn componentTypeInit() !void {
        contact_mask_cache = StringHashMap(BitMask).init(firefly.api.ALLOC);
        return;
    }

    pub fn componentTypeDeinit() void {
        var i = contact_mask_cache.valueIterator();
        while (i.next()) |bit_mask|
            bit_mask.deinit();
        contact_mask_cache.deinit();
    }

    pub fn construct(self: *TileSet) void {
        self.tile_templates = DynArray(TileTemplate).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 50);
    }

    pub fn destruct(self: *TileSet) void {
        var next = self.tile_templates.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_templates.get(i)) |tt| tt.deinit();
            next = self.tile_templates.slots.nextSetBit(i + 1);
        }

        self.tile_templates.deinit();
        self.tile_templates = undefined;
    }

    pub fn withTileTemplate(self: *TileSet, template: TileTemplate) *TileSet {
        _ = self.tile_templates.add(template);
        return self;
    }

    pub fn activation(self: *TileSet, active: bool) void {
        if (active) {
            self._activate();
        } else {
            self._deactivate();
        }
    }

    pub fn createContactMaskFromImage(self: *TileSet, tile_template: *TileTemplate) ?BitMask {
        if (tile_template.contact_mask_name == null)
            return null;

        if (contact_mask_cache.get(tile_template.contact_mask_name.?)) |cm|
            return cm;

        // create contact mask from image data and cache it
        // make sure involved texture is loaded into GPU
        Texture.loadByName(self.texture_name);
        if (Texture.resourceByName(self.texture_name)) |tex| {
            // load image of texture to CPU
            const st = SpriteTemplate.byId(tile_template._sprite_template_id.?);
            var image: ImageBinding = firefly.api.rendering.loadImageRegionFromTexture(
                tex._binding.?.id,
                st.texture_bounds,
            );
            defer firefly.api.rendering.disposeImage(image.id);

            const width: usize = firefly.utils.f32_usize(@abs(st.texture_bounds[2]));
            const height: usize = firefly.utils.f32_usize(@abs(st.texture_bounds[3]));
            var result: BitMask = BitMask.new(
                firefly.api.ALLOC,
                width,
                height,
            );
            for (0..height) |y| {
                for (0..width) |x| {
                    if (firefly.utils.hasColor(image.get_color_at(
                        image.id,
                        firefly.utils.usize_cint(x),
                        firefly.utils.usize_cint(y),
                    )))
                        result.setBitAt(x, y);
                }
            }
            contact_mask_cache.put(tile_template.contact_mask_name.?, result) catch unreachable;
        } else {
            std.debug.print("Missing texture with name: {s}", .{self.texture_name});
            @panic("Missing texture with name");
        }

        return contact_mask_cache.get(tile_template.contact_mask_name.?);
    }

    fn _activate(self: *TileSet) void {
        // create sprite templates out of the tile templates
        var next = self.tile_templates.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_templates.get(i)) |tt| {
                var st: *SpriteTemplate = SpriteTemplate.new(.{
                    .name = tt.name,
                    .texture_name = self.texture_name,
                    .texture_bounds = tt.sprite_data.texture_bounds,
                });
                if (tt.sprite_data.flip_x)
                    _ = st.flipX();
                if (tt.sprite_data.flip_y)
                    _ = st.flipY();
                tt._sprite_template_id = st.id;

                // animation if defined...
                if (tt.animation) |*animations| {
                    var next_a = animations.slots.nextSetBit(0);
                    while (next_a) |ii| {
                        if (animations.get(ii)) |frame| {
                            var ast: *SpriteTemplate = SpriteTemplate.new(.{
                                .texture_name = self.texture_name,
                                .texture_bounds = frame.sprite_data.texture_bounds,
                            });
                            if (frame.sprite_data.flip_x)
                                _ = ast.flipX();
                            if (frame.sprite_data.flip_y)
                                _ = ast.flipY();
                            frame._sprite_template_id = ast.id;
                        }
                        next_a = animations.slots.nextSetBit(ii + 1);
                    }
                }
            }
            next = self.tile_templates.slots.nextSetBit(i + 1);
        }

        // load texture asset for sprites
        Texture.loadByName(self.texture_name);
    }

    fn _deactivate(self: *TileSet) void {
        // delete all sprite templates of the tile map
        var next = self.tile_templates.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_templates.get(i)) |tt| {
                SpriteTemplate.disposeById(tt._sprite_template_id.?);
                tt._sprite_template_id = null;
                // cleanup animation if defined
                if (tt.animation) |*animations| {
                    var next_a = animations.slots.nextSetBit(0);
                    while (next_a) |ii| {
                        if (animations.get(ii)) |frame| {
                            SpriteTemplate.disposeById(frame._sprite_template_id.?);
                            frame._sprite_template_id = null;
                        }
                        next_a = animations.slots.nextSetBit(ii + 1);
                    }
                }
            }
            next = self.tile_templates.slots.nextSetBit(i + 1);
        }
    }
};

//////////////////////////////////////////////////////////////
//// TileMapping
//////////////////////////////////////////////////////////////

pub const TileSetMapping = struct {
    tile_set_id: Index,
    name: String,
    _map_code_offset: Index = UNDEF_INDEX,
    _tile_set_size: Index = UNDEF_INDEX,
};

pub const TileSetLayerMapping = struct {
    mapped_tile_set_name: String,
    layer_name: ?String,
    tint_color: ?Color = null,
    blend_mode: ?BlendMode = null,
    _mapped_tile_set_id: Index = UNDEF_INDEX,
};

pub const TileMapping = struct {
    pub usingnamespace Component.Trait(
        @This(),
        .{
            .name = "TileMapping",
            .subscription = false,
        },
    );

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    view_id: Index = UNDEF_INDEX,

    tile_sets: DynArray(TileSetMapping) = undefined,
    tile_sets_per_layer: DynArray(TileSetLayerMapping) = undefined,
    _layer_entity_mapping: DynArray(DynIndexArray) = undefined,

    pub fn construct(self: *TileMapping) void {
        self.tile_sets = DynArray(TileSetMapping).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
        self.tile_sets_per_layer = DynArray(TileSetLayerMapping).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
        self._layer_entity_mapping = DynArray(DynIndexArray).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
    }

    pub fn destruct(self: *TileMapping) void {
        self.tile_sets.deinit();
        self.tile_sets = undefined;
        self.tile_sets_per_layer.deinit();
        self.tile_sets_per_layer = undefined;
        self._layer_entity_mapping.deinit();
        self._layer_entity_mapping = undefined;
    }

    pub fn withTileSetMapping(self: *TileMapping, mapping: TileSetMapping) *TileMapping {
        var _mapping: TileSetMapping = mapping;
        var ts: *TileSet = TileSet.byId(mapping.tile_set_id);
        const size = self.tile_sets.nextFreeSlot();
        if (size > 0) {
            if (self.tile_sets.get(size - 1)) |last| {
                _mapping._map_code_offset = last._map_code_offset + last._tile_set_size;
            }
        } else {
            _mapping._map_code_offset = 1;
        }
        _mapping._tile_set_size = ts.tile_templates.size();
        _ = self.tile_sets.add(_mapping);
        return self;
    }

    pub fn withTileSetMappingByName(self: *TileMapping, tile_set_name: String) *TileMapping {
        if (TileSet.byName(tile_set_name)) |ts| {
            return self.withTileSetMapping(TileSetMapping{
                .name = tile_set_name,
                .tile_set_id = ts.id,
            });
        }
        return self;
    }

    pub fn withTileSetLayerMapping(self: *TileMapping, mapping: TileSetLayerMapping) *TileMapping {
        var _mapping = mapping;
        var next = self.tile_sets.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_sets.get(i)) |ts| {
                if (std.mem.eql(u8, ts.name, mapping.mapped_tile_set_name))
                    _mapping._mapped_tile_set_id = ts.tile_set_id;
            }
            next = self.tile_sets.slots.nextSetBit(i + 1);
        }
        _ = self.tile_sets_per_layer.add(_mapping);
        return self;
    }

    pub fn activation(self: *TileMapping, active: bool) void {
        if (active) {
            self._activate();
        } else {
            self._deactivate();
        }
    }

    pub fn getEntityId(self: *TileMapping, layer_id: Index, code: Index) Index {
        return self._layer_entity_mapping.get(layer_id).?.get(code);
    }

    fn _activate(self: *TileMapping) void {
        // activate all involved tile sets
        var next = self.tile_sets.slots.nextSetBit(0);
        while (next) |i| {
            TileSet.activateById(i, true);
            next = self.tile_sets.slots.nextSetBit(i + 1);
        }

        // create entities vor all tiles in all tile sets per layer and fill up the entity mapping
        // for all TileSetLayerMappings ...
        next = self.tile_sets_per_layer.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_sets_per_layer.get(i)) |tile_set_layer_mapping| {

                // get involved layer
                var layer_id: Index = 0;
                if (tile_set_layer_mapping.layer_name) |ln|
                    layer_id = firefly.graphics.Layer.idByName(ln).?;

                // get involved TileSet
                if (TileSet.byName(tile_set_layer_mapping.mapped_tile_set_name)) |tile_set| {
                    // get involved TileSetMapping
                    const mapped_tile_set: *TileSetMapping = self.tile_sets.get(tile_set_layer_mapping._mapped_tile_set_id).?;

                    // add new code -> entity mapping for layer if not existing
                    if (!self._layer_entity_mapping.exists(layer_id))
                        _ = self._layer_entity_mapping.set(
                            DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 50),
                            layer_id,
                        );

                    // get code -> entity mapping for layer
                    if (self._layer_entity_mapping.get(layer_id)) |e_mapping| {
                        // set code to mapping offset of TileSetMapping
                        var code = mapped_tile_set._map_code_offset;

                        // for all TileTemplates in TileSet
                        var next_ti = tile_set.tile_templates.slots.nextSetBit(0);
                        while (next_ti) |ti| {
                            if (tile_set.tile_templates.get(ti)) |tile_template| {

                                // create entity from TileTemplate for specific view and layer and add code mapping
                                const entity = Entity.new(.{
                                    .name = tile_template.name,
                                    .groups = GroupKind.fromStringList(tile_template.groups),
                                })
                                    .withComponent(ETransform{})
                                    .withComponent(EView{ .view_id = self.view_id, .layer_id = layer_id })
                                    .withComponent(ETile{
                                    .sprite_template_id = tile_template._sprite_template_id.?,
                                    .tint_color = tile_set_layer_mapping.tint_color,
                                    .blend_mode = tile_set_layer_mapping.blend_mode,
                                }).entity();

                                // add contact if needed
                                addContactData(entity, tile_set, tile_template);
                                // add animation if needed
                                addAnimationData(entity, tile_template);
                                // set code -> entity id mapping for layer
                                e_mapping.set(code, entity.id);
                                _ = entity.activate();
                            }
                            next_ti = tile_set.tile_templates.slots.nextSetBit(ti + 1);
                            code += 1;
                        }
                    }
                }
            }
            next = self.tile_sets_per_layer.slots.nextSetBit(i + 1);
        }
    }

    fn addContactData(entity: *Entity, tile_set: *TileSet, tile_template: *TileTemplate) void {
        if (tile_template.hasContact()) {
            _ = entity.withComponent(EContact{
                .bounds = .{
                    .rect = .{
                        0,
                        0,
                        tile_template.sprite_data.texture_bounds[2],
                        tile_template.sprite_data.texture_bounds[3],
                    },
                },
                .c_material = tile_template.contact_material_type,
                .mask = tile_set.createContactMaskFromImage(tile_template),
            });
        }
    }

    fn addAnimationData(entity: *Entity, tile_template: *TileTemplate) void {
        if (tile_template.animation) |*frames| {
            var list = IndexFrameList.new();
            var next = frames.slots.nextSetBit(0);
            while (next) |i| {
                if (frames.get(i)) |frame|
                    _ = list.withFrame(frame._sprite_template_id.?, frame.duration);
                next = frames.slots.nextSetBit(i + 1);
            }

            _ = entity.withComponent(EAnimation{})
                .withAnimation(
                .{ .duration = list._duration, .looping = true, .active_on_init = true },
                IndexFrameIntegration{
                    .timeline = list,
                    .property_ref = ETile.Property.FrameId,
                },
            );
        }
    }

    fn _deactivate(self: *TileMapping) void {
        // dispose all entities and clear the mapping
        var next = self._layer_entity_mapping.slots.nextSetBit(0);
        while (next) |i| {
            if (self._layer_entity_mapping.get(i)) |layer_mapping| {
                for (0..layer_mapping.size_pointer) |ii|
                    Entity.disposeById(layer_mapping.items[ii]);
                layer_mapping.clear();
            }
            next = self._layer_entity_mapping.slots.nextSetBit(i + 1);
        }
        self._layer_entity_mapping.clear();
    }
};
