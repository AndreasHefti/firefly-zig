const std = @import("std");
const inari = @import("../../inari.zig");
const firefly = inari.firefly;
const utils = inari.utils;

const Allocator = std.mem.Allocator;
const testing = @import("testing.zig");
const asset = @import("asset.zig");
const component = @import("Component.zig");
const system = @import("System.zig");
const timer = @import("Timer.zig");
const entity = @import("entity.zig");
const EventDispatch = utils.EventDispatch;
const Condition = utils.Condition;
const String = utils.String;
const CString = utils.CString;
const NO_NAME = utils.NO_NAME;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const CInt = utils.CInt;
const CUInt = utils.CUInt;
const Float = utils.Float;
const PosI = utils.PosI;
const PosF = utils.PosF;
const RectI = utils.RectI;
const RectF = utils.RectF;
const Color = utils.Color;
const Vector2f = utils.Vector2f;
const Vector3f = utils.Vector3f;
const Vector4f = utils.Vector4f;
const StringBuffer = utils.StringBuffer;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const InitMode = enum { TESTING, DEVELOPMENT, PRODUCTION };
pub var COMPONENT_ALLOC: Allocator = undefined;
pub var ENTITY_ALLOC: Allocator = undefined;
pub var ALLOC: Allocator = undefined;

pub var rendering: IRenderAPI() = undefined;
pub var window: IWindowAPI() = undefined;

pub const Asset = asset.Asset;
pub const AssetTrait = asset.AssetTrait;
pub const Component = component;
pub const ComponentEvent = component.ComponentEvent;
pub const ComponentActionType = component.ActionType;
pub const ComponentListener = component.ComponentListener;
pub const System = system.System;
pub const Timer = timer;
pub const UpdateScheduler = timer.UpdateScheduler;
pub const Entity = entity.Entity;
pub const EntityComponent = entity.EntityComponent;
pub const EntityEventSubscription = entity.EntityEventSubscription;

pub const BindingId = usize;
pub const NO_BINDING: BindingId = std.math.maxInt(usize);

//////////////////////////////////////////////////////////////
//// Initialization
//////////////////////////////////////////////////////////////

var initialized = false;

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

    try utils.init(allocator);

    if (initMode == InitMode.TESTING) {
        rendering = try testing.createTestRenderAPI();
    } else {
        rendering = try testing.createTestRenderAPI();
        //rendering = try @import("raylib/rendering.zig").createRenderAPI();
        //window = try @import("raylib/window.zig").createWindowAPI();
    }

    try Component.init();
    Timer.init();
    try asset.init();
    system.init();

    // register api based components and entity components
    Component.API.registerComponent(Entity);
    Component.API.registerComponent(system.SystemComponent);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    system.deinit();
    asset.deinit();
    Component.deinit();
    rendering.deinit();
    rendering = undefined;
    window = undefined;
    Timer.deinit();
    utils.deinit();
}

//////////////////////////////////////////////////////////////
//// Update Event and Render Event declarations
//////////////////////////////////////////////////////////////

pub const UpdateEvent = struct {};
pub const UpdateListener = *const fn (UpdateEvent) void;
pub const RenderEventType = enum {
    PRE_RENDER,
    RENDER,
    POST_RENDER,
};
pub const RenderEvent = struct { type: RenderEventType };
pub const RenderListener = *const fn (RenderEvent) void;

pub fn RenderEventSubscription(comptime _: type) type {
    return struct {
        const Self = @This();

        var _listener: RenderListener = undefined;
        var _condition: ?Condition(RenderEvent) = null;

        pub fn of(listener: RenderListener) Self {
            _listener = listener;
            return Self{};
        }

        pub fn withCondition(self: Self, condition: Condition(RenderEvent)) Self {
            _condition = condition;
            return self;
        }

        pub fn subscribe(self: Self) Self {
            firefly.Engine.subscribeRender(adapt);
            return self;
        }

        pub fn unsubscribe(self: Self) Self {
            firefly.Engine.unsubscribeRender(adapt);
            return self;
        }

        fn adapt(e: RenderEvent) void {
            if (_condition) |*c| if (!c.check(e))
                return;

            _listener(e);
        }
    };
}

pub fn UpdateEventSubscription(comptime _: type) type {
    return struct {
        const Self = @This();

        var _listener: UpdateListener = undefined;
        var _condition: ?Condition(UpdateEvent) = null;
        var _scheduler: ?UpdateScheduler = null;

        pub fn of(listener: UpdateListener) Self {
            _listener = listener;
            return Self{};
        }

        pub fn withCondition(self: Self, condition: Condition(UpdateEvent)) Self {
            _condition = condition;
            return self;
        }

        pub fn subscribe(self: Self) Self {
            firefly.Engine.subscribeUpdate(adapt);
            return self;
        }

        pub fn unsubscribe(self: Self) Self {
            firefly.Engine.unsubscribeUpdate(adapt);
            return self;
        }

        fn adapt(e: UpdateEvent) void {
            if (_scheduler) |*s| if (!s.needs_update)
                return;
            if (_condition) |*c| if (!c.check(e))
                return;

            _listener(e);
        }
    };
}

//////////////////////////////////////////////////////////////
//// Graphics API declarations
//////////////////////////////////////////////////////////////
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

// Texture parameters: filter mode
// NOTE 1: Filtering considers mipmaps if available in the texture
// NOTE 2: Filter is accordingly set for minification and magnification
pub const TextureFilter = enum(CInt) {
    TEXTURE_FILTER_POINT = 0, // No filter, just pixel approximation
    TEXTURE_FILTER_BILINEAR = 1, // Linear filtering
    TEXTURE_FILTER_TRILINEAR = 2, // Trilinear filtering (linear with mipmaps)
    TEXTURE_FILTER_ANISOTROPIC_4X = 3, // Anisotropic filtering 4x
    TEXTURE_FILTER_ANISOTROPIC_8X = 4, // Anisotropic filtering 8x
    TEXTURE_FILTER_ANISOTROPIC_16X = 5, // Anisotropic filtering 16x
};

// Texture parameters: wrap mode
pub const TextureWrap = enum(CInt) {
    TEXTURE_WRAP_REPEAT = 0, // Repeats texture in tiled mode
    TEXTURE_WRAP_CLAMP = 1, // Clamps texture to edge pixel in tiled mode
    TEXTURE_WRAP_MIRROR_REPEAT = 2, // Mirrors and repeats the texture in tiled mode
    TEXTURE_WRAP_MIRROR_CLAMP = 3, // Mirrors and clamps to border the texture in tiled mode
};

pub const Projection = struct {
    clear_color: ?Color = .{ 0, 0, 0, 255 },
    offset: PosF = .{ 0, 0 },
    pivot: PosF = .{ 0, 0 },
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

pub const TextureBinding = struct {
    id: BindingId = NO_BINDING,
    width: CInt = 0,
    height: CInt = 0,

    pub fn format(
        self: TextureBinding,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "TextureBinding[ id:{any}, width:{any}, height:{any} ]",
            self,
        );
    }
};

pub const RenderTextureBinding = struct {
    id: BindingId = NO_BINDING,
    width: CInt = 0,
    height: CInt = 0,

    pub fn format(
        self: RenderTextureBinding,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "RenderTextureBinding[ bind:{d}, w:{d}, h:{d} ]",
            self,
        );
    }
};

pub const TransformData = struct {
    position: PosF = .{ 0, 0 },
    pivot: PosF = .{ 0, 0 },
    scale: PosF = .{ 1, 1 },
    rotation: Float = 0,

    pub fn clear(self: *TransformData) void {
        self.position = .{ 0, 0 };
        self.pivot = .{ 0, 0 };
        self.scale = .{ 1, 1 };
        self.rotation = 0;
    }

    pub fn set(self: *TransformData, other: TransformData) void {
        self.position = other.position;
        self.pivot = other.pivot;
        self.scale = other.scale;
        self.rotation = other.rotation;
    }

    pub fn setDiscrete(self: *TransformData, other: TransformData) void {
        self.position = @floor(other.position);
        self.pivot = @floor(other.pivot);
        self.scale = other.scale;
        self.rotation = other.rotation;
    }

    pub fn add(self: *TransformData, other: TransformData) void {
        self.position += other.position;
        self.pivot += other.pivot;
        self.scale += other.scale;
        self.rotation += other.rotation;
    }

    pub fn minus(self: *TransformData, other: TransformData) void {
        self.position -= other.position;
        self.pivot -= other.pivot;
        self.scale -= other.scale;
        self.rotation -= other.rotation;
    }

    pub fn move(self: *TransformData, offset: Vector2f) void {
        self.position += offset;
    }

    pub fn moveDiscrete(self: *TransformData, offset: Vector2f) void {
        self.position += @floor(offset);
    }

    pub fn hasRotation(self: *TransformData) bool {
        return self.rotation != 0;
    }

    pub fn hasScale(self: *TransformData) bool {
        return self.scale[0] != 1 or self.scale[1] != 1;
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
    tint_color: Color = .{ 255, 255, 255, 255 },
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
    texture_bounds: RectF = .{ 0, 0, 0, 0 },

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

pub const WindowData = struct {
    width: CInt,
    height: CInt,
    fps: CInt,
    title: CString,
    flags: CUInt = 0,
};

pub fn IWindowAPI() type {
    return struct {
        const Self = @This();

        openWindow: *const fn (WindowData) void = undefined,
        hasWindowClosed: *const fn () bool = undefined,
        getWindowData: *const fn () *WindowData = undefined,
        closeWindow: *const fn () void = undefined,

        showFPS: *const fn (CInt, CInt) void = undefined,
        toggleFullscreen: *const fn () void = undefined,
        toggleBorderlessWindowed: *const fn () void = undefined,

        pub fn init(initImpl: *const fn (*IWindowAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }
    };
}

pub fn IRenderAPI() type {
    return struct {
        const Self = @This();

        /// Set rendering offset
        setOffset: *const fn (Vector2f) void = undefined,
        /// Adds given offset to actual offset of the rendering engine
        addOffset: *const fn (Vector2f) void = undefined,
        /// Set the projection and clear color of the base view
        setBaseProjection: *const fn (Projection) void = undefined,

        /// Loads image data from file system and create new texture data loaded into GPU
        /// @param textureData The texture DAO. Sets binding, width and height to the DAO
        loadTexture: *const fn (
            resource: String,
            is_mipmap: bool,
            filter: TextureFilter,
            wrap: TextureWrap,
        ) TextureBinding = undefined,
        /// Disposes the texture with given texture binding id from GPU memory
        /// @param textureId binding identifier of the texture to dispose.
        disposeTexture: *const fn (BindingId) void = undefined,

        createRenderTexture: *const fn (width: CInt, height: CInt) RenderTextureBinding = undefined,
        disposeRenderTexture: *const fn (BindingId) void = undefined,
        /// create new shader from given shader data and load it to GPU
        createShader: *const fn (
            vertex_shader: String,
            fragment_shade: String,
            file: bool,
        ) BindingId = undefined,
        /// Dispose the shader with the given binding identifier (shaderId) from GPU
        /// @param shaderId identifier of the shader to dispose.
        disposeShader: *const fn (BindingId) void = undefined,
        /// Set the active sprite rendering shader. Note that the shader program must have been created before with createShader.
        /// @param shaderId The instance identifier of the shader.
        setActiveShader: *const fn (BindingId) void = undefined,

        // TODO example: https://www.raylib.com/examples/shaders/loader.html?name=shaders_julia_set
        // setUniformFloat: *const fn (String, Float) void = undefined,
        // setUniformVec2: *const fn (String, *Vector2f) void = undefined,
        // setUniformVec3: *const fn (String, *Vector3f) void = undefined,
        // setUniformColorVec4: *const fn (String, *Vector4f) void = undefined,

        bindTexture: *const fn (String, BindingId) void = undefined,
        /// Start rendering to the given RenderTextureData or to the screen if no binding index is given
        /// Uses Projection to update camera projection and clear target before start rendering
        startRendering: *const fn (texture: ?BindingId, projection: ?*const Projection) void = undefined,
        /// This renders a given RenderTextureData (BindingId) to the actual render target that can be
        /// rendering texture or the screen
        renderTexture: *const fn (
            texture: BindingId,
            transform: *const TransformData,
            render_data: ?RenderData,
        ) void = undefined,
        // TODO
        renderSprite: *const fn (
            sprite: *const SpriteData,
            transform: *const TransformData,
            render_data: ?RenderData,
            offset: ?Vector2f,
        ) void = undefined,
        /// This is called form the firefly API to notify the end of rendering for the actual render target (RenderTextureData).
        /// switches back to screen rendering
        endRendering: *const fn () void = undefined,

        printDebug: *const fn (*StringBuffer) void = undefined,

        deinit: *const fn () void = undefined,

        pub fn init(initImpl: *const fn (*IRenderAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }
    };
}
