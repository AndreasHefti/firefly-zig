const std = @import("std");
const firefly = @import("graphics.zig").firefly;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const api = firefly.api;
const Aspect = firefly.utils.aspect.Aspect;
const Asset = firefly.Asset;
const DynArray = firefly.utils.dynarray.DynArray;
const SpriteData = api.SpriteData;
const BindingIndex = api.BindingIndex;
const String = firefly.utils.String;
const Event = api.Component.Event;
const ActionType = api.Component.ActionType;
const TextureData = firefly.api.TextureData;
const NO_NAME = firefly.utils.NO_NAME;
const NO_BINDING = firefly.api.NO_BINDING;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const RectF = firefly.utils.geom.RectF;
const Vec2f = firefly.utils.geom.Vector2f;

const SpriteSet = struct {
    sprites: ArrayList(SpriteData) = undefined,
    name_mapping: StringHashMap(usize) = undefined,

    fn byListIndex(self: *SpriteSet, index: usize) *SpriteData {
        return &self.sprites.items[index];
    }

    fn byName(self: *SpriteSet, name: String) *SpriteData {
        if (self.name_mapping.get(name)) |index| {
            return &self.sprites.items[index];
        } else {
            std.log.err("No sprite with name: {s} found", .{name});
            @panic("not found");
        }
    }
};

var initialized = false;
var resources: DynArray(SpriteSet) = undefined;
pub var asset_type: *Aspect = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("SpriteSet");
    resources = DynArray(SpriteSet).init(firefly.COMPONENT_ALLOC, SpriteSet{});
    Asset.subscribe(listener);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    Asset.unsubscribe(listener);
    asset_type = undefined;
    resources.deinit();
    resources = undefined;
}

pub const SpriteStamp = struct {
    name: String = NO_NAME,
    flip_x: bool = false,
    flip_y: bool = false,
    offset: Vec2f = Vec2f{ 0, 0 },
};

pub const SpriteSetData = struct {
    texture_asset_id: UNDEF_INDEX,
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
        .resource_id = resources.add(
            SpriteSet{
                .sprites = ArrayList(SpriteData).init(firefly.COMPONENT_ALLOC),
                .name_mapping = StringHashMap(usize).init(firefly.COMPONENT_ALLOC),
            },
        ),
        .parent_asset_id = data.texture_asset_id,
    });

    const ss: *SpriteSet = resources.get(asset.resource_id);

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

            ss.sprites.append(sd) catch unreachable;
        }
    }
}

pub fn getResource(res_index: usize) *SpriteSet {
    return &resources.get(res_index).byListIndex(0);
}

pub fn getResourceForIndex(res_index: usize, list_index: usize) *SpriteSet {
    return &resources.get(res_index).byListIndex(list_index);
}

pub fn getResourceForName(res_index: usize, name: String) *SpriteSet {
    return resources.get(res_index).byName(name);
}

fn listener(e: Event) void {
    var asset: *Asset = Asset.pool.byId(e.c_index);
    if (asset_type.index != asset.asset_type.index)
        return;

    switch (e.event_type) {
        ActionType.Activated => load(asset),
        ActionType.Deactivated => unload(asset),
        ActionType.Disposing => delete(asset),
        else => {},
    }
}

fn load(asset: *Asset) void {
    if (!initialized) @panic("Firefly module not initialized");

    // check if texture asset is loaded, if not try to load
    const texData: *const TextureData = Asset.byId(asset.parent_asset_id).getResource(TextureData);
    if (texData.binding == NO_BINDING) {
        Asset.activateById(asset.parent_asset_id, true);
        if (texData.binding == NO_BINDING) {
            std.log.err("Failed to load/activate dependent TextureAsset: {any}", .{Asset.byId(asset.parent_asset_id)});
            return;
        }
    }

    var data: *SpriteSet = resources.get(asset.resource_id);
    for (data.sprites) |*s| {
        s.texture_binding = texData.binding;
    }
}

fn unload(asset: *Asset) void {
    if (!initialized) @panic("Firefly module not initialized");

    const data: *SpriteSet = resources.get(asset.resource_id);
    for (data.sprites) |*s| {
        s.texture_binding = NO_BINDING;
    }
}

fn delete(asset: *Asset) void {
    Asset.activateById(asset.index, false);
    resources.reset(asset.resource_id);
}
