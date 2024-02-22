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
const BindingId = api.BindingId;
const String = utils.String;
const Event = api.Component.Event;
const ActionType = api.Component.ActionType;
const TextureAsset = graphics.TextureAsset;
const ShaderAsset = graphics.ShaderAsset;
const TextureData = api.TextureData;
const Shader = ShaderAsset.Shader;
const ShaderData = api.ShaderData;
const Texture = TextureAsset.Texture;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;
const CInt = utils.CInt;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// TESTING Texture Asset
//////////////////////////////////////////////////////////////

test "TextureAsset init/deinit" {
    try graphics.initTesting();
    defer graphics.deinit();

    try std.testing.expectEqual(
        @as(String, "Texture"),
        TextureAsset.asset_type.name,
    );
    try std.testing.expect(TextureAsset.resourceSize() == 0);
}

test "TextureAsset load/unload" {
    try graphics.initTesting();
    defer graphics.deinit();

    var texture_asset: *Asset = TextureAsset.new(Texture{
        .name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    try std.testing.expect(texture_asset.id != UNDEF_INDEX);
    try std.testing.expect(texture_asset.asset_type.index == TextureAsset.asset_type.index);
    try std.testing.expect(texture_asset.resource_id != UNDEF_INDEX);
    try std.testing.expectEqualStrings("TestTexture", texture_asset.name);

    var res: *const TextureData = TextureAsset.getResource(texture_asset.resource_id);
    try std.testing.expectEqualStrings("path/TestTexture", res.resource);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded yet
    try std.testing.expect(texture_asset.getResource(TextureAsset).binding == NO_BINDING);

    // load the texture... by name
    Asset.activateByName("TestTexture", true);
    try std.testing.expect(res.binding == 0); // now loaded
    try std.testing.expect(texture_asset.getResource(TextureAsset).binding == 0);

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

    api.RENDERING_API.printDebug(&sb);
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
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   null
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
    api.RENDERING_API.printDebug(&sb);
    const render_state2: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\ loaded render textures:
        \\ loaded shaders:
        \\ current state:
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state2, sb.toString());
}

test "TextureAsset dispose" {
    try graphics.initTesting();
    defer graphics.deinit();

    var texture_asset: *Asset = TextureAsset.new(Texture{
        .name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    Asset.activateByName("TestTexture", true);

    var res: *const TextureData = TextureAsset.getResource(texture_asset.resource_id);
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
    try graphics.initTesting();
    defer graphics.deinit();

    var texture_asset: *Asset = TextureAsset.new(Texture{
        .name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    // this shall get the NULL_VALUE since the asset is not loaded yet
    var res = texture_asset.getResource(TextureAsset);
    try std.testing.expect(res.binding == NO_BINDING);
    // this is not possible at compile time: error: cannot assign to constant
    //res.binding = 1;
}

//////////////////////////////////////////////////////////////
//// TESTING ShaderAsset
//////////////////////////////////////////////////////////////
test "ShaderAsset load/unload" {
    try graphics.initTesting();
    defer graphics.deinit();

    var shader_asset: *Asset = ShaderAsset.new(.{
        .asset_name = "Shader123",
        .vertex_shader_resource = "/vertex_shader.glsl",
        .fragment_shader_resource = "/fragment_shader.glsl",
        .file_resource = true,
    });

    try std.testing.expect(shader_asset.id != UNDEF_INDEX);
    try std.testing.expect(shader_asset.asset_type.index == ShaderAsset.asset_type.index);
    try std.testing.expect(shader_asset.resource_id != UNDEF_INDEX);
    try std.testing.expectEqualStrings("Shader123", shader_asset.name);

    var res: *const ShaderData = ShaderAsset.getResource(shader_asset.resource_id);
    try std.testing.expectEqualStrings("/vertex_shader.glsl", res.vertex_shader_resource);
    try std.testing.expectEqualStrings("/fragment_shader.glsl", res.fragment_shader_resource);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded yet
    try std.testing.expect(shader_asset.getResource(ShaderAsset).binding == NO_BINDING);

    // load the texture... by name
    Asset.activateByName("Shader123", true);
    try std.testing.expect(res.binding == 0); // now loaded
    try std.testing.expect(shader_asset.getResource(ShaderAsset).binding == 0);

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    api.RENDERING_API.printDebug(&sb);
    //std.debug.print("\n{s}", .{sb.toString()});
    const render_state1: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\ loaded render textures:
        \\ loaded shaders:
        \\   ShaderData[ binding:0, vert:/vertex_shader.glsl, frag:/fragment_shader.glsl, file_resource:true ]
        \\ current state:
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state1, sb.toString());

    // dispose texture
    Asset.activateByName("Shader123", false);
    try std.testing.expect(res.binding == NO_BINDING); // not loaded

    sb.clear();
    api.RENDERING_API.printDebug(&sb);
    const render_state2: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\ loaded render textures:
        \\ loaded shaders:
        \\ current state:
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state2, sb.toString());
}
