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
const Float = firefly.utils.Float;
const RectF = firefly.utils.RectF;
const ClipI = firefly.utils.ClipI;
const CInt = firefly.utils.CInt;
const PosF = firefly.utils.PosF;
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
    texture_pos: PosF,
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
    tile_width: Float,
    tile_height: Float,
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

    pub fn addTileTemplate(self: *TileSet, template: TileTemplate) void {
        _ = self.tile_templates.add(template);
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
                    .texture_bounds = .{
                        tt.sprite_data.texture_pos[0],
                        tt.sprite_data.texture_pos[1],
                        self.tile_width,
                        self.tile_height,
                    },
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
                                .texture_bounds = .{
                                    frame.sprite_data.texture_pos[0],
                                    frame.sprite_data.texture_pos[1],
                                    self.tile_width,
                                    self.tile_height,
                                },
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
    tile_set_name: String,
    code_offset: Index,
};

pub const TileLayerData = struct {
    layer: String,
    tint: ?Color = null,
    blend: ?BlendMode = null,
    parallax: ?Vector2f = null,
    offset: ?Vector2f = null,
    tile_set_mappings: DynArray(TileSetMapping) = undefined,

    pub fn withTileSetMapping(self: *TileLayerData, mapping: TileSetMapping) *TileLayerData {
        _ = self.tile_set_mappings.add(mapping);
        return self;
    }
};

pub const TileGridData = struct {
    name: String,
    layer: String,
    world_position: PosF,
    spherical: bool = false,
    dimensions: @Vector(4, usize),
    codes: String,
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

    tile_layer_data: DynArray(TileLayerData) = undefined,
    tile_grid_data: DynArray(TileGridData) = undefined,
    layer_entity_mapping: DynArray(DynIndexArray) = undefined,

    pub fn construct(self: *TileMapping) void {
        self.tile_layer_data = DynArray(TileLayerData).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
        self.tile_grid_data = DynArray(TileGridData).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
        self.layer_entity_mapping = DynArray(DynIndexArray).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
    }

    pub fn destruct(self: *TileMapping) void {
        var next = self.tile_layer_data.slots.nextSetBit(0);
        while (next) |i| {
            self.tile_layer_data.get(i).?.tile_set_mappings.deinit();
            next = self.tile_layer_data.slots.nextSetBit(i + 1);
        }
        self.tile_layer_data.deinit();
        self.tile_layer_data = undefined;
        self.tile_grid_data.deinit();
        self.tile_grid_data = undefined;
        self.layer_entity_mapping.deinit();
        self.layer_entity_mapping = undefined;
    }

    pub fn addTileSetMapping(self: *TileMapping, layer: String, mapping: TileSetMapping) void {
        var next = self.tile_layer_data.slots.nextSetBit(0);
        while (next) |i| {
            var layer_mapping = self.tile_layer_data.get(i).?;
            if (firefly.utils.stringEquals(layer_mapping.layer, layer)) {
                _ = layer_mapping.withTileSetMapping(mapping);
                return;
            }
            next = self.tile_layer_data.slots.nextSetBit(i + 1);
        }
    }

    pub fn withTileLayerData(self: *TileMapping, layer: String) *TileLayerData {
        var tile_layer_data = self.tile_layer_data.addAndGet(.{
            .layer = layer,
        }).ref;
        tile_layer_data.tile_set_mappings = DynArray(TileSetMapping).newWithRegisterSize(
            firefly.api.COMPONENT_ALLOC,
            10,
        );
        return tile_layer_data;
    }

    pub fn addTileGridData(self: *TileMapping, grid_data: TileGridData) void {
        _ = self.tile_grid_data.add(grid_data);
    }

    pub fn activation(self: *TileMapping, active: bool) void {
        if (active) {
            self._activate();
        } else {
            self._deactivate();
        }
    }

    pub fn getEntityId(self: *TileMapping, layer_id: Index, code: Index) Index {
        return self.layer_entity_mapping.get(layer_id).?.get(code);
    }

    fn _activate(self: *TileMapping) void {
        // create entities vor all tiles of layer based tile sets
        // for all TileLayerData ...
        var next = self.tile_layer_data.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_layer_data.get(i)) |layer_mapping| {
                // get involved layer
                if (firefly.graphics.Layer.byName(layer_mapping.layer)) |layer| {
                    // add new code -> entity mapping for layer if not existing
                    if (!self.layer_entity_mapping.exists(layer.id))
                        _ = self.layer_entity_mapping.set(
                            DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 50),
                            layer.id,
                        );
                    var entity_mapping: *DynIndexArray = self.layer_entity_mapping.get(layer.id).?;

                    // set layer offset if available
                    layer.offset = layer_mapping.offset;

                    // get involved TileSets
                    var next_ts = layer_mapping.tile_set_mappings.slots.nextSetBit(0);
                    while (next_ts) |ii| {
                        const tile_set_mapping: *TileSetMapping = layer_mapping.tile_set_mappings.get(ii).?;
                        var code = tile_set_mapping.code_offset;
                        if (TileSet.byName(tile_set_mapping.tile_set_name)) |tile_set| {
                            _ = tile_set.activate();

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
                                        .withComponent(EView{ .view_id = self.view_id, .layer_id = layer.id })
                                        .withComponent(ETile{
                                        .sprite_template_id = tile_template._sprite_template_id.?,
                                        .tint_color = layer_mapping.tint,
                                        .blend_mode = layer_mapping.blend,
                                    }).entity();

                                    // add contact if needed
                                    addContactData(entity, tile_set, tile_template);
                                    // add animation if needed
                                    addAnimationData(entity, tile_template);
                                    // set code -> entity id mapping for layer
                                    entity_mapping.set(code, entity.id);
                                    _ = entity.activate();
                                }
                                next_ti = tile_set.tile_templates.slots.nextSetBit(ti + 1);
                                code += 1;
                            }
                        }

                        next_ts = layer_mapping.tile_set_mappings.slots.nextSetBit(ii + 1);
                    }
                }
            }
            next = self.tile_layer_data.slots.nextSetBit(i + 1);
        }

        // create TileGrids
        next = self.tile_grid_data.slots.nextSetBit(0);
        while (next) |i| {
            const tile_grid_data = self.tile_grid_data.get(i).?;
            if (firefly.graphics.Layer.idByName(tile_grid_data.layer)) |layer_id| {
                var tile_grid = firefly.graphics.TileGrid.new(.{
                    .name = tile_grid_data.name,
                    .view_id = self.view_id,
                    .layer_id = layer_id,
                    .dimensions = tile_grid_data.dimensions,
                    .world_position = tile_grid_data.world_position,
                    .spherical = tile_grid_data.spherical,
                });

                // fill grid
                const code_mapping = self.layer_entity_mapping.get(layer_id).?;
                var code_it = std.mem.split(u8, tile_grid_data.codes, ",");
                for (0..tile_grid.dimensions[1]) |y| {
                    for (0..tile_grid.dimensions[0]) |x| {
                        const code = std.fmt.parseInt(Index, code_it.next().?, 10) catch unreachable;
                        const entity_id = code_mapping.get(code);
                        tile_grid.set(x, y, entity_id);
                    }
                }

                _ = tile_grid.activate();
            }
            next = self.tile_grid_data.slots.nextSetBit(i + 1);
        }
    }

    fn addContactData(entity: *Entity, tile_set: *TileSet, tile_template: *TileTemplate) void {
        if (tile_template.hasContact()) {
            _ = entity.withComponent(EContact{
                .bounds = .{
                    .rect = .{
                        0,
                        0,
                        tile_set.tile_width,
                        tile_set.tile_height,
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
        var next = self.layer_entity_mapping.slots.nextSetBit(0);
        while (next) |i| {
            if (self.layer_entity_mapping.get(i)) |layer_mapping| {
                for (0..layer_mapping.size_pointer) |ii|
                    Entity.disposeById(layer_mapping.items[ii]);
                layer_mapping.clear();
            }
            next = self.layer_entity_mapping.slots.nextSetBit(i + 1);
        }
        self.layer_entity_mapping.clear();
    }
};
