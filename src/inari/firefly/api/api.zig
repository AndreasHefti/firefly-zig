const std = @import("std");
const graphics = @import("graphics.zig");
const utils = @import("../../utils/utils.zig"); // TODO better way for import package?

pub const String = utils.String;
pub const NO_NAME = utils.NO_NAME;

pub const Int = utils.Int;
pub const UNDEF_INT = utils.UNDEF_INT;

pub const Float = utils.Float;

pub const PosI = utils.geom.PosI;
pub const PosF = utils.geom.PosF;
pub const RectI = utils.geom.RectI;
pub const RectF = utils.geom.RectF;
pub const Color = utils.geom.Color;

pub const BindingIndex = usize;
pub const NO_BINDING: BindingIndex = std.math.maxInt(usize);

pub const FFAPIError = error{
    GenericError,
    GraphicsInitError,
    GraphicsError,
};

/// Color blending modes
pub const BlendMode = enum(Int) {
    /// Blend textures considering alpha (default)
    BLEND_ALPHA = 0,
    /// Blend textures adding colors
    BLEND_ADDITIVE = 1,
    /// Blend textures multiplying colors
    BLEND_MULTIPLIED = 2,
    /// Blend textures adding colors (alternative)
    BLEND_ADD_COLORS = 3,
    /// Blend textures subtracting colors (alternative)
    BLEND_SUBTRACT_COLORS = 4,
    /// Blend premultiplied textures considering alpha
    BLEND_ALPHA_PREMULTIPLY = 5,
    /// Blend textures using custom src/dst factors (use rlSetBlendFactors())
    BLEND_CUSTOM = 6,
    /// Blend textures using custom rgb/alpha separate src/dst factors (use rlSetBlendFactorsSeparate())
    BLEND_CUSTOM_SEPARATE = 7,
};

// pub const ViewData = struct {
//     id: BindingIndex = NO_BINDING,
//     renderTarget: BindingIndex = NO_BINDING,
//     renderShader: BindingIndex = NO_BINDING,
//     bounds: RectI = RectI{ 0, 0, 0, 0 },
//     worldPosition: PosF = PosF{ 0, 0 },
//     clearColor: Color = Color{ 0, 0, 0, 255 },
//     clearBeforeStartRendering: bool = true,
//     tintColor: Color = Color{ 255, 255, 255, 255 },
//     blendMode: BlendMode = BlendMode.BLEND_ALPHA,
//     zoom: Float = 1,
//     fboScale: Float = 1,
// };

pub const TextureData = struct {
    resourceName: String = NO_NAME,
    bindingIndex: BindingIndex = NO_BINDING,
    width: Int = UNDEF_INT,
    height: Int = UNDEF_INT,
    isMipmap: bool = false,
    wrapS: Int = UNDEF_INT,
    wrapT: Int = UNDEF_INT,
    minFilter: Int = UNDEF_INT,
    magFilter: Int = UNDEF_INT,
    fboScale: Float = 1,
};

// TODO
// interface ShaderUpdate {
//     fun setUniformFloat(bindingName: String, value: Float)
//     fun setUniformVec2(bindingName: String, value: Vector2f)
//     fun setUniformVec3(bindingName: String, value: Vector3f)
//     fun setUniformColorVec4(bindingName: String, value:Vector4f)
//     fun bindTexture(bindingName: String, value: Int)
//     fun bindViewTexture(bindingName: String, value: Int)
// }

pub const ShaderData = struct {
    bindingIndex: BindingIndex = NO_BINDING,
    vertexShaderResourceName: String = NO_NAME,
    vertexShaderProgram: String = NO_NAME,
    fragmentShaderResourceName: String = NO_NAME,
    fragmentShaderProgram: String = NO_NAME,
    // TODO
    //shaderUpdate: (ShaderUpdate) -> Unit = VOID_CONSUMER_1
};

pub const TransformData = struct {
    position: PosF = PosF{ 0, 0 },
    pivot: PosF = PosF{ 0, 0 },
    scale: PosF = PosF{ 1, 1 },
    rotation: Float = 0,

    pub fn hasRotation(self: *TransformData) bool {
        return self.rotation != 0;
    }

    pub fn hasScale(self: *TransformData) bool {
        return self.scale[0] != 1 or self.scale[2] != 1;
    }
};

pub const RenderData = struct {
    clear: bool = true,
    clearColor: Color = Color{ 0, 0, 0, 255 },
    tintColor: Color = Color{ 255, 255, 255, 255 },
    blendMode: BlendMode = BlendMode.BLEND_ALPHA,
};

pub const SpriteData = struct {
    textureIndex: BindingIndex = NO_BINDING,
    textureBounds: RectF = RectF{ 0, 0, 0, 0 },
    hFlip: bool = false,
    vFlip: bool = false,
};

test {
    std.testing.refAllDecls(@import("graphics.zig"));
}
