const std = @import("std");
const api = @import("api.zig");

const utils = api.utils;
const StringBuffer = utils.StringBuffer;
const String = utils.String;
const FFAPIError = api.FFAPIError;
const DynArray = utils.dynarray.DynArray;
const BindingIndex = api.BindingIndex;
const NO_BINDING = api.NO_BINDING;
const BlendMode = api.BlendMode;
const ViewData = api.ViewData;
const TextureData = api.TextureData;
const RenderTextureData = api.RenderTextureData;
const ShaderData = api.ShaderData;
const TransformData = api.TransformData;
const RenderData = api.RenderData;
const SpriteData = api.SpriteData;
const PosI = utils.geom.PosI;
const CInt = utils.CInt;
const Vector2f = utils.geom.Vector2f;

pub fn RenderAPI() type {
    return struct {
        const Self = @This();
        /// return the actual screen width
        screenWidth: *const fn () CInt = undefined,
        /// return the actual screen height
        screenHeight: *const fn () CInt = undefined,
        /// Show actual frame rate per second at given position on the screen
        showFPS: *const fn (*PosI) void = undefined,

        /// Loads image data from file system and create new texture data loaded into GPU
        /// @param textureData The texture DAO. Sets binding, width and height to the DAO
        loadTexture: *const fn (*TextureData) FFAPIError!void = undefined,
        /// Disposes the texture with given texture binding id from GPU memory
        /// @param textureId binding identifier of the texture to dispose.
        disposeTexture: *const fn (*TextureData) FFAPIError!void = undefined,

        createRenderTexture: *const fn (*RenderTextureData) FFAPIError!void = undefined,
        disposeRenderTexture: *const fn (*RenderTextureData) FFAPIError!void = undefined,
        /// create new shader from given shader data and load it to GPU
        createShader: *const fn (*ShaderData) FFAPIError!void = undefined,
        /// Dispose the shader with the given binding identifier (shaderId) from GPU
        /// @param shaderId identifier of the shader to dispose.
        disposeShader: *const fn (*ShaderData) FFAPIError!void = undefined,

        /// Start rendering to the given RenderTextureData or to the screen if no binding index is given
        /// Use given render data as default rendering attributes
        startRendering: *const fn (?BindingIndex) void = undefined,
        /// Set the active sprite rendering shader. Note that the shader program must have been created before with createShader.
        /// @param shaderId The instance identifier of the shader.
        setActiveShader: *const fn (BindingIndex) FFAPIError!void = undefined,
        /// This renders a given RenderTextureData (BindingIndex) to the actual render target that can be
        /// rendering texture or the screen
        renderTexture: *const fn (BindingIndex, *const TransformData, ?*const RenderData, ?*const Vector2f) void = undefined,
        // TODO
        renderSprite: *const fn (*const SpriteData, *const TransformData, ?*const RenderData, ?*const Vector2f) void = undefined,
        /// This is called form the firefly API to notify the end of rendering for the actual render target (RenderTextureData).
        endRendering: *const fn () void = undefined,

        deinit: *const fn () void = undefined,

        pub fn init(
            initImpl: *const fn (*RenderAPI(), std.mem.Allocator) anyerror!void,
            allocator: std.mem.Allocator,
        ) !Self {
            var self = Self{};
            _ = try initImpl(&self, allocator);
            return self;
        }
    };
}

//////////////////////////////////////////////////////////////
//// TESTING
//////////////////////////////////////////////////////////////

// Singleton Debug RenderAPI
var singletonDebugRenderAPI: RenderAPI() = undefined;
pub fn createDebugRenderAPI(allocator: std.mem.Allocator) !RenderAPI() {
    if (DebugRenderAPI.initialized) {
        return singletonDebugRenderAPI;
    }
    singletonDebugRenderAPI = try RenderAPI().init(DebugRenderAPI.initImpl, allocator);
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
    var alloc: std.mem.Allocator = undefined;
    var initialized = false;

    const defaultOffset = Vector2f{ 0, 0 };
    const defaultRenderData = RenderData{};

    const RenderAction = struct {
        render_texture: ?BindingIndex = null,
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

    var textures: DynArray(TextureData) = undefined;
    var renderTextures: DynArray(RenderTextureData) = undefined;
    var shaders: DynArray(ShaderData) = undefined;

    var renderActionQueue: DynArray(RenderAction) = undefined;

    var currentRenderTexture: ?BindingIndex = null;
    var currentShader: ?BindingIndex = null;
    var currentOffset: *const Vector2f = &defaultOffset;
    var currentRenderData: *const RenderData = &defaultRenderData;

    fn initImpl(interface: *RenderAPI(), allocator: std.mem.Allocator) !void {
        alloc = allocator;
        textures = try DynArray(TextureData).init(allocator, null);
        renderTextures = try DynArray(RenderTextureData).init(allocator, null);
        shaders = try DynArray(ShaderData).init(allocator, null);
        renderActionQueue = try DynArray(RenderAction).init(allocator, null);

        interface.deinit = deinit;

        interface.screenWidth = screenWidth;
        interface.screenHeight = screenHeight;
        interface.showFPS = showFPS;

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

        DebugRenderAPI.currentRenderTexture = null;
        DebugRenderAPI.currentShader = null;
        DebugRenderAPI.currentOffset = &defaultOffset;
        DebugRenderAPI.currentRenderData = &defaultRenderData;

        initialized = true;
    }

    fn deinit() void {
        renderActionQueue.deinit();
        textures.deinit();
        renderTextures.deinit();
        shaders.deinit();
        initialized = false;
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

    pub fn loadTexture(textureData: *TextureData) FFAPIError!void {
        textureData.width = 1;
        textureData.height = 1;
        textureData.binding = textures.add(textureData.*);
        textures.get(textureData.binding).binding = textureData.binding;
    }

    pub fn disposeTexture(textureData: *TextureData) FFAPIError!void {
        if (textureData.binding != NO_BINDING) {
            textures.reset(textureData.binding);
            textureData.binding = NO_BINDING;
            textureData.width = -1;
            textureData.height = -1;
        }
    }

    pub fn createRenderTexture(textureData: *RenderTextureData) FFAPIError!void {
        textureData.binding = renderTextures.add(textureData.*);
        renderTextures.get(textureData.binding).binding = textureData.binding;
    }

    pub fn disposeRenderTexture(textureData: *RenderTextureData) FFAPIError!void {
        if (textureData.binding != NO_BINDING) {
            renderTextures.reset(textureData.binding);
            textureData.binding = NO_BINDING;
        }
    }

    pub fn createShader(shaderData: *ShaderData) FFAPIError!void {
        shaderData.binding = shaders.add(shaderData.*);
        shaders.get(shaderData.binding).binding = shaderData.binding;
    }

    pub fn disposeShader(shaderData: *ShaderData) FFAPIError!void {
        if (shaderData.binding != NO_BINDING) {
            shaders.reset(shaderData.binding);
            shaderData.binding = NO_BINDING;
        }
    }

    pub fn startRendering(textureId: ?BindingIndex) void {
        if (textureId) |id| {
            currentRenderTexture = id;
        }
    }

    pub fn setActiveShader(shaderId: BindingIndex) FFAPIError!void {
        currentShader = shaderId;
    }

    pub fn renderTexture(
        textureId: BindingIndex,
        transform: *const TransformData,
        renderData: ?*const RenderData,
        offset: ?*const Vector2f,
    ) void {
        if (renderData) |rd| {
            currentRenderData = rd;
        }
        if (offset) |o| {
            currentOffset = o;
        }
        _ = renderActionQueue.add(RenderAction{
            .render_texture = textureId,
            .transform = transform.*,
            .render = if (renderData) |sd| sd.* else null,
            .offset = if (offset) |sd| sd.* else null,
        });
    }

    pub fn renderSprite(
        spriteData: *const SpriteData,
        transform: *const TransformData,
        renderData: ?*const RenderData,
        offset: ?*const Vector2f,
    ) void {
        if (renderData) |rd| {
            currentRenderData = rd;
        }
        if (offset) |o| {
            currentOffset = o;
        }
        _ = renderActionQueue.add(RenderAction{
            .render_sprite = spriteData.*,
            .transform = transform.*,
            .render = if (renderData) |sd| sd.* else null,
            .offset = if (offset) |sd| sd.* else null,
        });
    }

    pub fn endRendering() void {
        currentRenderTexture = null;
    }

    pub fn printDebugRendering(buffer: *StringBuffer) void {
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
        buffer.print("   RenderTexture: {any}\n", .{DebugRenderAPI.currentRenderTexture});
        buffer.print("   RenderData: {any}\n", .{DebugRenderAPI.currentRenderData});
        buffer.print("   Shader: {any}\n", .{DebugRenderAPI.currentShader});
        buffer.print("   Offset: {any}\n", .{DebugRenderAPI.currentOffset.*});

        buffer.append(" render actions:\n");
        var aitr = DebugRenderAPI.renderActionQueue.iterator();
        while (aitr.next()) |a| {
            buffer.print("   {any}\n", .{a});
        }
    }
};

test "debug init" {
    try api.init(std.testing.allocator, std.testing.allocator, std.testing.allocator);
    defer api.deinit();

    var width = api.RENDERING_API.screenWidth();
    var height = api.RENDERING_API.screenHeight();

    try std.testing.expect(width == 800);
    try std.testing.expect(height == 600);

    var fpsPos = PosI{ 10, 10 };

    api.RENDERING_API.showFPS(&fpsPos);

    var t1 = TextureData{ .resource = "t1" };
    var t2 = RenderTextureData{};
    var sprite = SpriteData{};
    var transform = TransformData{};
    var renderData = RenderData{};
    transform.position[0] = 10;
    transform.position[1] = 100;

    try std.testing.expect(t1.binding == NO_BINDING);
    try api.RENDERING_API.loadTexture(&t1);
    try std.testing.expect(t1.binding != NO_BINDING);
    try std.testing.expect(t2.binding == NO_BINDING);
    try api.RENDERING_API.createRenderTexture(&t2);
    try std.testing.expect(t2.binding != NO_BINDING);

    sprite.texture_binding = t1.binding;
    api.RENDERING_API.renderSprite(&sprite, &transform, &renderData, null);

    // test creating another DebugGraphics will get the same instance back
    var debugGraphics2 = try createDebugRenderAPI(std.testing.allocator);
    try std.testing.expectEqual(api.RENDERING_API, debugGraphics2);
    var offset = Vector2f{ 10, 10 };
    debugGraphics2.renderSprite(&sprite, &transform, &renderData, &offset);

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    const api_out: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\   TextureData[ res:t1, bind:0, w:1, h:1, mipmap:false, wrap:-1|-1, minmag:-1|-1]
        \\ loaded render textures:
        \\   RenderTextureData[ bind:0, w:0, h:0, fbo:1 ]
        \\ loaded shaders:
        \\ current state:
        \\   RenderTexture: null
        \\   RenderData: RenderData[ clear:true, ccolor:{ 0, 0, 0, 255 }, tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   Shader: null
        \\   Offset: { 1.0e+01, 1.0e+01 }
        \\ render actions:
        \\   render SpriteData[ bind:0, bounds:{ 0.0e+00, 0.0e+00, 0.0e+00, 0.0e+00 } ] -->
        \\     TransformData[ pos:{ 1.0e+01, 1.0e+02 }, pivot:{ 0.0e+00, 0.0e+00 }, scale:{ 1.0e+00, 1.0e+00 }, rot:0 ],
        \\     RenderData[ clear:true, ccolor:{ 0, 0, 0, 255 }, tint:{ 255, 255, 255, 255 }, blend:ALPHA ],
        \\     offset:null
        \\   render SpriteData[ bind:0, bounds:{ 0.0e+00, 0.0e+00, 0.0e+00, 0.0e+00 } ] -->
        \\     TransformData[ pos:{ 1.0e+01, 1.0e+02 }, pivot:{ 0.0e+00, 0.0e+00 }, scale:{ 1.0e+00, 1.0e+00 }, rot:0 ],
        \\     RenderData[ clear:true, ccolor:{ 0, 0, 0, 255 }, tint:{ 255, 255, 255, 255 }, blend:ALPHA ],
        \\     offset:{ 1.0e+01, 1.0e+01 }
        \\
    ;
    DebugRenderAPI.printDebugRendering(&sb);
    //std.debug.print("\n{s}", .{sb.toString()});
    try std.testing.expectEqualStrings(api_out, sb.toString());
}
