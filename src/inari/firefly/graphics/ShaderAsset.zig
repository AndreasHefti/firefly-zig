const std = @import("std");
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const graphics = @import("graphics.zig");
const api = graphics.api;
const utils = graphics.utils;

const Aspect = utils.aspect.Aspect;
const Asset = api.Asset;
const DynArray = utils.dynarray.DynArray;
const StringBuffer = utils.StringBuffer;
const ShaderData = api.ShaderData;
const BindingIndex = api.BindingIndex;
const String = utils.String;
const Event = api.Component.Event;
const ActionType = api.Component.ActionType;
const TextureData = api.TextureData;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;

pub var asset_type: *Aspect = undefined;
pub const NULL_VALUE = ShaderData{};

var initialized = false;
var resources: DynArray(ShaderData) = undefined;

pub fn init() !void {
    defer initialized = true;
    if (initialized) return;

    asset_type = Asset.ASSET_TYPE_ASPECT_GROUP.getAspect("Shader");
    resources = try DynArray(ShaderData).init(api.COMPONENT_ALLOC, NULL_VALUE);
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

pub const Shader = struct {
    asset_name: String = NO_NAME,
    vertex_shader_resource: String = NO_NAME,
    fragment_shader_resource: String = NO_NAME,
    file_resource: bool = true,
};

pub fn new(data: Shader) *Asset {
    if (!initialized)
        @panic("Firefly module not initialized");

    return Asset.new(Asset{
        .asset_type = asset_type,
        .name = data.asset_name,
        .resource_id = resources.add(ShaderData{
            .vertex_shader_resource = data.vertex_shader_resource,
            .fragment_shader_resource = data.fragment_shader_resource,
            .file_resource = data.file_resource,
        }),
    });
}

pub fn getResource(res_id: Index) *const ShaderData {
    return resources.get(res_id);
}

pub fn getResourceForIndex(res_id: Index, _: Index) *const ShaderData {
    return resources.get(res_id);
}

pub fn getResourceForName(res_id: Index, _: String) *const ShaderData {
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

    var shaderData: *ShaderData = resources.get(asset.resource_id);
    if (shaderData.binding != NO_BINDING)
        return; // already loaded

    api.RENDERING_API.createShader(shaderData) catch {
        std.log.err("Failed to load shader: {any}", .{shaderData});
    };
}

fn unload(asset: *Asset) void {
    if (!initialized)
        return;

    var shaderData: *ShaderData = resources.get(asset.resource_id);
    api.RENDERING_API.disposeShader(shaderData) catch {
        std.log.err("Failed to dispose shader: {any}", .{shaderData});
    };
}

fn delete(asset: *Asset) void {
    Asset.activateById(asset.id, false);
    resources.reset(asset.resource_id);
}

//////////////////////////////////////////////////////////////
//// TESTING
//////////////////////////////////////////////////////////////
test "ShaderAsset load/unload" {
    try graphics.init(std.testing.allocator, std.testing.allocator, std.testing.allocator);
    defer graphics.deinit();

    var shader_asset: *Asset = new(Shader{
        .asset_name = "Shader123",
        .vertex_shader_resource = "/vertex_shader.glsl",
        .fragment_shader_resource = "/fragment_shader.glsl",
        .file_resource = true,
    });

    try std.testing.expect(shader_asset.id != UNDEF_INDEX);
    try std.testing.expect(shader_asset.asset_type.index == asset_type.index);
    try std.testing.expect(shader_asset.resource_id != UNDEF_INDEX);
    try std.testing.expectEqualStrings("Shader123", shader_asset.name);

    var res: *ShaderData = resources.get(shader_asset.resource_id);
    try std.testing.expectEqualStrings("/vertex_shader.glsl", res.vertex_shader_resource);
    try std.testing.expectEqualStrings("/fragment_shader.glsl", res.fragment_shader_resource);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded yet
    try std.testing.expect(shader_asset.getResource(@This()).binding == NO_BINDING);

    // load the texture... by name
    Asset.activateByName("Shader123", true);
    try std.testing.expect(res.binding == 0); // now loaded
    try std.testing.expect(shader_asset.getResource(@This()).binding == 0);

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    api.rendering_api.DebugRenderAPI.printDebugRendering(&sb);
    std.debug.print("\n{s}", .{sb.toString()});
    const render_state1: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\ loaded render textures:
        \\ loaded shaders:
        \\   ShaderData[ binding:0, vert:/vertex_shader.glsl, frag:/fragment_shader.glsl, file_resource:true ]
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
    Asset.activateByName("Shader123", false);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded

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
