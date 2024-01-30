const std = @import("std");
const firefly = @import("../firefly.zig"); // TODO better way for import package?
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const api = firefly.api;
const Aspect = firefly.utils.aspect.Aspect;
const Asset = firefly.Asset;
const DynArray = firefly.utils.dynarray.DynArray;

const SpriteData = api.SpriteData;
const BindingIndex = api.BindingIndex;
const String = firefly.utils.String;
const NO_NAME = firefly.utils.NO_NAME;
const NO_BINDING = firefly.api.NO_BINDING;
const RectF = firefly.utils.geom.RectF;
const Vec2f = firefly.utils.geom.Vector2f;
const Event = api.component.Event;
const ActionType = api.component.ActionType;

const SpriteSet = struct {
    const NULL = SpriteData{};

    texture_asset: BindingIndex,
    sprites: ArrayList(SpriteData) = undefined,
    name_mapping: StringHashMap(usize) = undefined,

    fn byName(self: *SpriteSet, name: String) *SpriteData {
        if (self.name_mapping.get(name)) |index| {
            return &self.sprites.items[index];
        } else {
            std.log.err("No sprite with name: {s} found", .{name});
            return &NULL;
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
    texture_asset: BindingIndex,
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
    if (!initialized) @panic("Firefly module not initialized");

    var asset: *Asset = Asset.new(Asset{
        .asset_type = asset_type,
        .name = data.asset_name,
        .binding_by_index = bindingByAsset,
        .binding_by_name = bindingByName,
        .resource_id = resources.add(
            SpriteSet{
                .texture_asset = data.texture_asset,
                .sprites = ArrayList(SpriteData).init(firefly.COMPONENT_ALLOC),
                .name_mapping = StringHashMap(usize).init(firefly.COMPONENT_ALLOC),
            },
        ),
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

pub fn get(binding: BindingIndex, index: usize) *SpriteData {
    return &resources.register.get(binding).sprites[index];
}

pub fn getByName(binding: BindingIndex, name: String) *SpriteData {
    &resources.register.get(binding).byName(name);
}

pub fn bindingByAsset(_: *Asset, index: usize) BindingIndex {
    return index;
}

pub fn bindingByName(asset: *Asset, name: String) BindingIndex {
    return resources.register.get(asset.resource_id).name_mapping.get(name).? orelse NO_BINDING;
}

fn listener(e: Event) void {
    switch (e.event_type) {
        ActionType.Activated => load(Asset.pool.byId(e.c_index)),
        ActionType.Deactivated => unload(Asset.pool.byId(e.c_index)),
        ActionType.Disposing => delete(Asset.pool.byId(e.c_index)),
        else => {},
    }
}

fn load(asset: *Asset) void {
    if (!initialized) @panic("Firefly module not initialized");

    var data: *SpriteSet = resources.get(asset.resource_id);
    if (Asset.byId(data.texture_asset).binding() == NO_BINDING) {
        // load dependent texture asset first
        Asset.activateById(data.texture_asset, true);
        if (Asset.byId(data.texture_asset).binding() == NO_BINDING) {
            std.log.err("Failed to load/activate dependent TextureAsset: {any}", .{Asset.byId(data.texture_asset)});
            return;
        }
    }

    const tex_binding_id = Asset.byId(data.texture_asset).binding();

    for (data.sprites) |*s| {
        s.texture_binding = tex_binding_id;
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
