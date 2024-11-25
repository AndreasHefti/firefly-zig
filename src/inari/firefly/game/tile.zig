const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const physics = firefly.physics;
const graphics = firefly.graphics;

const Color = utils.Color;
const String = utils.String;
const Index = utils.Index;
const Float = utils.Float;
const RectF = utils.RectF;
const ClipI = utils.ClipI;
const CInt = utils.CInt;
const PosF = utils.PosF;
const Vector2f = utils.Vector2f;
const BindingId = api.BindingId;
const UNDEF_INDEX = utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// game tile init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.Component.register(TileSet, "TileSet");
    api.Component.register(TileMapping, "TileMapping");
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
    animation: ?utils.DynArray(TileAnimationFrame) = null,

    contact_material_type: ?physics.ContactMaterialAspect = null,
    contact_mask_name: ?String = null,

    _sprite_template_id: ?Index = null,

    pub fn withAnimationFrame(self: TileTemplate, frame: TileAnimationFrame) TileTemplate {
        var _self = self;
        if (_self.animation == null)
            _self.animation = utils.DynArray(TileAnimationFrame).new(firefly.api.COMPONENT_ALLOC);

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
    pub const Component = api.Component.Mixin(TileSet);
    pub const Naming = api.Component.NameMappingMixin(TileSet);
    pub const Activation = api.Component.ActivationMixin(TileSet);

    var contact_mask_cache: std.StringHashMap(utils.BitMask) = undefined;

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    texture_name: String,
    tile_width: Float,
    tile_height: Float,
    tile_templates: utils.DynArray(TileTemplate) = undefined,

    pub fn componentTypeInit() !void {
        contact_mask_cache = std.StringHashMap(utils.BitMask).init(firefly.api.ALLOC);
        return;
    }

    pub fn componentTypeDeinit() void {
        var i = contact_mask_cache.valueIterator();
        while (i.next()) |bit_mask|
            bit_mask.deinit();
        contact_mask_cache.deinit();
    }

    pub fn construct(self: *TileSet) void {
        self.tile_templates = utils.DynArray(TileTemplate).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 50);
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

    pub fn createContactMaskFromImage(self: *TileSet, tile_template: *TileTemplate) ?utils.BitMask {
        if (tile_template.contact_mask_name == null)
            return null;

        if (contact_mask_cache.get(tile_template.contact_mask_name.?)) |cm|
            return cm;

        // create contact mask from image data and cache it
        // make sure involved texture is loaded into GPU

        graphics.Texture.Component.activateByName(self.texture_name);
        if (graphics.Texture.Component.byName(self.texture_name)) |tex| {
            // load image of texture to CPU
            const st = graphics.SpriteTemplate.Component.byId(tile_template._sprite_template_id.?);
            var image: api.ImageBinding = firefly.api.rendering.loadImageRegionFromTexture(
                tex._binding.?.id,
                st.texture_bounds,
            );
            defer firefly.api.rendering.disposeImage(image.id);

            const width: usize = firefly.utils.f32_usize(@abs(st.texture_bounds[2]));
            const height: usize = firefly.utils.f32_usize(@abs(st.texture_bounds[3]));
            var result: utils.BitMask = utils.BitMask.new(
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
        } else @panic("Missing texture with name");

        return contact_mask_cache.get(tile_template.contact_mask_name.?);
    }

    fn _activate(self: *TileSet) void {
        // create sprite templates out of the tile templates
        var next = self.tile_templates.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_templates.get(i)) |tt| {
                var st = graphics.SpriteTemplate.Component.newAndGet(.{
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
                            var ast = graphics.SpriteTemplate.Component.newAndGet(.{
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
        graphics.Texture.Component.activateByName(self.texture_name);
    }

    fn _deactivate(self: *TileSet) void {
        // delete all sprite templates of the tile map
        var next = self.tile_templates.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_templates.get(i)) |tt| {
                graphics.SpriteTemplate.Component.dispose(tt._sprite_template_id.?);
                tt._sprite_template_id = null;
                // cleanup animation if defined
                if (tt.animation) |*animations| {
                    var next_a = animations.slots.nextSetBit(0);
                    while (next_a) |ii| {
                        if (animations.get(ii)) |frame| {
                            graphics.SpriteTemplate.Component.dispose(frame._sprite_template_id.?);
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
    blend: ?api.BlendMode = null,
    offset: ?Vector2f = null,
    parallax: ?Vector2f = null,
    tile_set_mappings: utils.DynArray(TileSetMapping) = undefined,

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
    pub const Component = api.Component.Mixin(TileMapping);
    pub const Naming = api.Component.NameMappingMixin(TileMapping);
    pub const Activation = api.Component.ActivationMixin(TileMapping);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    view_id: Index = UNDEF_INDEX,
    tile_layer_data: utils.DynArray(TileLayerData) = undefined,
    tile_grid_data: utils.DynArray(TileGridData) = undefined,
    layer_entity_mapping: utils.DynArray(utils.DynIndexArray) = undefined,

    pub fn construct(self: *TileMapping) void {
        self.tile_layer_data = utils.DynArray(TileLayerData).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
        self.tile_grid_data = utils.DynArray(TileGridData).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
        self.layer_entity_mapping = utils.DynArray(utils.DynIndexArray).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 10);
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

        next = self.layer_entity_mapping.slots.nextSetBit(0);
        while (next) |i| {
            self.layer_entity_mapping.get(i).?.deinit();
            next = self.layer_entity_mapping.slots.nextSetBit(i + 1);
        }
        self.layer_entity_mapping.deinit();
        self.layer_entity_mapping = undefined;
    }

    pub fn withTileLayerData(self: *TileMapping, tile_layer: TileLayerData) *TileLayerData {
        var tile_layer_data = self.tile_layer_data.addAndGet(tile_layer).ref;
        tile_layer_data.tile_set_mappings = utils.DynArray(TileSetMapping).newWithRegisterSize(
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
        // activate view, if nor already active
        graphics.View.Activation.activate(self.view_id);
        // create entities vor all tiles of layer based tile sets
        // for all TileLayerData ...
        var next = self.tile_layer_data.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_layer_data.get(i)) |layer_mapping| {
                // get involved layer
                if (graphics.Layer.Naming.byName(layer_mapping.layer)) |layer| {
                    // activates the layer if not already active
                    graphics.Layer.Activation.activate(layer.id);
                    // add new code -> entity mapping for layer if not existing
                    if (!self.layer_entity_mapping.exists(layer.id))
                        _ = self.layer_entity_mapping.set(
                            utils.DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 50),
                            layer.id,
                        );

                    var entity_mapping: *utils.DynIndexArray = self.layer_entity_mapping.set(
                        utils.DynIndexArray.new(firefly.api.ALLOC, 100),
                        layer.id,
                    );

                    // set layer offset and parallax
                    layer.offset = layer_mapping.offset;
                    layer.parallax = layer_mapping.parallax;

                    // get involved TileSets
                    var next_ts = layer_mapping.tile_set_mappings.slots.nextSetBit(0);
                    while (next_ts) |ii| {
                        const tile_set_mapping: *TileSetMapping = layer_mapping.tile_set_mappings.get(ii).?;
                        var code = tile_set_mapping.code_offset;
                        if (TileSet.Naming.byName(tile_set_mapping.tile_set_name)) |tile_set| {
                            TileSet.Activation.activate(tile_set.id);

                            // for all TileTemplates in TileSet
                            var next_ti = tile_set.tile_templates.slots.nextSetBit(0);
                            while (next_ti) |ti| {
                                if (tile_set.tile_templates.get(ti)) |tile_template| {

                                    // create entity from TileTemplate for specific view and layer and add code mapping
                                    const entity_id = api.Entity.new(.{
                                        .name = api.NamePool.format("{s}_{s}", .{ tile_template.name.?, layer_mapping.layer }),
                                        .groups = api.GroupKind.fromStringList(tile_template.groups),
                                    }, .{
                                        graphics.ETransform{},
                                        graphics.EView{ .view_id = self.view_id, .layer_id = layer.id },
                                        graphics.ETile{
                                            .sprite_template_id = tile_template._sprite_template_id.?,
                                            .tint_color = layer_mapping.tint,
                                            .blend_mode = layer_mapping.blend,
                                        },
                                    });

                                    // add contact if needed
                                    addContactData(entity_id, tile_set, tile_template);
                                    // add animation if needed
                                    addAnimationData(entity_id, tile_template);
                                    // set code -> entity id mapping for layer
                                    entity_mapping.set(code, entity_id);
                                    api.Entity.Activation.activate(entity_id);
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
            next = self.tile_grid_data.slots.nextSetBit(i + 1);

            const tile_grid_data = self.tile_grid_data.get(i).?;
            const layer_id = graphics.Layer.Naming.getId(tile_grid_data.layer);
            var tile_grid = graphics.TileGrid.Component.newAndGet(.{
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
                    const code = std.fmt.parseInt(Index, code_it.next().?, 10) catch 0;
                    if (code > 0) {
                        const entity_id = code_mapping.get(code);
                        tile_grid.set(x, y, entity_id);
                    }
                }
            }

            graphics.TileGrid.Activation.activate(tile_grid.id);
        }
    }

    fn addContactData(entity_id: Index, tile_set: *TileSet, tile_template: *TileTemplate) void {
        const material_type = tile_template.contact_material_type orelse return;
        physics.EContact.Component.new(entity_id, .{
            .bounds = .{ .rect = .{ 0, 0, tile_set.tile_width, tile_set.tile_height } },
            .material = material_type,
            .mask = tile_set.createContactMaskFromImage(tile_template),
        });
    }

    fn addAnimationData(entity_id: Index, tile_template: *TileTemplate) void {
        if (tile_template.animation) |*frames| {
            var list = physics.IndexFrameList.new();
            var next = frames.slots.nextSetBit(0);
            while (next) |i| {
                if (frames.get(i)) |frame|
                    _ = list.withFrame(frame._sprite_template_id.?, frame.duration);
                next = frames.slots.nextSetBit(i + 1);
            }

            physics.Animation.new(
                .{ .duration = list._duration, .looping = true, .active_on_init = true },
                physics.IndexFrameIntegrator{
                    .timeline = list,
                    .property_ref = graphics.ETile.Property.FrameId,
                },
                entity_id,
            );
        }
    }

    fn _deactivate(self: *TileMapping) void {
        // dispose all entities and clear the mapping
        var next = self.layer_entity_mapping.slots.nextSetBit(0);
        while (next) |i| {
            if (self.layer_entity_mapping.get(i)) |entity_mapping| {
                for (0..entity_mapping.size_pointer) |ii|
                    api.Entity.Component.dispose(entity_mapping.items[ii]);
                entity_mapping.deinit();
            }
            next = self.layer_entity_mapping.slots.nextSetBit(i + 1);
        }
        self.layer_entity_mapping.clear();

        // dispose all grids
        next = self.tile_grid_data.slots.nextSetBit(0);
        while (next) |i| {
            next = self.tile_grid_data.slots.nextSetBit(i + 1);
            const tile_grid_data = self.tile_grid_data.get(i).?;
            firefly.graphics.TileGrid.Naming.dispose(tile_grid_data.name);
        }
    }
};
