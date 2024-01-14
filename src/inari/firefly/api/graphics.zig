const std = @import("std");
const api = @import("api.zig");
const utils = @import("../../utils/utils.zig"); // TODO better way for import package?
const DynArray = utils.dynarray.DynArray;
const BindingIndex = api.BindingIndex;
const NO_BINDING = api.NO_BINDING;
const BlendMode = api.BlendMode;
const ViewData = api.ViewData;
const TextureData = api.TextureData;
const ShaderData = api.ShaderData;
const TransformData = api.TransformData;
const RenderData = api.RenderData;
const SpriteData = api.SpriteData;
const FFAPIError = api.FFAPIError;
const PosI = api.PosI;
const Int = utils.Int;
const Vector2f = utils.geom.Vector2f;

pub fn GraphicsAPI() type {
    return struct {
        const Self = @This();
        /// return the actual screen width
        screenWidth: *const fn () Int = undefined,
        /// return the actual screen height
        screenHeight: *const fn () Int = undefined,
        /// Show actual frame rate per second at given position on the screen
        showFPS: *const fn (*PosI) void = undefined,

        /// Loads image data from file system and create new texture data loaded into GPU
        /// @param textureData The texture DAO. Sets bindingIndex, width and height to the DAO
        loadTexture: *const fn (*TextureData) FFAPIError!void = undefined,
        /// Disposes the texture with given texture binding id from GPU memory
        /// @param textureId binding identifier of the texture to dispose.
        disposeTexture: *const fn (*TextureData) FFAPIError!void = undefined,
        createRenderTexture: *const fn (*TextureData) FFAPIError!void = undefined,
        disposeRenderTexture: *const fn (*TextureData) FFAPIError!void = undefined,
        /// create new shader from given shader data and load it to GPU
        createShader: *const fn (*ShaderData) FFAPIError!void = undefined,
        /// Dispose the shader with the given binding identifier (shaderId) from GPU
        /// @param shaderId identifier of the shader to dispose.
        disposeShader: *const fn (*ShaderData) FFAPIError!void = undefined,

        /// Start rendering to the given render texture or to the screen if no binding index is given
        /// Use given render data as default rendering attributes
        startRendering: *const fn (?BindingIndex) void = undefined,
        /// Set the active sprite rendering shader. Note that the shader program must have been created before with createShader.
        /// @param shaderId The instance identifier of the shader.
        setActiveShader: *const fn (BindingIndex) FFAPIError!void = undefined,
        // TODO
        renderTexture: *const fn (BindingIndex, *TransformData, ?*RenderData, ?*Vector2f) void = undefined,
        // TODO
        renderSprite: *const fn (*SpriteData, *TransformData, ?*RenderData, ?*Vector2f) void = undefined,
        /// This is called form the firefly API to notify the end of rendering for a specified [ViewData].
        /// @param view [ViewData] that is ending to be rendered
        endRendering: *const fn (?BindingIndex) void = undefined,

        deinit: *const fn () void = undefined,

        pub fn init(
            initImpl: *const fn (*GraphicsAPI(), std.mem.Allocator) anyerror!void,
            allocator: std.mem.Allocator,
        ) !Self {
            var self = Self{};
            _ = try initImpl(&self, allocator);
            return self;
        }
    };
}

pub fn createDebugGraphics(allocator: std.mem.Allocator) !GraphicsAPI() {
    if (DebugGraphicsAPI.initialized) {
        return FFAPIError.GraphicsInitError;
    }
    return try GraphicsAPI().init(DebugGraphicsAPI.initImpl, allocator);
}

/// This implementation of GraphicsAPI can be used for debugging
///
/// var graphics = GraphicsAPI().init(DebugGraphicsAPI.initImpl);
/// or
/// var graphics = GraphicsAPI().init(DebugGraphicsAPI.initScreen(800, 600).initImpl);
const DebugGraphicsAPI = struct {
    pub var screen_width: Int = 800;
    pub var screen_height: Int = 600;
    var alloc: std.mem.Allocator = undefined;
    var initialized = false;

    const defaultOffset = Vector2f{ 0, 0 };
    const defaultRenderData = RenderData{};

    var textures: DynArray(TextureData) = undefined;
    var renderTextures: DynArray(TextureData) = undefined;
    var shaders: DynArray(ShaderData) = undefined;

    var currentRenderTexture: ?BindingIndex = null;
    var currentShader: ?BindingIndex = null;
    var currentOffset: *const Vector2f = &defaultOffset;
    var currentRenderData: *const RenderData = &defaultRenderData;

    fn initImpl(interface: *GraphicsAPI(), allocator: std.mem.Allocator) !void {
        alloc = allocator;
        textures = try DynArray(TextureData).init(allocator, null);
        renderTextures = try DynArray(TextureData).init(allocator, null);
        shaders = try DynArray(ShaderData).init(allocator, null);

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
        initialized = true;
    }

    fn deinit() void {
        textures.deinit();
        renderTextures.deinit();
        shaders.deinit();
        initialized = false;
    }

    pub fn screenWidth() Int {
        return screen_width;
    }

    pub fn screenHeight() Int {
        return screen_height;
    }

    pub fn showFPS(pos: *PosI) void {
        std.debug.print("showFPS: {any}\n", .{pos.*});
    }

    pub fn loadTexture(textureData: *TextureData) FFAPIError!void {
        textureData.bindingIndex = textures.add(textureData.*);
        textures.get(textureData.bindingIndex).bindingIndex = textureData.bindingIndex;
        std.debug.print("loadTexture: {any}\n", .{textureData.*});
    }

    pub fn disposeTexture(textureData: *TextureData) FFAPIError!void {
        std.debug.print("disposeTexture: {any}\n", .{textureData.*});
        if (textureData.bindingIndex != NO_BINDING) {
            textures.reset(textureData.bindingIndex);
            textureData.bindingIndex = NO_BINDING;
        }
    }

    pub fn createRenderTexture(textureData: *TextureData) FFAPIError!void {
        textureData.bindingIndex = renderTextures.add(textureData.*);
        renderTextures.get(textureData.bindingIndex).bindingIndex = textureData.bindingIndex;
        std.debug.print("createRenderTexture: {any}\n", .{textureData.*});
    }

    pub fn disposeRenderTexture(textureData: *TextureData) FFAPIError!void {
        std.debug.print("disposeRenderTexture: {any}\n", .{textureData.*});
        if (textureData.bindingIndex != NO_BINDING) {
            renderTextures.reset(textureData.bindingIndex);
            textureData.bindingIndex = NO_BINDING;
        }
    }

    pub fn createShader(shaderData: *ShaderData) FFAPIError!void {
        shaderData.bindingIndex = shaders.add(shaderData.*);
        shaders.get(shaderData.bindingIndex).bindingIndex = shaderData.bindingIndex;
        std.debug.print("createShader: {any}\n", .{shaderData.*});
    }

    pub fn disposeShader(shaderData: *ShaderData) FFAPIError!void {
        std.debug.print("disposeShader: {any}\n", .{shaderData.*});
        if (shaderData.bindingIndex != NO_BINDING) {
            shaders.reset(shaderData.bindingIndex);
            shaderData.bindingIndex = NO_BINDING;
        }
    }

    pub fn startRendering(textureId: ?BindingIndex) void {
        std.debug.print("startRendering: {any}\n", .{textureId});
        if (textureId) |id| {
            currentRenderTexture = id;
        }
    }

    pub fn setActiveShader(shaderId: BindingIndex) FFAPIError!void {
        std.debug.print("setActiveShader: {any}\n", .{shaderId});
        currentShader = shaderId;
    }

    pub fn renderTexture(textureId: BindingIndex, transform: *TransformData, renderData: ?*RenderData, offset: ?*Vector2f) void {
        var textureData = textures.get(textureId);
        std.debug.print("renderTexture: {any}\n", .{textureData.*});
        if (currentRenderTexture) |rti| {
            std.debug.print("  render to: {any}\n", .{textures.get(rti)});
        } else {
            std.debug.print("  render to: screen\n", .{});
        }
        std.debug.print("  with TransformData: {any}\n", .{transform.*});
        if (renderData) |rd| {
            std.debug.print("  with RenderData: {any}\n", .{rd.*});
            currentRenderData = rd;
        }
        if (offset) |o| {
            std.debug.print("  with render offset: {any}\n", .{o.*});
            currentOffset = o;
        }
    }

    pub fn renderSprite(spriteData: *SpriteData, transform: *TransformData, renderData: ?*RenderData, offset: ?*Vector2f) void {
        std.debug.print("renderSprite: {any}\n", .{spriteData.*});
        var textureData = textures.get(spriteData.textureIndex);
        std.debug.print("  texture: {any}\n", .{textureData.*});
        if (currentRenderTexture) |rti| {
            std.debug.print("  render to: {any}\n", .{textures.get(rti)});
        } else {
            std.debug.print("  render to: screen\n", .{});
        }
        std.debug.print("  with TransformData: {any}\n", .{transform.*});
        if (renderData) |rd| {
            std.debug.print("  with RenderData: {any}\n", .{rd.*});
            currentRenderData = rd;
        }
        if (offset) |o| {
            std.debug.print("  with render offset: {any}\n", .{o.*});
            currentOffset = o;
        }
    }

    pub fn endRendering(textureId: ?BindingIndex) void {
        std.debug.print("endRendering: {any}\n", .{textureId});
        currentRenderTexture = null;
    }
};

test "debug init" {
    var debugGraphics = try createDebugGraphics(std.testing.allocator);
    defer debugGraphics.deinit();

    var width = debugGraphics.screenWidth();
    var height = debugGraphics.screenHeight();

    try std.testing.expect(width == 800);
    try std.testing.expect(height == 600);

    try std.testing.expectError(
        FFAPIError.GraphicsInitError,
        createDebugGraphics(std.testing.allocator),
    );

    var fpsPos = PosI{ 10, 10 };
    std.debug.print("\n", .{});
    debugGraphics.showFPS(&fpsPos);

    var t1 = TextureData{ .resourceName = "t1" };
    var t2 = TextureData{ .resourceName = "t2" };
    var sprite = SpriteData{};
    var transform = TransformData{};
    var renderData = RenderData{};
    transform.position[0] = 10;
    transform.position[1] = 100;

    try std.testing.expect(t1.bindingIndex == NO_BINDING);
    try debugGraphics.loadTexture(&t1);
    try std.testing.expect(t1.bindingIndex != NO_BINDING);
    try std.testing.expect(t2.bindingIndex == NO_BINDING);
    try debugGraphics.createRenderTexture(&t2);
    try std.testing.expect(t2.bindingIndex != NO_BINDING);

    sprite.textureIndex = t1.bindingIndex;
    debugGraphics.renderSprite(&sprite, &transform, &renderData, null);
}
