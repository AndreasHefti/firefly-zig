const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const graphics = inari.firefly.graphics;

//const ArrayList = std.ArrayList;
//const StringHashMap = std.StringHashMap;
//const Aspect = utils.Aspect;
//const Condition = utils.Condition;
//const DynArray = utils.DynArray;
//const BindingId = api.BindingId;
//const TextureData = api.TextureData;
//const Entity = api.Entity;
//const View = graphics.View;
//const ViewRenderListener = graphics.ViewRenderListener;
//const DynIndexArray = utils.DynIndexArray;

const Kind = utils.Kind;
const Asset = api.Asset;
const SpriteData = api.SpriteData;
const RenderData = api.RenderData;
const String = utils.String;
const Component = api.Component;
const ComponentEvent = api.Component.ComponentEvent;
const ActionType = api.Component.ActionType;
const TextureAsset = graphics.TextureAsset;
const EntityComponent = api.EntityComponent;
const EntityEventSubscription = api.EntityEventSubscription;
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
    Component.API.registerComponent(SpriteTemplate);
    EntityComponent.registerEntityComponent(ESprite);
    // init renderer
    SimpleSpriteRenderer.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit renderer
    SimpleSpriteRenderer.deinit();
    // deinit Assets
    //SpriteSetAsset.deinit();
}

//////////////////////////////////////////////////////////////
//// Sprite Template Components
//////////////////////////////////////////////////////////////

pub const SpriteTemplate = struct {
    pub usingnamespace Component.API.ComponentTrait(
        @This(),
        .{
            .name = "SpriteTemplate",
            .activation = false,
            .processing = false,
            .subscription = false,
        },
    );

    id: Index = UNDEF_INDEX,
    name: String = NO_NAME,
    texture_asset_name: String = NO_NAME,
    sprite_data: SpriteData,

    pub fn init() !void {
        Asset.subscribe(notifyAssetEvent);
    }

    pub fn deinit() void {
        Asset.unsubscribe(notifyAssetEvent);
    }

    fn notifyAssetEvent(e: ComponentEvent) void {
        var asset: *Asset = Asset.byId(e.c_id);
        if (asset.asset_type.index != TextureAsset.asset_type.index)
            return;
        if (utils.stringEquals(asset.name, NO_NAME))
            return;

        switch (e.event_type) {
            ActionType.ACTIVATED => onTextureLoad(asset),
            ActionType.DEACTIVATING => onTextureUnload(asset),
            ActionType.DISPOSING => onTextureDispose(asset),
            else => {},
        }
    }

    fn onTextureLoad(asset: *Asset) void {
        const tex_binding_id = TextureAsset.getBindingByAssetId(asset.id);
        var next = SpriteTemplate.nextId(0);
        while (next) |id| {
            var template = SpriteTemplate.byId(id);
            if (utils.stringEquals(template.texture_asset_name, asset.name)) {
                template.sprite_data.texture_binding = tex_binding_id;
            }
            next = SpriteTemplate.nextId(id + 1);
        }
    }

    fn onTextureUnload(asset: *Asset) void {
        var next = SpriteTemplate.nextId(0);
        while (next) |id| {
            var template = SpriteTemplate.byId(id);
            if (utils.stringEquals(template.texture_asset_name, asset.name)) {
                template.sprite_data.texture_binding = NO_BINDING;
            }
            next = SpriteTemplate.nextId(id + 1);
        }
    }

    fn onTextureDispose(asset: *Asset) void {
        var next = SpriteTemplate.nextId(0);
        while (next) |id| {
            var template = SpriteTemplate.byId(id);
            if (utils.stringEquals(template.texture_asset_name, asset.name)) {
                SpriteTemplate.disposeById(id);
            }
            next = SpriteTemplate.nextId(id + 1);
        }
    }
};

//////////////////////////////////////////////////////////////
//// ESprite Sprite Entity Component
//////////////////////////////////////////////////////////////

pub const ESprite = struct {
    pub usingnamespace EntityComponent.API.Adapter(@This(), "ESprite");

    id: Index = UNDEF_INDEX,
    template_id: Index,
    render_data: RenderData = .{},
    offset: Vec2f = .{ 0, 0 },

    pub fn destruct(self: *ESprite) void {
        self.template_id = UNDEF_INDEX;
        self.render_data = .{};
        self.offset = .{ 0, 0 };
    }
};

//////////////////////////////////////////////////////////////
//// Sprite Set Asset
//////////////////////////////////////////////////////////////

// pub const SpriteSetAsset = struct {
//     pub var asset_type: *Aspect = undefined;

//     pub const SpriteStamp = struct {
//         name: String = NO_NAME,
//         flip_x: bool = false,
//         flip_y: bool = false,
//         offset: Vec2f = Vec2f{ 0, 0 },
//     };

//     texture_asset_id: Index,
//     stamp_region: RectF,
//     sprite_dim: Vec2f,
//     stamps: ?[]?SpriteStamp = null,

//     fn getStamp(self: *SpriteSetAsset, x: usize, y: usize) ?SpriteStamp {
//         if (self.stamps) |sp| {
//             const index = y * self.stamp_region[2] + x;
//             if (index < sp.len) {
//                 return sp[index];
//             }
//         }
//         return null;
//     }

//     fn init() void {
//         asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("SpriteSet");
//         Asset.subscribe(listener);
//     }

//     fn deinit() void {
//         Asset.unsubscribe(listener);
//         asset_type = undefined;
//     }

//     pub fn new(data: SpriteSetAsset) *Asset {
//         if (!initialized)
//             @panic("Firefly module not initialized");

//         if (data.texture_asset_id != UNDEF_INDEX and Asset.pool.exists(data.texture_asset_id))
//             @panic("SpriteSetData has invalid TextureAsset reference id");

//         var asset: *Asset = Asset.new(Asset{
//             .asset_type = asset_type,
//             .name = data.asset_name,
//             .resource_id = sprite_sets.add(SpriteSet.new()),
//             .parent_asset_id = data.texture_asset_id,
//         });

//         const ss: *SpriteSet = sprite_sets.get(asset.resource_id);

//         for (0..data.stamp_region[3]) |y| {
//             for (0..data.stamp_region[2]) |x| {
//                 var sd = SpriteData{};

//                 sd.texture_bounds[0] = x * data.sprite_dim[0] + data.stamp_region[0]; // x pos
//                 sd.texture_bounds[1] = y * data.sprite_dim[1] + data.stamp_region[1]; // y pos
//                 sd.texture_bounds[2] = data.sprite_dim[0]; // width
//                 sd.texture_bounds[3] = data.sprite_dim[1]; // height

//                 if (data.getStamp(x, y)) |stamp| {
//                     sd.texture_bounds[0] = sd.texture_bounds[0] + stamp.offset[0]; // x offset
//                     sd.texture_bounds[1] = sd.texture_bounds[1] + stamp.offset[1]; // y offset
//                     if (stamp.flip_x) sd.flip_x();
//                     if (stamp.flip_y) sd.flip_y();
//                     if (stamp.name != NO_NAME) {
//                         ss.name_mapping.put(stamp.name, ss.sprites.items.len);
//                     }
//                 }

//                 ss.sprites.append(sprites.add(sd)) catch unreachable;
//             }
//         }
//     }

//     pub fn getResource(res_id: Index) *SpriteSet {
//         return &sprite_sets.get(res_id);
//     }

//     fn listener(e: ComponentEvent) void {
//         var asset: *Asset = Asset.byId(e.c_id);
//         if (asset_type.index != asset.asset_type.index)
//             return;

//         switch (e.event_type) {
//             ActionType.ACTIVATED => load(asset),
//             ActionType.DEACTIVATING => unload(asset),
//             ActionType.DISPOSING => delete(asset),
//             else => {},
//         }
//     }

//     fn load(asset: *Asset) void {
//         if (!initialized)
//             return;

//         // check if texture asset is loaded, if not try to load
//         const tex_binding_id = TextureAsset.getBindingByAssetId(asset.parent_asset_id);
//         if (sprite_sets.get(asset.resource_id)) |ss| {
//             for (ss.sprites_indices.items) |id| {
//                 if (sprites.get(id)) |s| s.texture_binding = tex_binding_id;
//             }
//         }
//     }

//     fn unload(asset: *Asset) void {
//         if (!initialized)
//             return;

//         if (sprite_sets.get(asset.resource_id)) |ss| {
//             for (ss.sprites_indices.items) |id| {
//                 if (sprites.get(id)) |s| s.texture_binding = NO_BINDING;
//             }
//         }
//     }

//     fn delete(asset: *Asset) void {
//         Asset.activateById(asset.id, false);
//         if (sprite_sets.get(asset.resource_id)) |ss| ss.deinit();
//         sprite_sets.delete(asset.resource_id);
//         asset.resource_id = UNDEF_INDEX;
//     }
// };

//////////////////////////////////////////////////////////////
//// Simple Sprite Renderer System
//////////////////////////////////////////////////////////////

const SimpleSpriteRenderer = struct {
    const sys_name = "SimpleSpriteRenderer";

    var ee_subscription: EntityEventSubscription(SimpleSpriteRenderer) = undefined;
    var sprite_refs: ViewLayerMapping = undefined;

    fn init() void {
        ee_subscription = EntityEventSubscription(SimpleSpriteRenderer)
            .of(registerEntity)
            .withAcceptKind(Kind.of(ETransform.type_aspect).with(ESprite.type_aspect))
            .withDismissKind(Kind.of(EMultiplier.type_aspect))
            .subscribe();

        sprite_refs = ViewLayerMapping.new();
        _ = System.new(.{
            .name = sys_name,
            .info = "Render Entities with ETransform and ESprite components",
            .onActivation = onActivation,
        });
        System.activateByName(sys_name, true);
    }

    fn deinit() void {
        System.disposeByName(sys_name);
        _ = ee_subscription.unsubscribe();
        ee_subscription = undefined;
        sprite_refs.deinit();
        sprite_refs = undefined;
    }

    fn onActivation(active: bool) void {
        if (active) {
            graphics.ViewRenderer.subscribeAt(0, render);
        } else {
            graphics.ViewRenderer.unsubscribe(render);
        }
    }

    fn registerEntity(e: ComponentEvent) void {
        var transform = ETransform.byId(e.c_id);
        switch (e.event_type) {
            ActionType.ACTIVATED => sprite_refs.add(transform.view_id, transform.layer_id, e.c_id),
            ActionType.DEACTIVATING => sprite_refs.remove(transform.view_id, transform.layer_id, e.c_id),
            else => {},
        }
    }

    fn render(e: ViewRenderEvent) void {
        if (sprite_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the sprite
                var es = ESprite.byId(id);
                if (es.template_id != UNDEF_INDEX) {
                    api.rendering.renderSprite(
                        &SpriteTemplate.byId(es.template_id).sprite_data,
                        &ETransform.byId(id).transform,
                        &es.render_data,
                        es.offset,
                    );
                }
                i = all.nextSetBit(id + 1);
            }
        }
    }
};
