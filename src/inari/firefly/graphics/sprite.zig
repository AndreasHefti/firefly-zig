const std = @import("std");
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const graphics = @import("graphics.zig");
const api = graphics.api;
const utils = graphics.utils;

const Aspect = utils.aspect.Aspect;
const Kind = utils.aspect.Kind;
const Asset = api.Asset;
const DynArray = utils.dynarray.DynArray;
const SpriteData = api.SpriteData;
const RenderData = api.RenderData;
const BindingId = api.BindingId;
const String = utils.String;
const ComponentEvent = api.Component.ComponentEvent;
const ActionType = api.Component.ActionType;
const TextureData = api.TextureData;
const TextureAsset = graphics.TextureAsset;
const Entity = api.Entity;
const EntityComponent = api.EntityComponent;
const ETransform = graphics.view.ETransform;
const EMultiplier = graphics.view.EMultiplier;
const View = graphics.View;
const ViewLayerMapping = graphics.view.ViewLayerMapping;
const ViewRenderEvent = graphics.view.ViewRenderEvent;
const ViewRenderListener = graphics.view.ViewRenderListener;
const System = api.System;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;

//////////////////////////////////////////////////////////////
//// global
//////////////////////////////////////////////////////////////

var sprites: DynArray(SpriteData) = undefined;
var sprite_sets: DynArray(SpriteSet) = undefined;

pub const SpriteSet = struct {
    sprites: ArrayList(Index) = undefined,
    name_mapping: StringHashMap(Index) = undefined,

    fn byListIndex(self: *SpriteSet, index: Index) *const SpriteData {
        return sprites.get(self.sprites.items[index]);
    }

    fn byName(self: *SpriteSet, name: String) *const SpriteData {
        if (self.name_mapping.get(name)) |index| {
            return sprites.get(self.sprites.items[index]);
        } else {
            std.log.err("No sprite with name: {s} found", .{name});
            @panic("not found");
        }
    }
};

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    sprites = try DynArray(SpriteData).init(api.COMPONENT_ALLOC, SpriteAsset.NULL_VALUE);
    sprite_sets = try DynArray(SpriteSet).init(api.COMPONENT_ALLOC, SpriteSetAsset.NULL_VALUE);
    // init Asset
    SpriteAsset.init();
    SpriteSetAsset.init();
    // init components and entities
    EntityComponent.registerEntityComponent(ESprite);
    // init renderer
    SimpleSpriteRenderer.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    sprites.deinit();
    sprites = undefined;
    sprite_sets.deinit();
    sprite_sets = undefined;
    // deinit renderer
    SimpleSpriteRenderer.deinit();
    // deinit Assets
    SpriteSetAsset.deinit();
    SpriteAsset.deinit();
}

//////////////////////////////////////////////////////////////
//// ESprite Sprite Entity Component
//////////////////////////////////////////////////////////////

pub const ESprite = struct {
    // component type fields
    pub const NULL_VALUE = ESprite{};
    pub const COMPONENT_NAME = "ESprite";
    pub const pool = Entity.EntityComponentPool(ESprite);
    // component type pool references
    pub var type_aspect: *Aspect = undefined;
    pub var get: *const fn (Index) *ESprite = undefined;
    pub var byId: *const fn (Index) *const ESprite = undefined;

    id: Index = UNDEF_INDEX,
    sprite_ref: BindingId = NO_BINDING,
    render_data: RenderData = RenderData{},
    offset: Vec2f = Vec2f{ 0, 0 },

    pub fn setSpriteByAssetName(self: *ESprite, view_name: String) void {
        self.view_id = View.byName(view_name).id;
    }

    pub fn destruct(self: *ESprite) void {
        self.sprite_ref = NO_BINDING;
        self.render_data = RenderData{};
        self.offset = Vec2f{ 0, 0 };
    }
};

//////////////////////////////////////////////////////////////
//// Sprite Asset
//////////////////////////////////////////////////////////////

pub const SpriteAsset = struct {
    pub var asset_type: *Aspect = undefined;
    pub const NULL_VALUE = SpriteData{};

    pub const Sprite = struct {
        name: String = NO_NAME,
        texture_asset_id: Index,
        texture_bounds: RectF,
        flip_x: bool = false,
        flip_y: bool = false,
    };

    fn init() void {
        asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Sprite");
        Asset.subscribe(listener);
    }

    fn deinit() void {
        Asset.unsubscribe(listener);
        asset_type = undefined;
    }

    pub fn new(data: Sprite) *Asset {
        if (!initialized)
            @panic("Firefly module not initialized");

        if (data.texture_asset_id != UNDEF_INDEX and Asset.pool.exists(data.texture_asset_id))
            @panic("Sprite has invalid TextureAsset reference id");

        var spriteData = SpriteData{
            .texture_bounds = data.texture_bounds,
        };
        if (data.flip_x)
            spriteData.flip_x();
        if (data.flip_y)
            spriteData.flip_y();

        return Asset.new(Asset{
            .asset_type = asset_type,
            .name = data.asset_name,
            .resource_id = sprites.add(spriteData),
            .parent_asset_id = data.texture_asset_id,
        });
    }

    pub fn getResource(res_id: Index) *const SpriteData {
        return sprites.get(res_id);
    }

    pub fn getResourceForIndex(res_id: Index, _: Index) *const SpriteData {
        return sprites.get(res_id);
    }

    pub fn getResourceForName(res_id: Index, _: String) *const SpriteData {
        return sprites.get(res_id);
    }

    fn listener(e: *const ComponentEvent) void {
        var asset: *Asset = Asset.pool.get(e.c_id);
        if (asset_type.index != asset.asset_type.index)
            return;

        switch (e.event_type) {
            ActionType.ACTIVATED => load(asset),
            ActionType.DEACTIVATING => unload(asset),
            ActionType.DISPOSING => delete(asset),
            else => {},
        }
    }

    fn load(asset: *Asset) void {
        if (!initialized)
            return;

        var spriteData: *SpriteData = sprites.get(asset.resource_id);
        if (spriteData.texture_binding != NO_BINDING)
            return; // already loaded

        // check if texture asset is loaded, if not try to load
        const texData: *const TextureData = Asset.get(asset.parent_asset_id).getResource(TextureAsset);
        if (texData.binding == NO_BINDING) {
            Asset.activateById(asset.parent_asset_id, true);
            if (texData.binding == NO_BINDING) {
                std.log.err("Failed to load/activate dependent TextureAsset: {any}", .{Asset.byId(asset.parent_asset_id)});
                return;
            }
        }

        spriteData.texture_binding = texData.binding;
    }

    fn unload(asset: *Asset) void {
        if (!initialized)
            return;

        var spriteData: *SpriteData = sprites.get(asset.resource_id);
        spriteData.texture_binding = NO_BINDING;
    }

    fn delete(asset: *Asset) void {
        Asset.activateById(asset.id, false);
        sprites.reset(asset.resource_id);
    }
};

//////////////////////////////////////////////////////////////
//// Sprite Set Asset
//////////////////////////////////////////////////////////////

pub const SpriteSetAsset = struct {
    pub var asset_type: *Aspect = undefined;
    pub const NULL_VALUE = SpriteSet{};

    fn init() void {
        asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("SpriteSet");
        Asset.subscribe(listener);
    }

    fn deinit() void {
        Asset.unsubscribe(listener);
        asset_type = undefined;
    }

    pub const SpriteStamp = struct {
        name: String = NO_NAME,
        flip_x: bool = false,
        flip_y: bool = false,
        offset: Vec2f = Vec2f{ 0, 0 },
    };

    pub const SpriteSetData = struct {
        texture_asset_id: Index,
        stamp_region: RectF,
        sprite_dim: Vec2f,
        stamps: ?[]?SpriteStamp = null,

        fn getStamp(self: *SpriteSetData, x: usize, y: usize) ?SpriteStamp {
            if (self.stamps) |sp| {
                const index = y * self.stamp_region[2] + x;
                if (index < sp.len) {
                    return sp[index];
                }
            }
            return null;
        }
    };

    pub fn new(data: SpriteSetData) *Asset {
        if (!initialized)
            @panic("Firefly module not initialized");

        if (data.texture_asset_id != UNDEF_INDEX and Asset.pool.exists(data.texture_asset_id))
            @panic("SpriteSetData has invalid TextureAsset reference id");

        var asset: *Asset = Asset.new(Asset{
            .asset_type = asset_type,
            .name = data.asset_name,
            .resource_id = sprite_sets.add(
                SpriteSet{
                    .sprites = ArrayList(Index).init(api.COMPONENT_ALLOC),
                    .name_mapping = StringHashMap(Index).init(api.COMPONENT_ALLOC),
                },
            ),
            .parent_asset_id = data.texture_asset_id,
        });

        const ss: *SpriteSet = sprite_sets.get(asset.resource_id);

        for (0..data.stamp_region[3]) |y| {
            for (0..data.stamp_region[2]) |x| {
                var sd = SpriteData{};

                sd.texture_bounds[0] = x * data.sprite_dim[0] + data.stamp_region[0]; // x pos
                sd.texture_bounds[1] = y * data.sprite_dim[1] + data.stamp_region[1]; // y pos
                sd.texture_bounds[2] = data.sprite_dim[0]; // width
                sd.texture_bounds[3] = data.sprite_dim[1]; // height

                if (data.getStamp(x, y)) |stamp| {
                    sd.texture_bounds[0] = sd.texture_bounds[0] + stamp.offset[0]; // x offset
                    sd.texture_bounds[1] = sd.texture_bounds[1] + stamp.offset[1]; // y offset
                    if (stamp.flip_x) sd.flip_x();
                    if (stamp.flip_y) sd.flip_y();
                    if (stamp.name != NO_NAME) {
                        ss.name_mapping.put(stamp.name, ss.sprites.items.len);
                    }
                }

                ss.sprites.append(sprites.add(sd)) catch unreachable;
            }
        }
    }

    pub fn getResource(res_id: Index) *SpriteSet {
        return &sprite_sets.get(res_id).byListIndex(0);
    }

    pub fn getResourceForIndex(res_id: Index, list_index: Index) *SpriteSet {
        return &sprite_sets.get(res_id).byListIndex(list_index);
    }

    pub fn getResourceForName(res_id: Index, name: String) *SpriteSet {
        return sprite_sets.get(res_id).byName(name);
    }

    fn listener(e: *const ComponentEvent) void {
        var asset: *Asset = Asset.pool.get(e.c_id);
        if (asset_type.index != asset.asset_type.index)
            return;

        switch (e.event_type) {
            ActionType.ACTIVATED => load(asset),
            ActionType.DEACTIVATING => unload(asset),
            ActionType.DISPOSING => delete(asset),
            else => {},
        }
    }

    fn load(asset: *Asset) void {
        if (!initialized)
            return;

        // check if texture asset is loaded, if not try to load
        const texData: *const TextureData = Asset.get(asset.parent_asset_id).getResource(TextureAsset);
        if (texData.binding == NO_BINDING) {
            Asset.activateById(asset.parent_asset_id, true);
            if (texData.binding == NO_BINDING) {
                std.log.err("Failed to load/activate dependent TextureAsset: {any}", .{Asset.byId(asset.parent_asset_id)});
                return;
            }
        }

        var data: *SpriteSet = sprite_sets.get(asset.resource_id);
        for (data.sprites.items) |id| {
            sprites.get(id).texture_binding = texData.binding;
        }
    }

    fn unload(asset: *Asset) void {
        if (!initialized)
            return;

        const data: *SpriteSet = sprite_sets.get(asset.resource_id);
        for (data.sprites.items) |id| {
            sprites.get(id).texture_binding = NO_BINDING;
        }
    }

    fn delete(asset: *Asset) void {
        Asset.activateById(asset.id, false);
        const data: *SpriteSet = sprite_sets.get(asset.resource_id);
        for (data.sprites.items) |id| {
            sprites.reset(id);
        }
        sprite_sets.reset(asset.resource_id);
    }
};

//////////////////////////////////////////////////////////////
//// Simple Sprite Renderer System
//////////////////////////////////////////////////////////////

const SimpleSpriteRenderer = struct {
    const sys_name = "SimpleSpriteRenderer";
    var sprite_refs: ViewLayerMapping = undefined;

    fn init() void {
        sprite_refs = ViewLayerMapping.new();
        _ = System.new(System{
            .name = sys_name,
            .info = "Render Entities with ETransform and ESprite components",
            .onEntityEvent = handleEntityEvent,
            .entity_accept_kind = Kind.of(ETransform.type_aspect).with(ESprite.type_aspect),
            .entity_dismiss_kind = Kind.of(EMultiplier.type_aspect),
            .onActivation = onActivation,
        });
        System.activateByName(sys_name, true);
    }

    fn deinit() void {
        System.activateByName(sys_name, false);
        System.disposeByName(sys_name);
        sprite_refs.deinit();
    }

    fn onActivation(active: bool) void {
        if (active) {
            graphics.view.subscribeViewRenderingAt(0, handleRenderEvent);
        } else {
            graphics.view.unsubscribeViewRendering(handleRenderEvent);
        }
    }

    fn handleEntityEvent(e: *const ComponentEvent) void {
        var transform = ETransform.byId(e.c_id);
        switch (e.event_type) {
            ActionType.ACTIVATED => sprite_refs.add(transform.view_id, transform.layer_id, e.c_id),
            ActionType.DEACTIVATING => sprite_refs.remove(transform.view_id, transform.layer_id, e.c_id),
            else => {},
        }
    }

    // fn accepted(entity_id: Index) ?*const ETransform {
    //     const e_kind = &Entity.byId(entity_id).kind;
    //     if (accept_kind.isKindOf(e_kind) and dismiss_kind.isNotKindOf(e_kind)) {
    //         return ETransform.byId(entity_id);
    //     }
    //     return null;
    // }

    fn handleRenderEvent(e: ViewRenderEvent) void {
        if (sprite_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                var s = ESprite.byId(id);
                api.RENDERING_API.renderSprite(
                    sprites.get(s.sprite_ref),
                    &ETransform.byId(id).transform,
                    &s.render_data,
                    s.offset,
                );
            }
        }
    }
};
