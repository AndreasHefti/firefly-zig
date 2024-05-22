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

const DynIndexArray = firefly.utils.DynIndexArray;
const BlendMode = firefly.api.BlendMode;
const Color = firefly.utils.Color;
const String = firefly.utils.String;
const Index = firefly.utils.Index;
const RectF = firefly.utils.RectF;
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

pub const TileTemplate = struct {
    name: ?String = null,
    groups: ?String = null,
    tile_kind: ?TileTypeKind = null,
    tint_color: ?Color = null,
    blend_mode: ?BlendMode = null,

    contact_material_type: ?ContactMaterialAspect = null,
    contact_type: ?ContactTypeAspect = null,
    contact_mask: ?BitMask = null,

    sprite_template_id: Index = UNDEF_INDEX,
    sprite_animation: ?IndexFrameList = null,
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

    tile_templates: DynIndexArray = undefined,

    pub fn construct(self: *TileSet) void {
        self.tile_templates = DynIndexArray.init(firefly.api.COMPONENT_ALLOC, 50);
    }

    pub fn destruct(self: *TileSet) void {
        self.tile_templates.deinit();
        self.tile_templates = undefined;
    }

    pub fn withTileTemplate(self: *TileSet, template: TileTemplate) *TileSet {
        self.tile_templates.add(TileTemplate.new(template).id);
        return self;
    }

    // pub fn activation(self: *TileSet, active: bool) void {
    //     if (active) {
    //         self.activate();
    //     } else {
    //         self.deactivate();
    //     }

    // }

    // fn activate(self: *TileSet) void {
    //     // make sure texture for sprite set is defined and loaded
    //     if (Texture.resourceByName(self.texture_name)) |texture| {
    //         // create all sprite templates

    //     }

    // }

    // fn dactivate(self: *TileSet) void {

    // }

    // override fun activate() {
    //     super.activate()

    //     // make sure texture for sprite set is defined and loaded
    //     if (!textureRef.exists)
    //         throw IllegalStateException("textureRef missing")
    //     val texture = Texture[textureRef.targetKey]
    //     if (!texture.loaded)
    //         Texture.load(textureRef.targetKey)

    //     // load all sprites on low level
    //     val textureIndex = texture.assetIndex
    //     val iter = tileTemplates.iterator()
    //     while (iter.hasNext()) {
    //         val tileTemplate = iter.next()
    //         val spriteTemplate = tileTemplate.spriteTemplate
    //         spriteTemplate.textureIndex = textureIndex
    //         spriteTemplate.spriteIndex = Engine.graphics.createSprite(spriteTemplate.spriteData)
    //         if (tileTemplate.animationData != null) {
    //             val iter = tileTemplate.animationData!!.sprites.values.iterator()
    //             while (iter.hasNext()) {
    //                 val aSpriteTemplate = iter.next()
    //                 aSpriteTemplate.textureIndex = textureIndex
    //                 aSpriteTemplate.spriteIndex = Engine.graphics.createSprite(aSpriteTemplate.spriteData)
    //             }
    //         }
    //     }
    // }

    // override fun deactivate() {
    //     for (i in 0 until tileTemplates.capacity) {
    //         val tileTemplate = tileTemplates[i] ?: continue
    //         Engine.graphics.disposeSprite(tileTemplate.spriteTemplate.spriteIndex)
    //         tileTemplate.spriteTemplate.spriteIndex = NULL_COMPONENT_INDEX
    //         if (tileTemplate.animationData != null) {
    //             val iter = tileTemplate.animationData!!.sprites.values.iterator()
    //             while (iter.hasNext()) {
    //                 val aSpriteTemplate = iter.next()
    //                 Engine.graphics.disposeSprite(aSpriteTemplate.spriteIndex)
    //                 aSpriteTemplate.spriteIndex = NULL_COMPONENT_INDEX
    //             }
    //         }
    //     }
    //     super.dispose()
    // }
};
