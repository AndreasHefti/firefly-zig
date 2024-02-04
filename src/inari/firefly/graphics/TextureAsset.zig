const std = @import("std");
const assert = std.debug.assert;

const graphics = @import("graphics.zig");
const api = graphics.api;
const utils = graphics.utils;

const Aspect = utils.aspect.Aspect;
const Asset = api.Asset;
const DynArray = utils.dynarray.DynArray;
const StringBuffer = utils.StringBuffer;
const SpriteData = api.SpriteData;
const BindingIndex = api.BindingIndex;
const String = utils.String;
const Event = api.Component.Event;
const ActionType = api.Component.ActionType;
const TextureData = api.TextureData;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;
const CInt = utils.CInt;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;

var initialized = false;
var resources: DynArray(TextureData) = undefined;

pub var asset_type: *Aspect = undefined;
pub const NULL_VALUE = TextureData{};

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Texture");
    resources = try DynArray(TextureData).init(api.COMPONENT_ALLOC, NULL_VALUE);
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

pub fn getResource(res_id: Index) *const TextureData {
    return resources.get(res_id);
}

pub fn getResourceForIndex(res_id: Index, _: Index) *const TextureData {
    return resources.get(res_id);
}

pub fn getResourceForName(res_id: Index, _: String) *const TextureData {
    return resources.get(res_id);
}

fn listener(e: Event) void {
    var asset: *Asset = Asset.pool.get(e.c_id);
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
    if (!initialized)
        return;

    var tex_data = resources.get(asset.resource_id);
    if (tex_data.binding != NO_BINDING)
        return; // already loaded

    api.RENDERING_API.loadTexture(tex_data) catch {
        std.log.err("Failed to load texture resource: {s}", .{tex_data.resource});
    };
}

fn unload(asset: *Asset) void {
    if (!initialized)
        return;

    if (asset.resource_id == UNDEF_INDEX)
        return;

    var tex_data: *TextureData = resources.get(asset.resource_id);
    if (tex_data.binding == NO_BINDING)
        return; // already disposed

    api.RENDERING_API.disposeTexture(tex_data) catch {
        std.log.err("Failed to dispose texture resource: {s}", .{tex_data.resource});
        return;
    };

    assert(tex_data.binding == NO_BINDING);
    assert(tex_data.width == -1);
    assert(tex_data.height == -1);
}

fn delete(asset: *Asset) void {
    Asset.activateById(asset.id, false);
    resources.reset(asset.resource_id);
}

//////////////////////////////////////////////////////////////
//// TESTING
//////////////////////////////////////////////////////////////

test "TextureAsset init/deinit" {
    try graphics.init(std.testing.allocator, std.testing.allocator, std.testing.allocator);
    defer graphics.deinit();

    try std.testing.expectEqual(@as(String, "Texture"), asset_type.name);
    try std.testing.expect(resources.size() == 0);
}

test "TextureAsset load/unload" {
    try graphics.init(std.testing.allocator, std.testing.allocator, std.testing.allocator);
    defer graphics.deinit();

    var texture_asset: *Asset = new(Texture{
        .asset_name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    try std.testing.expect(texture_asset.id != UNDEF_INDEX);
    try std.testing.expect(texture_asset.asset_type.index == asset_type.index);
    try std.testing.expect(texture_asset.resource_id != UNDEF_INDEX);
    try std.testing.expectEqualStrings("TestTexture", texture_asset.name);

    var res: *TextureData = resources.get(texture_asset.resource_id);
    try std.testing.expectEqualStrings("path/TestTexture", res.resource);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded yet
    try std.testing.expect(texture_asset.getResource(@This()).binding == NO_BINDING);

    // load the texture... by name
    Asset.activateByName("TestTexture", true);
    try std.testing.expect(res.binding == 0); // now loaded
    try std.testing.expect(texture_asset.getResource(@This()).binding == 0);

    try std.testing.expect(res.width > 0);
    try std.testing.expect(res.height > 0);
    // dispose texture
    Asset.activateByName("TestTexture", false);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded
    try std.testing.expect(res.width == -1);
    try std.testing.expect(res.height == -1);

    // load the texture... by id
    Asset.activateById(texture_asset.id, true);
    try std.testing.expect(res.binding == 0); // now loaded
    try std.testing.expect(res.width > 0);
    try std.testing.expect(res.height > 0);

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    api.rendering_api.DebugRenderAPI.printDebugRendering(&sb);
    //std.debug.print("\n{s}", .{sb.toString()});
    const render_state1: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\   TextureData[ res:path/TestTexture, bind:0, w:1, h:1, mipmap:false, wrap:-1|-1, minmag:-1|-1]
        \\ loaded render textures:
        \\ loaded shaders:
        \\ current state:
        \\   RenderTexture: null
        \\   RenderData: RenderData[ clear:true, ccolor:{ 0, 0, 0, 255 }, tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   Shader: null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state1, sb.toString());

    // dispose texture
    Asset.activateById(texture_asset.id, false);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded
    try std.testing.expect(res.width == -1);
    try std.testing.expect(res.height == -1);

    sb.clear();
    api.rendering_api.DebugRenderAPI.printDebugRendering(&sb);
    const render_state2: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\ loaded render textures:
        \\ loaded shaders:
        \\ current state:
        \\   RenderTexture: null
        \\   RenderData: RenderData[ clear:true, ccolor:{ 0, 0, 0, 255 }, tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   Shader: null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state2, sb.toString());
}

test "TextureAsset dispose" {
    try graphics.init(std.testing.allocator, std.testing.allocator, std.testing.allocator);
    defer graphics.deinit();

    var texture_asset: *Asset = new(Texture{
        .asset_name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    Asset.activateByName("TestTexture", true);

    var res: *TextureData = resources.get(texture_asset.resource_id);
    try std.testing.expectEqualStrings("path/TestTexture", res.resource);
    try std.testing.expect(res.binding != NO_BINDING); //  loaded yet

    // should also deactivate first
    Asset.disposeByName("TestTexture");

    try std.testing.expect(res.binding == NO_BINDING); // not loaded yet
    // asset ref has been reset
    try std.testing.expect(texture_asset.id == UNDEF_INDEX);
    try std.testing.expectEqualStrings(texture_asset.name, NO_NAME);
}

test "get resources is const" {
    try graphics.init(std.testing.allocator, std.testing.allocator, std.testing.allocator);
    defer graphics.deinit();

    var texture_asset: *Asset = new(Texture{
        .asset_name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    // this shall get the NULL_VALUE since the asset is not loaded yet
    var res = texture_asset.getResource(@This());
    try std.testing.expect(res.binding == NO_BINDING);
    // this is not possible at compile time: error: cannot assign to constant
    //res.binding = 1;
}
