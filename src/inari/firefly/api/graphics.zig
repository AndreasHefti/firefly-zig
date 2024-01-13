const std = @import("std");
const api = @import("api.zig");
const utils = @import("../../utils/utils.zig"); // TODO better way for import package?
const BindingIndex = api.BindingIndex;
const NoBinding = api.NoBinding;
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
        showFPS: *const fn (PosI) void = undefined,
        /// This creates a new viewport with the given ViewData.
        /// Uses the view data index for identifier
        /// @param viewData The ViewData strcut instance
        createView: *const fn (*ViewData) FFAPIError!void = undefined,
        /// Dispose the viewport with the given identifier
        /// @param viewId The ViewData identifier (index) if the viewport to dispose
        disposeView: *const fn (BindingIndex) FFAPIError!void = undefined,
        /// Loads image data from file system and create new texture data loaded into GPU
        /// @param textureData The texture DAO. Sets bindingIndex, width and height to the DAO
        loadTexture: *const fn (*TextureData) FFAPIError!void = undefined,
        /// Disposes the texture with given texture binding id from GPU memory
        /// @param textureId binding identifier of the texture to dispose.
        disposeTexture: *const fn (BindingIndex) FFAPIError!void = undefined,
        /// create new shader from given shader data and load it to GPU
        createShader: *const fn (*ShaderData) FFAPIError!void = undefined,
        /// Dispose the shader with the given binding identifier (shaderId) from GPU
        /// @param shaderId identifier of the shader to dispose.
        disposeShader: *const fn (BindingIndex) FFAPIError!void = undefined,
        /// Set the active sprite rendering shader. Note that the shader program must have been created before with createShader.
        /// @param shaderId The instance identifier of the shader.
        setActiveShader: *const fn (BindingIndex) FFAPIError!void = undefined,
        /// Start rendering to the given viewport
        startViewRendering: *const fn (*ViewData) FFAPIError!void = undefined,
        /// This applies a given offset on x- and y-axis to the current/actual viewport.
        /// This is usually used for layering
        /// @param vec with x- and y-axis offset to apply to the current/actual viewport rendering position
        applyViewportOffset: *const fn (*Vector2f) void = undefined,
        // TODO
        renderTexture: *const fn (BindingIndex, *TransformData, ?*RenderData) void = undefined,
        // TODO
        renderSprite: *const fn (*TransformData, *SpriteData) void = undefined,
        // TODO
        renderSpriteOff: *const fn (*TransformData, *Vector2f, *SpriteData) void = undefined,
        /// This is called form the firefly API to notify the end of rendering for a specified [ViewData].
        /// @param view [ViewData] that is ending to be rendered
        endViewRendering: *const fn (*ViewData) FFAPIError!void = undefined,
        // TODO actualize comment with new behavior
        /// Flushes the rendered views to the base view (screen) by applying also defined rendering pipelines as well
        /// as applying defined shaders for views. The process looks like:
        ///
        ///  1. virtualViews is an ordered list of virtual Views that has been rendered (render to texture before) and
        ///     are marked as ViewData.renderToBase = true
        ///  2. If the list is empty means there are no virtual views, and we only have the deal with base View.
        ///     In this case the current sprite and shape batch is just flushed to GPU.
        ///  3. Go through the ordered list of virtual views and apply first the rendering pipeline that is defined within
        ///     ViewData.isRenderTarget = true.
        ///  4. If rendering pipeline is defined, the process goes up to the last defined source view and renders
        ///     down to the target view step by step until this origin virtual view that renders to base is fully applied
        ///  5. Render the virtual view to the base view by applying shader if defined
        ///  6. Flush the resulting base view to the screen.
        ///
        flushRenderPipeline: *const fn () FFAPIError!void = undefined,

        pub fn init(initImpl: *const fn (i: *GraphicsAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        // TODO render shapes

        // /// This is called form the firefly API to render a shape. See [ShapeData] for more information about the data structure of shapes.
        // ///
        // /// @param data [ShapeData] DAO
        // /// @param xOffset the x-axis offset, default is 0f
        // /// @param yOffset the y-axis offset, default is 0f

        // fun renderShape(data: ShapeData, xOffset: Float = ZERO_FLOAT, yOffset: Float = ZERO_FLOAT)

        // /// This is called form the firefly API to render a shape with given [TransformData].
        // /// See [ShapeData] for more information about the data structure of shapes.
        // ///
        // /// @param data [ShapeData] DAO
        // /// @param transform [TransformData] DAO

        // fun renderShape(data: ShapeData, transform: TransformData)

        // /// This is called form the firefly API to render a shape with given [TransformData].
        // /// See [ShapeData] for more information about the data structure of shapes.
        // ///
        // /// @param data [ShapeData] DAO
        // /// @param transform [TransformData] DAO
        // /// @param xOffset the x-axis offset
        // /// @param yOffset the y-axis offset

        // fun renderShape(data: ShapeData, transform: TransformData, xOffset: Float, yOffset: Float)

        // TODO Texture pixel handling
        // /// Gets the pixels of given texture as ByteArray in RGBA8888 format.
        // ///
        // /// @param textureId The texture identifier
        // /// @return ByteArray of pixels in RGBA8888 format

        // fun getTexturePixels(textureId: Int): ByteArray

        // /// Set or draw the given pixels to the specified texture.
        // ///
        // /// @param textureId The texture identifier
        // /// @param region specified the region to draw the pixels on the texture
        // /// @param pixels ByteArray of pixels in RGBA8888 format

        // fun setTexturePixels(textureId: Int, region: Vector4i, pixels: ByteArray)

        // /// Gets the pixels of the given active screen region.
        // ///
        // /// @param region specified the region to get pixels form the screen
        // ///  @return ByteArray of pixels in RGBA8888 format

        // fun getScreenshotPixels(region: Vector4i): ByteArray
    };
}

/// This implementation of GraphicsAPI can be used for debugging
///
/// var graphics = GraphicsAPI().init(DebugGraphicsAPI.initImpl);
/// or
/// var graphics = GraphicsAPI().init(DebugGraphicsAPI.initScreen(800, 600).initImpl);
pub const DebugGraphicsAPI = struct {
    pub var screen_width: Int = 800;
    pub var screen_height: Int = 600;

    pub fn initImpl(interface: *GraphicsAPI()) void {
        interface.screenWidth = screenWidth;
        interface.screenHeight = screenHeight;
        interface.showFPS = showFPS;
        interface.createView = createView;
        interface.disposeView = disposeView;
        interface.loadTexture = loadTexture;
        interface.disposeTexture = disposeTexture;
        interface.createShader = createShader;
        interface.disposeShader = disposeShader;
        interface.setActiveShader = setActiveShader;
        interface.startViewRendering = startViewRendering;
        interface.applyViewportOffset = applyViewportOffset;
        interface.renderTexture = renderTexture;
        interface.renderSprite = renderSprite;
        interface.renderSpriteOff = renderSpriteOff;
        interface.endViewRendering = endViewRendering;
        interface.flushRenderPipeline = flushRenderPipeline;
    }

    pub fn screenWidth() Int {
        return screen_width;
    }

    pub fn screenHeight() Int {
        return screen_height;
    }

    pub fn showFPS(pos: PosI) void {
        _ = pos;
    }

    pub fn createView(viewData: *ViewData) FFAPIError!void {
        _ = viewData;
    }

    pub fn disposeView(bindingIndex: BindingIndex) FFAPIError!void {
        _ = bindingIndex;
    }

    pub fn loadTexture(textureData: *TextureData) FFAPIError!void {
        _ = textureData;
    }

    pub fn disposeTexture(textureId: BindingIndex) FFAPIError!void {
        _ = textureId;
    }

    pub fn createShader(data: *ShaderData) FFAPIError!void {
        _ = data;
    }

    pub fn disposeShader(shaderId: BindingIndex) FFAPIError!void {
        _ = shaderId;
    }

    pub fn setActiveShader(shaderId: BindingIndex) FFAPIError!void {
        _ = shaderId;
    }

    pub fn startViewRendering(view: *ViewData) FFAPIError!void {
        _ = view;
    }

    pub fn applyViewportOffset(offset: *Vector2f) void {
        _ = offset;
    }

    pub fn renderTexture(textureId: BindingIndex, transform: *TransformData, renderData: ?*RenderData) void {
        _ = renderData;
        _ = transform;
        _ = textureId;
    }

    pub fn renderSprite(transform: *TransformData, spriteData: *SpriteData) void {
        _ = spriteData;
        _ = transform;
    }

    pub fn renderSpriteOff(transform: *TransformData, offset: *Vector2f, spriteData: *SpriteData) void {
        _ = spriteData;
        _ = offset;
        _ = transform;
    }

    pub fn endViewRendering(view: *ViewData) FFAPIError!void {
        _ = view;
    }

    pub fn flushRenderPipeline() FFAPIError!void {}
};

pub const debugGraphics = GraphicsAPI().init(DebugGraphicsAPI.initImpl);

test "debug init" {
    var width = debugGraphics.screenWidth();
    var height = debugGraphics.screenHeight();

    try std.testing.expect(width == 800);
    try std.testing.expect(height == 600);
}
