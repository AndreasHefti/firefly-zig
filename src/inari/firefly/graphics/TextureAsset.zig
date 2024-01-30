const std = @import("std");
const firefly = @import("../firefly.zig"); // TODO better way for import package?
const assert = std.debug.assert;
const DynArray = firefly.utils.dynarray.DynArray;
const api = firefly.api;
const Aspect = firefly.utils.aspect.Aspect;
const Asset = firefly.Asset;
const TextureData = api.TextureData;
const String = firefly.utils.String;
const NO_NAME = firefly.utils.NO_NAME;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_BINDING = firefly.api.NO_BINDING;
const BindingIndex = firefly.api.BindingIndex;
const CInt = firefly.utils.CInt;
const Event = api.component.Event;
const ActionType = api.component.ActionType;

var initialized = false;
var resources: DynArray(TextureData) = undefined;

pub var asset_type: *Aspect = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Texture");
    resources = try DynArray(TextureData).init(firefly.COMPONENT_ALLOC, TextureData{});
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

pub const Texture = struct {
    asset_name: String = NO_NAME,
    resource_path: String,
    is_mipmap: bool = false,
    s_wrap: CInt = -1,
    t_wrap: CInt = -1,
    min_filter: CInt = -1,
    mag_filter: CInt = -1,
};

pub fn new(data: Texture) *Asset {
    if (!initialized) @panic("Firefly module not initialized");

    return Asset.new(Asset{
        .asset_type = asset_type,
        .name = data.asset_name,
        .binding_by_index = bindingByAsset,
        .binding_by_name = bindingByName,
        .resource_id = resources.add(
            TextureData{
                .resource = data.resource_path,
                .is_mipmap = data.is_mipmap,
                .s_wrap = data.s_wrap,
                .t_wrap = data.t_wrap,
                .min_filter = data.min_filter,
                .mag_filter = data.mag_filter,
            },
        ),
    });
}

pub fn get(binding: BindingIndex) *TextureData {
    return resources.register.get(binding);
}

pub fn bindingByAsset(asset: *Asset, _: usize) BindingIndex {
    return resources.register.get(asset.resource_id).binding;
}

pub fn bindingByName(asset: *Asset, _: String) BindingIndex {
    return resources.register.get(asset.resource_id).binding;
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

    var tex_data = resources.get(asset.resource_id);
    if (tex_data.binding != NO_BINDING) return; // already loaded

    firefly.RENDER_API.loadTexture(tex_data) catch {
        std.log.err("Failed to load texture resource: {s}", .{tex_data.resource});
    };
}

fn unload(asset: *Asset) void {
    if (!initialized) @panic("Firefly module not initialized");

    if (asset.resource_id == UNDEF_INDEX) return;
    var tex_data: *TextureData = resources.get(asset.resource_id);
    if (tex_data.binding == NO_BINDING) return;

    firefly.RENDER_API.disposeTexture(tex_data) catch {
        std.log.err("Failed to dispose texture resource: {s}", .{tex_data.resource});
        return;
    };

    assert(tex_data.binding == NO_BINDING);
    assert(tex_data.width == -1);
    assert(tex_data.height == -1);
}

fn delete(asset: *Asset) void {
    Asset.activateById(asset.index, false);
    resources.reset(asset.resource_id);
}

test "TextureAsset init/deinit" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();

    try std.testing.expectEqual(@as(String, "Texture"), asset_type.name);
    try std.testing.expect(resources.size() == 0);
}

test "TextureAsset load/unload" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();

    var texture_asset: *Asset = new(Texture{
        .asset_name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    try std.testing.expect(texture_asset.index != UNDEF_INDEX);
    try std.testing.expect(texture_asset.asset_type.index == asset_type.index);
    try std.testing.expect(texture_asset.resource_id != UNDEF_INDEX);
    try std.testing.expectEqualStrings("TestTexture", texture_asset.name);

    var res: *TextureData = resources.get(texture_asset.resource_id);
    try std.testing.expectEqualStrings("path/TestTexture", res.resource);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded yet
    try std.testing.expect(texture_asset.binding() == NO_BINDING);

    // load the texture... by name
    Asset.activateByName("TestTexture", true);
    try std.testing.expect(res.binding == 0); // now loaded
    try std.testing.expect(texture_asset.binding() == 0);
    try std.testing.expect(res.width > 0);
    try std.testing.expect(res.height > 0);
    // dispose texture
    Asset.activateByName("TestTexture", false);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded
    try std.testing.expect(res.width == -1);
    try std.testing.expect(res.height == -1);

    // load the texture... by id
    Asset.activateById(texture_asset.index, true);
    try std.testing.expect(res.binding == 0); // now loaded
    try std.testing.expect(res.width > 0);
    try std.testing.expect(res.height > 0);
    // dispose texture
    Asset.activateById(texture_asset.index, false);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded
    try std.testing.expect(res.width == -1);
    try std.testing.expect(res.height == -1);
}

test "TextureAsset dispose" {
    try firefly.moduleInitDebug(std.testing.allocator);
    defer firefly.moduleDeinit();

    var texture_asset: *Asset = new(Texture{
        .asset_name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    Asset.activateByName("TestTexture", true);

    var res: *TextureData = resources.get(texture_asset.resource_id);
    try std.testing.expectEqualStrings("path/TestTexture", res.resource);
    try std.testing.expect(res.binding != NO_BINDING); //  loaded yet
    try std.testing.expect(texture_asset.binding() != NO_BINDING);

    // should also deactivate first
    Asset.disposeByName("TestTexture");

    try std.testing.expect(res.binding == NO_BINDING); // not loaded yet
    // asset ref has been reset
    try std.testing.expect(texture_asset.index == UNDEF_INDEX);
    try std.testing.expectEqualStrings(texture_asset.name, NO_NAME);
}
