const std = @import("std");
const Allocator = std.mem.Allocator;

const EventDispatch = utils.event.EventDispatch;
const String = utils.String;
const NO_NAME = utils.NO_NAME;
const CInt = utils.CInt;
const Float = utils.Float;
const PosI = utils.geom.PosI;
const PosF = utils.geom.PosF;
const RectI = utils.geom.RectI;
const RectF = utils.geom.RectF;
const Color = utils.geom.Color;
const Vector2f = utils.geom.Vector2f;
const Vector3f = utils.geom.Vector3f;
const Vector4f = utils.geom.Vector4f;
const StringBuffer = utils.StringBuffer;

// public API
pub const testing = @import("testing.zig");
pub const utils = @import("../../utils/utils.zig");
pub const Engine = @import("Engine.zig");
pub const Component = @import("Component.zig");
pub const System = @import("System.zig");
pub const Timer = @import("Timer.zig");
pub const Entity = @import("Entity.zig");
pub const Asset = @import("Asset.zig");
pub const Index = usize;
pub const UNDEF_INDEX = std.math.maxInt(Index);
pub const BindingId = usize;
pub const NO_BINDING: BindingId = std.math.maxInt(usize);

pub const InitMode = enum { TESTING, DEVELOPMENT, PRODUCTION };

pub const UpdateEvent = struct {};
pub const UpdateListener = *const fn (*const UpdateEvent) void;
pub const RenderEventType = enum {
    PRE_RENDER,
    RENDER,
    POST_RENDER,
};
pub const RenderEvent = struct { type: RenderEventType };
pub const RenderListener = *const fn (*const RenderEvent) void;

// public API constants
pub var COMPONENT_ALLOC: Allocator = undefined;
pub var ENTITY_ALLOC: Allocator = undefined;
pub var ALLOC: Allocator = undefined;
pub var RENDERING_API: RenderAPI() = undefined;

// initialization
var initialized = false;
pub fn initTesting() !void {
    try init(
        std.testing.allocator,
        std.testing.allocator,
        std.testing.allocator,
        InitMode.TESTING,
    );
}

pub fn init(
    component_allocator: Allocator,
    entity_allocator: Allocator,
    allocator: Allocator,
    initMode: InitMode,
) !void {
    defer initialized = true;
    if (initialized)
        return;

    COMPONENT_ALLOC = component_allocator;
    ENTITY_ALLOC = entity_allocator;
    ALLOC = allocator;

    try utils.aspect.init(allocator);

    if (initMode == InitMode.TESTING) {
        RENDERING_API = try testing.createTestRenderAPI();
    } else {
        // TODO

    }

    Engine.init();
    try Component.init();
    Timer.init();

    // register api based components and entity components
    Component.registerComponent(Asset);
    Component.registerComponent(System);
    Component.registerComponent(Entity);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    Engine.deinit();
    Timer.deinit();
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

pub const TextureData = struct {
    resource: String = NO_NAME,
    binding: BindingId = NO_BINDING,
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

pub const Projection = struct {
    clear_color: ?Color = Color{ 0, 0, 0, 255 },
    offset: PosF = PosF{ 0, 0 },
    pivot: PosF = PosF{ 0, 0 },
    zoom: Float = 1,
    rotation: Float = 0,

    pub fn format(
        self: Projection,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Projection[ clear_color:{any}, offset:{any}, pivot:{any}, zoom:{d}, rot:{d} ]",
            self,
        );
    }
};

pub const RenderTextureData = struct {
    binding: BindingId = NO_BINDING,
    width: CInt = 0,
    height: CInt = 0,

    pub fn format(
        self: RenderTextureData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "RenderTextureData[ bind:{d}, w:{d}, h:{d} ]",
            self,
        );
    }
};

pub const ShaderUpdate = struct {
    setUniformFloat: *const fn (String, Float) void = undefined,
    setUniformVec2: *const fn (String, *Vector2f) void = undefined,
    setUniformVec3: *const fn (String, *Vector3f) void = undefined,
    setUniformColorVec4: *const fn (String, *Vector4f) void = undefined,
    bindTexture: *const fn (String, BindingId) void = undefined,
};

pub const ShaderData = struct {
    binding: BindingId = NO_BINDING,
    vertex_shader_resource: String = NO_NAME,
    fragment_shader_resource: String = NO_NAME,
    file_resource: bool = true,
    shaderUpdate: ShaderUpdate = undefined,

    pub fn format(
        self: ShaderData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "ShaderData[ binding:{d}, vert:{s}, frag:{s}, file_resource:{} ]",
            .{ self.binding, self.vertex_shader_resource, self.fragment_shader_resource, self.file_resource },
        );
    }
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
    tint_color: Color = Color{ 255, 255, 255, 255 },
    blend_mode: BlendMode = BlendMode.ALPHA,

    pub fn format(
        self: RenderData,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "RenderData[ tint:{any}, blend:{} ]",
            self,
        );
    }
};

pub const SpriteData = struct {
    texture_binding: BindingId = NO_BINDING,
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
        /// Uses Projection to update camera projection and clear target before start rendering
        startRendering: *const fn (?BindingId, ?*const Projection) void = undefined,
        /// Set the active sprite rendering shader. Note that the shader program must have been created before with createShader.
        /// @param shaderId The instance identifier of the shader.
        setActiveShader: *const fn (BindingId) FFAPIError!void = undefined,
        /// This renders a given RenderTextureData (BindingId) to the actual render target that can be
        /// rendering texture or the screen
        renderTexture: *const fn (BindingId, *const TransformData, ?*const RenderData, ?*const Vector2f) void = undefined,
        // TODO
        renderSprite: *const fn (*const SpriteData, *const TransformData, ?*const RenderData, ?*const Vector2f) void = undefined,
        /// This is called form the firefly API to notify the end of rendering for the actual render target (RenderTextureData).
        /// switches back to screen rendering
        endRendering: *const fn () void = undefined,

        printDebug: *const fn (*StringBuffer) void = undefined,

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
