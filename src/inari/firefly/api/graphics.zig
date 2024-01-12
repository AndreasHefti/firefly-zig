const std = @import("std");
const api = @import("api.zig");
const utils = @import("../../utils/utils.zig"); // TODO better way for import package?
const BindingIndex = api.BindingIndex;
const NoBinding = api.NoBinding;
const BlendMode = api.BlendMode;
const ViewData = api.ViewData;
const TextureData = api.TextureData;
const FFAPIError = api.FFAPIError;

pub fn GraphicsAPI() type {
    return struct {
        const Self = @This();

        _fn_screenWidth: fn () i32 = undefined,
        _fn_screenHeight: fn () i32 = undefined,
        _fn_createView: fn (*ViewData) FFAPIError!void = undefined,
        _fn_disposeView: fn (BindingIndex) FFAPIError!void = undefined,
        _fn_loadTexture: fn (*TextureData) FFAPIError!void = undefined,
        _fn_disposeTexture: fn (BindingIndex) FFAPIError!void = undefined,

        pub fn init(initImpl: *const fn (i: *GraphicsAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        /// return the actual screen width
        pub fn screenWidth(self: *Self) usize {
            return self._fn_screenWidth();
        }

        /// return the actual screen height
        pub fn screenHeight(self: *Self) usize {
            return self._fn_screenHeight();
        }

        /// This creates a new viewport with the given ViewData.
        /// Uses the view data index for identifier
        /// @param viewData The ViewData strcut instance
        pub fn createView(self: *Self, viewData: *ViewData) FFAPIError!void {
            return self._fn_createView(viewData);
        }

        /// Dispose the viewport with the given identifier
        /// @param viewId The ViewData identifier (index) if the viewport to dispose
        fn disposeView(self: *Self, bindingIndex: BindingIndex) FFAPIError!void {
            return self._fn_disposeView(bindingIndex);
        }

        /// Loads image data from file system and create new texture data loaded into GPU
        /// @param textureData The texture DAO. Sets bindingIndex, width and height to the DAO
        fn loadTexture(self: *Self, textureData: *TextureData) FFAPIError!void {
            return self._fn_loadTexture(textureData);
        }

        /// Disposes the texture with given texture binding id from GPU memory
        /// @param textureId binding identifier of the texture to dispose.
        fn disposeTexture(self: *Self, textureId: BindingIndex) FFAPIError!void {
            return self._fn_disposeTexture(textureId);
        }

        // fun createShader(data: ShaderData): Int

        // /// This is called from the firefly API when a shader script is disposed
        // /// and must release and delete the shader script on GPU level
        // ///
        // /// @param shaderId identifier of the shader to dispose.

        // fun disposeShader(shaderId: Int)

        // /// Set the active sprite rendering shader. Note that the shader program must have been created before with createShader.
        // /// @param shaderId The instance identifier of the shader.

        // fun setActiveShader(shaderId: Int)

        // /// Clears the given view with its defined clear color.
        // ///
        // /// @param view the [ViewData] to clear color and other buffers

        // fun clearView(view: ViewData)

        // fun startViewportRendering(view: ViewData) = startViewportRendering(view, view.clearBeforeStartRendering)

        // /// This is called form the firefly API before rendering to a given [ViewData] and must
        // /// prepare all the stuff needed to render the that [ViewData] on following renderXXX calls.
        // ///
        // /// @param view the [ViewData] that is starting to be rendered
        // /// @param clear indicates whether the [ViewData] should be cleared with the vies clear-color before rendering or not

        // fun startViewportRendering(view: ViewData, clear: Boolean)

        // /// This applies a given offset on x- and y-axis to the current/actual viewport.
        // /// This is usually used for layering
        // ///
        // /// @param x the x-axis offset to apply to the current/actual viewport rendering position
        // /// @param y the y-axis offset to apply to the current/actual viewport rendering position

        // fun applyViewportOffset(x: Float, y: Float)

        // /// This is called form the firefly API to render a created texture on specified position to the actual [ViewData]
        // ///
        // /// @param textureId the texture identifier
        // /// @param posX the x-axis offset
        // /// @param posY the y-axis offset
        // /// @param tintColor the tint color for alpha blending. Default is Vector4f(1f, 1f, 1f, 1f)
        // /// @param blendMode the blend mode. Default is BlendMode.NONE

        // fun renderTexture(
        //     textureId: Int,
        //     posX: Float,
        //     posY: Float,
        //     scaleX: Float = 1f,
        //     scaleY: Float = 1f,
        //     rotation: Float = ZERO_FLOAT,
        //     flipX: Boolean = false,
        //     flipY: Boolean = false,
        //     tintColor: Vector4f = Vector4f(1f, 1f, 1f, 1f),
        //     blendMode: BlendMode = BlendMode.NONE)

        // /// This is called form the firefly API to render a created sprite on specified position to the actual [ViewData]
        // ///
        // /// @param renderableSprite the sprite DAO
        // /// @param xOffset the x-axis offset
        // /// @param yOffset the y-axis offset

        // fun renderSprite(renderableSprite: SpriteRenderable, xOffset: Float, yOffset: Float)

        // /// This is called form the firefly API to render a created sprite with specified [TransformData] to the actual [ViewData]
        // ///
        // /// @param renderableSprite the sprite DAO
        // /// @param transform [TransformData] DAO containing all transform data to render the sprite like: position-offset, scale, pivot, rotation

        // fun renderSprite(renderableSprite: SpriteRenderable, transform: TransformData)

        // /// This is called form the firefly API to render a created sprite with specified [TransformData] to the actual [ViewData]
        // ///
        // /// @param renderableSprite the sprite DAO
        // /// @param transform [TransformData] DAO containing all transform data to render the sprite like: position-offset, scale, pivot, rotation
        // /// @param xOffset the x-axis offset
        // /// @param yOffset the y-axis offset

        // fun renderSprite(renderableSprite: SpriteRenderable, transform: TransformData, xOffset: Float, yOffset: Float)

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

        // /// This is called form the firefly API to notify the end of rendering for a specified [ViewData].
        // /// @param view [ViewData] that is ending to be rendered

        // fun endViewportRendering(view: ViewData)

        // /// Flushes the rendered views to the base view (screen) by applying also defined rendering pipelines as well
        // /// as applying defined shaders for views. The process looks like:
        // ///
        // ///  1. virtualViews is an ordered list of virtual Views that has been rendered (render to texture before) and
        // ///     are marked as ViewData.renderToBase = true
        // ///  2. If the list is empty means there are no virtual views, and we only have the deal with base View.
        // ///     In this case the current sprite and shape batch is just flushed to GPU.
        // ///  3. Go through the ordered list of virtual views and apply first the rendering pipeline that is defined within
        // ///     ViewData.isRenderTarget = true.
        // ///  4. If rendering pipeline is defined, the process goes up to the last defined source view and renders
        // ///     down to the target view step by step until this origin virtual view that renders to base is fully applied
        // ///  5. Render the virtual view to the base view by applying shader if defined
        // ///  6. Flush the resulting base view to the screen.
        // ///
        // /// @param virtualViews sorted (z-position) list of virtual views that renders directly to the base view (screen)

        // fun flush(virtualViews: DynArrayRO<ViewData>)

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
