const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const graphics = inari.firefly.graphics;

const Aspect = utils.aspect.Aspect;
const Asset = api.Asset;
const DynArray = utils.dynarray.DynArray;
const StringBuffer = utils.StringBuffer;
const SpriteData = api.SpriteData;
const BindingId = api.BindingId;
const String = utils.String;
const Event = api.Component.Event;
const ActionType = api.Component.ActionType;
const Texture = graphics.Texture;
const TextureData = api.TextureData;
const Shader = graphics.Shader;
const RectF = utils.geom.RectF;
const Vec2f = utils.geom.Vector2f;
const CInt = utils.CInt;

const NO_NAME = utils.NO_NAME;
const NO_BINDING = api.NO_BINDING;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// TESTING Texture Asset
//////////////////////////////////////////////////////////////

test "TextureAsset init/deinit" {
    try inari.firefly.initTesting();
    defer inari.firefly.deinit();

    try std.testing.expectEqual(
        @as(String, "Texture"),
        Texture.aspect.name,
    );
    //try std.testing.expect(TextureAsset.resourceSize() == 0);
}

test "TextureAsset load/unload" {
    try inari.firefly.initTesting();
    defer inari.firefly.deinit();

    var texture_asset: *Asset(Texture) = Texture.newAnd(.{
        .name = "TestTexture",
        .resource = "path/TestTexture",
        .is_mipmap = false,
    });

    try std.testing.expect(texture_asset.id != UNDEF_INDEX);
    try std.testing.expect(texture_asset.getAssetType().id == Texture.aspect.id);
    try std.testing.expect(texture_asset.resource_id != UNDEF_INDEX);
    try std.testing.expectEqualStrings("TestTexture", texture_asset.name.?);

    var res: ?*Texture = texture_asset.getResource();
    try std.testing.expect(res != null);
    try std.testing.expectEqualStrings("path/TestTexture", res.?.resource);
    try std.testing.expect(res.?.binding == null);

    // load the texture... by name
    _ = Texture.loadByName("TestTexture");
    try std.testing.expect(res.?.binding != null);
    try std.testing.expect(res.?.binding.?.id == 0); // now loaded
    try std.testing.expect(res.?.binding.?.width > 0);
    try std.testing.expect(res.?.binding.?.height > 0);

    // dispose texture
    Texture.unloadByName("TestTexture");
    try std.testing.expect(res.?.binding == null); // not loaded

    // load the texture... by id
    _ = Texture.loadById(texture_asset.id);
    try std.testing.expect(res.?.binding != null); // now loaded
    try std.testing.expect(res.?.binding.?.id == 0); // now loaded
    try std.testing.expect(res.?.binding.?.width > 0);
    try std.testing.expect(res.?.binding.?.height > 0);

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    api.rendering.printDebug(&sb);
    //std.debug.print("\n{s}", .{sb.toString()});
    const render_state1: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\   TextureBinding[ id:0, width:1, height:1 ]
        \\ loaded render textures:
        \\ loaded shaders:
        \\ current state:
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state1, sb.toString());

    // dispose texture
    Texture.unloadById(texture_asset.id);
    try std.testing.expect(res.?.binding == null); // not loaded

    sb.clear();
    api.rendering.printDebug(&sb);
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
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state2, sb.toString());
}

test "TextureAsset dispose" {
    try inari.firefly.initTesting();
    defer inari.firefly.deinit();

    var texture_asset: *Asset(Texture) = Texture.newAnd(.{
        .name = "TestTexture",
        .resource = "path/TestTexture",
        .is_mipmap = false,
    });

    _ = Texture.loadByName("TestTexture");
    var res: ?*Texture = texture_asset.getResource();
    try std.testing.expect(res != null);
    try std.testing.expectEqualStrings("path/TestTexture", res.?.resource);
    try std.testing.expect(res.?.binding != null); //  loaded yet
    try std.testing.expect(res.?.binding.?.id != NO_BINDING); //  loaded yet

    // should also deactivate first
    Texture.disposeByName("TestTexture");

    try std.testing.expect(res.?.binding == null); // not loaded yet
    // asset ref has been reset
    try std.testing.expect(texture_asset.id == UNDEF_INDEX);
    try std.testing.expect(texture_asset.name == null);
}

//////////////////////////////////////////////////////////////
//// TESTING ShaderAsset
//////////////////////////////////////////////////////////////
test "ShaderAsset load/unload" {
    try inari.firefly.initTesting();
    defer inari.firefly.deinit();

    var shader_asset: *Asset(Shader) = Shader.newAnd(.{
        .name = "Shader123",
        .vertex_shader_resource = "/vertex_shader.glsl",
        .fragment_shader_resource = "/fragment_shader.glsl",
        .file_resource = true,
    });

    try std.testing.expect(shader_asset.id != UNDEF_INDEX);
    try std.testing.expect(shader_asset.resource_id != UNDEF_INDEX);
    try std.testing.expectEqualStrings("Shader123", shader_asset.name.?);

    var res: *Shader = Shader.getResourceById(shader_asset.resource_id).?;
    try std.testing.expectEqualStrings("/vertex_shader.glsl", res.vertex_shader_resource.?);
    try std.testing.expectEqualStrings("/fragment_shader.glsl", res.fragment_shader_resource.?);
    try std.testing.expect(res.binding == null); // not loaded yet

    // load the texture... by name
    _ = Shader.loadByName("Shader123");
    try std.testing.expect(res.binding != null); // now loaded

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    api.rendering.printDebug(&sb);
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
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state1, sb.toString());

    // dispose texture
    Shader.unloadByName("Shader123");
    try std.testing.expect(res.binding == null); // not loaded

    sb.clear();
    api.rendering.printDebug(&sb);
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
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    try std.testing.expectEqualStrings(render_state2, sb.toString());
}
