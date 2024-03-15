const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;

const StringBuffer = utils.StringBuffer;
const String = utils.String;
const FFAPIError = api.FFAPIError;
const DynArray = utils.DynArray;
const BindingId = api.BindingId;
const NO_BINDING = api.NO_BINDING;
const TextureBinding = api.TextureBinding;
const TextureFilter = api.TextureFilter;
const TextureWrap = api.TextureWrap;
const RenderTextureData = api.RenderTextureData;
const ShaderData = api.ShaderData;
const TransformData = api.TransformData;
const RenderData = api.RenderData;
const SpriteData = api.SpriteData;
const PosI = utils.PosI;
const CInt = utils.CInt;
const Vector2f = utils.Vector2f;
const Projection = api.Projection;
const IRenderAPI = api.IRenderAPI;

// Singleton Debug RenderAPI
var singletonDebugRenderAPI: IRenderAPI() = undefined;
pub fn createTestRenderAPI() !IRenderAPI() {
    if (DebugRenderAPI.initialized) {
        return singletonDebugRenderAPI;
    }
    singletonDebugRenderAPI = IRenderAPI().init(DebugRenderAPI.initImpl);
    return singletonDebugRenderAPI;
}

/// This implementation of RenderAPI can be used for debugging
///
/// var render_api = RenderAPI().init(DebugRenderAPI.initImpl);
/// or
/// var render_api = RenderAPI().init(DebugRenderAPI.initScreen(800, 600).initImpl);
pub const DebugRenderAPI = struct {
    pub var screen_width: CInt = 800;
    pub var screen_height: CInt = 600;
    var initialized = false;

    const defaultOffset = Vector2f{ 0, 0 };
    const defaultRenderData = RenderData{};

    const RenderAction = struct {
        render_texture: ?BindingId = null,
        render_sprite: ?SpriteData = null,
        transform: TransformData,
        render: ?RenderData,
        offset: ?Vector2f,

        pub fn format(
            self: RenderAction,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            if (self.render_texture) |rt| {
                _ = rt;
                try writer.print(
                    "render texture {any} -->\n     {any},\n     {any},\n     offset:{any}",
                    .{ self.render_texture, self.transform, self.render, self.offset },
                );
            } else {
                try writer.print(
                    "render {any} -->\n     {any},\n     {any},\n     offset:{any}",
                    .{ self.render_sprite, self.transform, self.render, self.offset },
                );
            }
        }
    };

    var textures: DynArray(TextureBinding) = undefined;
    var renderTextures: DynArray(RenderTextureData) = undefined;
    var shaders: DynArray(ShaderData) = undefined;

    var renderActionQueue: DynArray(RenderAction) = undefined;

    var currentProjection: Projection = Projection{};
    var currentRenderTexture: ?BindingId = null;
    var currentShader: ?BindingId = null;
    var currentOffset: Vector2f = defaultOffset;
    var currentRenderData: *const RenderData = &defaultRenderData;

    fn initImpl(interface: *IRenderAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        textures = DynArray(TextureBinding).new(api.ALLOC) catch unreachable;
        renderTextures = DynArray(RenderTextureData).new(api.ALLOC) catch unreachable;
        shaders = DynArray(ShaderData).new(api.ALLOC) catch unreachable;
        renderActionQueue = DynArray(RenderAction).new(api.ALLOC) catch unreachable;

        interface.setOffset = setOffset;
        interface.addOffset = addOffset;
        interface.setBaseProjection = setBaseProjection;

        interface.loadTexture = loadTexture;
        interface.disposeTexture = disposeTexture;
        interface.createRenderTexture = createRenderTexture;
        interface.disposeRenderTexture = disposeRenderTexture;
        interface.createShader = createShader;
        interface.disposeShader = disposeShader;

        interface.startRendering = startRendering;
        interface.setActiveShader = setActiveShader;
        interface.renderTexture = renderTexture;
        interface.renderSprite = renderSprite;
        interface.endRendering = endRendering;

        interface.printDebug = printDebug;
        interface.deinit = deinit;

        DebugRenderAPI.currentRenderTexture = null;
        DebugRenderAPI.currentShader = null;
        DebugRenderAPI.currentOffset = defaultOffset;
        DebugRenderAPI.currentRenderData = &defaultRenderData;
    }

    fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        renderActionQueue.deinit();
        textures.deinit();
        renderTextures.deinit();
        shaders.deinit();
    }

    pub fn screenWidth() CInt {
        return screen_width;
    }

    pub fn screenHeight() CInt {
        return screen_height;
    }

    pub fn showFPS(pos: *PosI) void {
        std.debug.print("showFPS: {any}\n", .{pos.*});
    }

    pub fn loadTexture(
        _: String,
        _: bool,
        _: TextureFilter,
        _: TextureWrap,
    ) TextureBinding {
        var binding = TextureBinding{
            .width = 1,
            .height = 1,
        };
        binding.id = textures.add(binding);

        return binding;
    }

    pub fn disposeTexture(binding: BindingId) void {
        textures.delete(binding);
    }

    pub fn createRenderTexture(textureData: *RenderTextureData) void {
        textureData.binding = renderTextures.add(textureData.*);
        if (renderTextures.get(textureData.binding)) |tex| tex.binding = textureData.binding;
    }

    pub fn disposeRenderTexture(textureData: *RenderTextureData) void {
        if (textureData.binding != NO_BINDING) {
            renderTextures.delete(textureData.binding);
            textureData.binding = NO_BINDING;
        }
    }

    pub fn createShader(shaderData: *ShaderData) void {
        shaderData.binding = shaders.add(shaderData.*);
        if (shaders.get(shaderData.binding)) |s| s.binding = shaderData.binding;
    }

    pub fn disposeShader(shaderData: *ShaderData) void {
        if (shaderData.binding != NO_BINDING) {
            shaders.delete(shaderData.binding);
            shaderData.binding = NO_BINDING;
        }
    }

    pub fn startRendering(textureId: ?BindingId, projection: ?*const Projection) void {
        if (textureId) |id| {
            currentRenderTexture = id;
        }
        if (projection) |p| {
            currentProjection = p.*;
        } else {
            currentProjection = Projection{};
        }
    }

    pub fn setActiveShader(shaderId: BindingId) void {
        currentShader = shaderId;
    }

    pub fn setOffset(offset: Vector2f) void {
        currentOffset = offset;
    }

    pub fn addOffset(offset: Vector2f) void {
        currentOffset[0] += offset[0];
        currentOffset[1] += offset[1];
    }

    pub fn setBaseProjection(_: Projection) void {}

    pub fn renderTexture(
        textureId: BindingId,
        transform: *const TransformData,
        renderData: ?*const RenderData,
        offset: ?Vector2f,
    ) void {
        if (renderData) |rd| {
            currentRenderData = rd;
        }
        _ = renderActionQueue.add(RenderAction{
            .render_texture = textureId,
            .transform = transform.*,
            .render = if (renderData) |sd| sd.* else null,
            .offset = offset,
        });
    }

    pub fn renderSprite(
        spriteData: *const SpriteData,
        transform: *const TransformData,
        renderData: ?*const RenderData,
        offset: ?Vector2f,
    ) void {
        if (renderData) |rd| {
            currentRenderData = rd;
        }
        _ = renderActionQueue.add(RenderAction{
            .render_sprite = spriteData.*,
            .transform = transform.*,
            .render = if (renderData) |sd| sd.* else null,
            .offset = offset,
        });
    }

    pub fn endRendering() void {
        currentRenderTexture = null;
    }

    pub fn printDebug(buffer: *StringBuffer) void {
        buffer.append("\n******************************\n");
        buffer.append("Debug Rendering API State:\n");

        buffer.append(" loaded textures:\n");
        var texitr = DebugRenderAPI.textures.iterator();
        while (texitr.next()) |tex| {
            buffer.print("   {any}\n", .{tex});
        }

        buffer.append(" loaded render textures:\n");
        var rtexitr = DebugRenderAPI.renderTextures.iterator();
        while (rtexitr.next()) |tex| {
            buffer.print("   {any}\n", .{tex});
        }

        buffer.append(" loaded shaders:\n");
        var sitr = DebugRenderAPI.shaders.iterator();
        while (sitr.next()) |s| {
            buffer.print("   {any}\n", .{s});
        }

        buffer.append(" current state:\n");

        buffer.print("   {any}\n", .{DebugRenderAPI.currentProjection});
        buffer.print("   {any}\n", .{DebugRenderAPI.currentRenderTexture});
        buffer.print("   {any}\n", .{DebugRenderAPI.currentRenderData});
        buffer.print("   {any}\n", .{DebugRenderAPI.currentShader});
        buffer.print("   Offset: {any}\n", .{DebugRenderAPI.currentOffset});

        buffer.append(" render actions:\n");
        var aitr = DebugRenderAPI.renderActionQueue.iterator();
        while (aitr.next()) |a| {
            buffer.print("   {any}\n", .{a});
        }
    }
};

// //////////////////////////////////////////////////////////////
// //// TESTING RenderAPI
// //////////////////////////////////////////////////////////////

test "RenderAPI debug init" {
    try inari.firefly.initTesting();
    defer inari.firefly.deinit();

    //var t1 = TextureData{ .resource = "t1" };
    var t2 = RenderTextureData{};
    var sprite = SpriteData{};
    var transform = TransformData{};
    var renderData = RenderData{};
    transform.position[0] = 10;
    transform.position[1] = 100;

    //try std.testing.expect(t1.binding == NO_BINDING);
    var tex_1_binding = api.rendering.loadTexture("t1", false, TextureFilter.TEXTURE_FILTER_POINT, TextureWrap.TEXTURE_WRAP_CLAMP);
    try std.testing.expect(tex_1_binding != NO_BINDING);
    try std.testing.expect(t2.binding == NO_BINDING);
    api.rendering.createRenderTexture(&t2);
    try std.testing.expect(t2.binding != NO_BINDING);

    sprite.texture_binding = tex_1_binding.id;
    api.rendering.renderSprite(&sprite, &transform, &renderData, null);

    // test creating another DebugGraphics will get the same instance back
    var debugGraphics2 = try createTestRenderAPI();
    try std.testing.expectEqual(api.rendering, debugGraphics2);
    var offset = Vector2f{ 10, 10 };
    debugGraphics2.setOffset(offset);
    debugGraphics2.renderSprite(&sprite, &transform, &renderData, offset);

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    const api_out: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\   TextureData[ res:t1, bind:0, w:1, h:1, mipmap:false, wrap:-1|-1, minmag:-1|-1]
        \\ loaded render textures:
        \\   RenderTextureData[ bind:0, w:0, h:0 ]
        \\ loaded shaders:
        \\ current state:
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   null
        \\   Offset: { 1.0e+01, 1.0e+01 }
        \\ render actions:
        \\   render SpriteData[ bind:0, bounds:{ 0.0e+00, 0.0e+00, 0.0e+00, 0.0e+00 } ] -->
        \\     TransformData[ pos:{ 1.0e+01, 1.0e+02 }, pivot:{ 0.0e+00, 0.0e+00 }, scale:{ 1.0e+00, 1.0e+00 }, rot:0 ],
        \\     RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ],
        \\     offset:null
        \\   render SpriteData[ bind:0, bounds:{ 0.0e+00, 0.0e+00, 0.0e+00, 0.0e+00 } ] -->
        \\     TransformData[ pos:{ 1.0e+01, 1.0e+02 }, pivot:{ 0.0e+00, 0.0e+00 }, scale:{ 1.0e+00, 1.0e+00 }, rot:0 ],
        \\     RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ],
        \\     offset:{ 1.0e+01, 1.0e+01 }
        \\
    ;
    api.rendering.printDebug(&sb);
    //std.debug.print("\n{s}", .{sb.toString()});
    try std.testing.expectEqualStrings(api_out, sb.toString());
}

test "TransformData operations" {
    var td1 = TransformData{
        .position = Vector2f{ 10, 10 },
        .pivot = Vector2f{ 0, 0 },
        .scale = Vector2f{ 1, 1 },
        .rotation = 2,
    };
    var td2 = TransformData{
        .position = Vector2f{ 10, 10 },
        .pivot = Vector2f{ 1, 1 },
        .scale = Vector2f{ 2, 2 },
        .rotation = 5,
    };
    var td3 = TransformData{};
    td3.set(td1);

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();
    sb.print("{any}", .{td3});
    try std.testing.expectEqualStrings(
        "TransformData[ pos:{ 1.0e+01, 1.0e+01 }, pivot:{ 0.0e+00, 0.0e+00 }, scale:{ 1.0e+00, 1.0e+00 }, rot:2 ]",
        sb.toString(),
    );

    sb.clear();
    td3.add(td2);
    sb.print("{any}", .{td3});
    try std.testing.expectEqualStrings(
        "TransformData[ pos:{ 2.0e+01, 2.0e+01 }, pivot:{ 1.0e+00, 1.0e+00 }, scale:{ 3.0e+00, 3.0e+00 }, rot:7 ]",
        sb.toString(),
    );
}

// //////////////////////////////////////////////////////////////
// //// TESTING System
// //////////////////////////////////////////////////////////////

// // test "initialization" {
// //
// //     try firefly.moduleInitDebug(std.testing.allocator);
// //     defer firefly.moduleDeinit();

// //     var exampleSystem = try System.initSystem(ExampleSystem);
// //     try std.testing.expectEqualStrings("ExampleSystem", exampleSystem.getInfo().name);
// //     var systemPtr = System.getSystem("ExampleSystem").?;
// //     try std.testing.expectEqualStrings("ExampleSystem", systemPtr.getInfo().name);
// //     System.activate(ExampleSystem.info.name, false);
// // }
