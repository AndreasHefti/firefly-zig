const std = @import("std");
pub const firefly = @import("../firefly.zig"); // TODO better way for import package?
pub const utils = @import("../../utils/utils.zig"); // TODO better way for import package?
pub const graphics = @import("graphics.zig");
pub const component = @import("component.zig");
pub const system = @import("system.zig");

pub const String = utils.String;
pub const NO_NAME = utils.NO_NAME;

pub const CInt = utils.CInt;
pub const Float = utils.Float;

pub const PosI = utils.geom.PosI;
pub const PosF = utils.geom.PosF;
pub const RectI = utils.geom.RectI;
pub const RectF = utils.geom.RectF;
pub const Color = utils.geom.Color;

pub const BindingIndex = usize;
pub const NO_BINDING: BindingIndex = std.math.maxInt(usize);

/// Color blending modes
pub const BlendMode = enum(CInt) {
    /// Blend textures considering alpha (default)
    ALPHA = 0,
    /// Blend textures adding colors
    ADDITIVE = 1,
    /// Blend textures multiplying colors
    MULTIPLIED = 2,
    /// Blend textures adding colors (alternative)
    ADD_COLORS = 3,
    /// Blend textures subtracting colors (alternative)
    SUBTRACT_COLORS = 4,
    /// Blend premultiplied textures considering alpha
    ALPHA_PREMULTIPLY = 5,
    /// Blend textures using custom src/dst factors (use rlSetBlendFactors())
    CUSTOM = 6,
    /// Blend textures using custom rgb/alpha separate src/dst factors (use rlSetBlendFactorsSeparate())
    CUSTOM_SEPARATE = 7,

    pub fn format(
        self: BlendMode,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll(switch (self) {
            .ALPHA => "ALPHA",
            .ADDITIVE => "ADDITIVE",
            .MULTIPLIED => "MULTIPLIED",
            .ADD_COLORS => "ADD_COLORS",
            .SUBTRACT_COLORS => "SUBTRACT_COLORS",
            .ALPHA_PREMULTIPLY => "ALPHA_PREMULTIPLY",
            .CUSTOM => "CUSTOM",
            .CUSTOM_SEPARATE => "CUSTOM_SEPARATE",
        });
    }
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
    width: CInt = 0,
    height: CInt = 0,
    isMipmap: bool = false,
    wrapS: CInt = -1,
    wrapT: CInt = -1,
    minFilter: CInt = -1,
    magFilter: CInt = -1,
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
    blendMode: BlendMode = BlendMode.ALPHA,
};

pub const SpriteData = struct {
    textureIndex: BindingIndex = NO_BINDING,
    textureBounds: RectF = RectF{ 0, 0, 0, 0 },
    hFlip: bool = false,
    vFlip: bool = false,
};

test {
    std.testing.refAllDecls(@import("graphics.zig"));
    std.testing.refAllDecls(@import("system.zig"));
    std.testing.refAllDecls(@import("component.zig"));
}
