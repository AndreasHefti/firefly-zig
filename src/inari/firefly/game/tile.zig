const std = @import("std");
const firefly = @import("../firefly.zig");

const Component = firefly.api.Component;
const ContactMaterialAspect = firefly.physics.ContactMaterialAspect;
const ContactMaterialAspectGroup = firefly.physics.ContactMaterialAspectGroup;
const TileTypeKind = firefly.graphics.TileTypeKind;
const BitMask = firefly.utils.BitMask;
const IndexFrameList = firefly.physics.IndexFrameList;
const ContactTypeAspect = firefly.physics.ContactTypeAspect;
const Asset = firefly.api.Asset;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;

const DynArray = firefly.utils.DynArray;
const BlendMode = firefly.api.BlendMode;
const Color = firefly.utils.Color;
const String = firefly.utils.String;
const Index = firefly.utils.Index;
const RectF = firefly.utils.RectF;
const BindingId = firefly.api.BindingId;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// game tile init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    TileContactMaterialTypes.NONE = ContactMaterialAspectGroup.getAspect("NONE");
    TileContactMaterialTypes.TERRAIN = ContactMaterialAspectGroup.getAspect("TERRAIN");
    TileContactMaterialTypes.PROJECTILE = ContactMaterialAspectGroup.getAspect("PROJECTILE");
    TileContactMaterialTypes.WATER = ContactMaterialAspectGroup.getAspect("WATER");
    TileContactMaterialTypes.LADDER = ContactMaterialAspectGroup.getAspect("LADDER");
    TileContactMaterialTypes.ROPE = ContactMaterialAspectGroup.getAspect("ROPE");
    TileContactMaterialTypes.INTERACTIVE = ContactMaterialAspectGroup.getAspect("INTERACTIVE");
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

pub const TileContactMaterialTypes = struct {
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
    tile_kind: ?TileTypeKind = null,

    sprite_data: SpriteData,
    animation: ?DynArray(TileAnimationFrame) = null,

    contact_material_type: ?ContactMaterialAspect = null,
    contact_type: ?ContactTypeAspect = null,
    contact_mask_id: ?String = null,

    _sprite_template_id: ?Index = null,

    pub fn withAnimationFrame(self: *TileTemplate, frame: TileAnimationFrame) *TileTemplate {
        if (self.animation == null)
            self.animation = DynArray(TileAnimationFrame).new(firefly.api.COMPONENT_ALLOC);

        if (self.animation) |a|
            _ = a.add(frame);

        return self;
    }

    pub fn deinit(self: *TileTemplate) void {
        if (self.animation) |a|
            a.deinit();
    }
};

pub const TileSet = struct {
    pub usingnamespace Component.Trait(
        @This(),
        .{
            .name = "TileSet",
            .processing = false,
            .subscription = false,
        },
    );

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    tile_map_start_index: Index = UNDEF_INDEX,
    texture_name: String,

    tile_templates: DynArray(TileTemplate) = undefined,

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
        self.tile_templates.add(TileTemplate.new(template).id);
        return self;
    }

    pub fn activation(self: *TileSet, active: bool) void {
        if (active) {
            self.activate();
        } else {
            self.deactivate();
        }
    }

    fn activate(self: *TileSet) void {
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
                    st.flipX();
                if (tt.sprite_data.flip_y)
                    st.flipY();
                tt._sprite_template_id = st.id;

                // animation if defined...
                if (tt.animation) |animations| {
                    var next_a = animations.slots.nextSetBit(0);
                    while (next_a) |ii| {
                        if (animations.get(ii)) |frame| {
                            var ast: *SpriteTemplate = SpriteTemplate.new(.{
                                .texture_name = self.texture_name,
                                .texture_bounds = frame.sprite_data.texture_bounds,
                            });
                            if (frame.sprite_data.flip_x)
                                ast.flipX();
                            if (frame.sprite_data.flip_y)
                                ast.flipY();
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

    fn deactivate(self: *TileSet) void {
        // delete all sprite templates of the tile map
        var next = self.tile_templates.slots.nextSetBit(0);
        while (next) |i| {
            if (self.tile_templates.get(i)) |tt| {
                SpriteTemplate.disposeById(tt._sprite_template_id.?);
                tt._sprite_template_id = null;
                // cleanup animation if defined
                if (tt.animation) |animations| {
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

pub const TileMapping = struct {
    pub usingnamespace Component.Trait(
        @This(),
        .{
            .name = "TileSet",
            .processing = false,
            .subscription = false,
        },
    );
};
