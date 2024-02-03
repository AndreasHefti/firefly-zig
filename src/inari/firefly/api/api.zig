const std = @import("std");
const Allocator = std.mem.Allocator;

const rendering = @import("rendering_api.zig");
const String = utils.String;
const NO_NAME = utils.NO_NAME;
const CInt = utils.CInt;
const Float = utils.Float;
const PosI = utils.geom.PosI;
const PosF = utils.geom.PosF;
const RectI = utils.geom.RectI;
const RectF = utils.geom.RectF;
const Color = utils.geom.Color;

pub const utils = @import("../../utils/utils.zig");
//pub const utils = @import("utils");
pub const Component = @import("Component.zig");
pub const System = @import("System.zig");
pub const Timer = @import("Timer.zig");
pub const Entity = @import("Entity.zig");
pub const Asset = @import("Asset.zig");
pub const BindingIndex = usize;
pub const NO_BINDING: BindingIndex = std.math.maxInt(usize);

pub var COMPONENT_ALLOC: Allocator = undefined;
pub var ENTITY_ALLOC: Allocator = undefined;
pub var ALLOC: Allocator = undefined;
pub var RENDERING_API: rendering.RenderAPI() = undefined;

// module initialization
var initialized = false;
pub fn init(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    defer initialized = true;
    if (initialized) return;

    COMPONENT_ALLOC = component_allocator;
    ENTITY_ALLOC = entity_allocator;
    ALLOC = allocator;

    try utils.aspect.init(allocator);

    // TODO make this configurable
    RENDERING_API = try rendering.createDebugRenderAPI(allocator);

    System.init();
    try Component.init();
    try Asset.init();

    // register api based components and entity components
    Component.registerComponent(Asset);
    Component.registerComponent(Entity);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;

    Asset.deinit();
    System.deinit();
    Component.deinit();
    RENDERING_API.deinit();
    utils.aspect.deinit();
}

pub const FFAPIError = error{
    GenericError,
    SingletonAlreadyInitialized,
    ComponentInitError,
    RenderingInitError,
    RenderingError,
};

pub const ActionType = enum {
    CREATED,
    ACTIVATED,
    DEACTIVATED,
    DISPOSED,
};

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
    resource: String = NO_NAME,
    binding: BindingIndex = NO_BINDING,
    width: CInt = 0,
    height: CInt = 0,
    is_mipmap: bool = false,
    s_wrap: CInt = -1,
    t_wrap: CInt = -1,
    min_filter: CInt = -1,
    mag_filter: CInt = -1,

    pub fn format(
        self: TextureData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "TextureData[ res:{s}, bind:{d}, w:{d}, h:{d}, mipmap:{}, wrap:{}|{}, minmag:{}|{}]",
            self,
        );
    }
};

pub const RenderTextureData = struct {
    binding: BindingIndex = NO_BINDING,
    width: CInt = 0,
    height: CInt = 0,
    fbo_scale: Float = 1,

    pub fn format(
        self: RenderTextureData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "RenderTextureData[ bind:{d}, w:{d}, h:{d}, fbo:{d} ]",
            self,
        );
    }
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
    binding: BindingIndex = NO_BINDING,
    vertex_shader_resource: String = NO_NAME,
    vertex_shader_program: String = NO_NAME,
    fragment_shader_resource: String = NO_NAME,
    fragment_shader_program: String = NO_NAME,
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

    pub fn format(
        self: TransformData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "TransformData[ pos:{any}, pivot:{any}, scale:{any}, rot:{d} ]",
            self,
        );
    }
};

pub const RenderData = struct {
    clear: bool = true,
    clear_color: Color = Color{ 0, 0, 0, 255 },
    tint_color: Color = Color{ 255, 255, 255, 255 },
    blend_mode: BlendMode = BlendMode.ALPHA,

    pub fn format(
        self: RenderData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "RenderData[ clear:{}, ccolor:{any}, tint:{any}, blend:{} ]",
            self,
        );
    }
};

pub const SpriteData = struct {
    texture_binding: BindingIndex = NO_BINDING,
    texture_bounds: RectF = RectF{ 0, 0, 0, 0 },

    // x = x + width / width = -width
    pub fn flip_x(self: *SpriteData) void {
        self.texture_bounds[0] = self.texture_bounds[0] + self.texture_bounds[2];
        self.texture_bounds[2] = -self.texture_bounds[2];
    }

    // y = y + height / height = -height
    pub fn flip_y(self: *SpriteData) void {
        self.texture_bounds[1] = self.texture_bounds[1] + self.texture_bounds[3];
        self.texture_bounds[3] = -self.texture_bounds[3];
    }

    pub fn format(
        self: SpriteData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "SpriteData[ bind:{d}, bounds:{any} ]",
            self,
        );
    }
};

test {
    std.testing.refAllDecls(@import("rendering_api.zig"));
    std.testing.refAllDecls(@import("system.zig"));
    std.testing.refAllDecls(@import("component.zig"));
}
