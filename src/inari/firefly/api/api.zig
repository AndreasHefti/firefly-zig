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
const Index = utils.Index;
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
pub const AssetAspectGroup = asset.AssetAspectGroup;
pub const AssetKind = AssetAspectGroup.Kind;
pub const AssetAspect = AssetAspectGroup.Aspect;
pub const AssetTrait = asset.AssetTrait;
pub const Component = component;
pub const ComponentAspectGroup = component.ComponentAspectGroup;
pub const ComponentKind = ComponentAspectGroup.Kind;
pub const ComponentAspect = ComponentAspectGroup.Aspect;
pub const ComponentEvent = component.ComponentEvent;
pub const ComponentActionType = component.ActionType;
pub const ComponentListener = component.ComponentListener;
pub const System = system.System;
pub const Timer = timer;
pub const UpdateScheduler = timer.UpdateScheduler;
pub const Entity = entity.Entity;
pub const EntityCondition = entity.EntityCondition;
pub const EComponent = entity.EComponent;
pub const EComponentAspectGroup = entity.EComponentAspectGroup;
pub const EComponentKind = EComponentAspectGroup.Kind;
pub const EComponentAspect = EComponentAspectGroup.Aspect;
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

    UPDATE_EVENT_DISPATCHER = EventDispatch(UpdateEvent).new(ALLOC);
    RENDER_EVENT_DISPATCHER = EventDispatch(RenderEvent).new(ALLOC);
    VIEW_RENDER_EVENT_DISPATCHER = EventDispatch(ViewRenderEvent).new(ALLOC);

    if (initMode == InitMode.TESTING) {
        rendering = try testing.createTestRenderAPI();
    } else {
        //rendering = try testing.createTestRenderAPI();
        rendering = try @import("raylib/rendering.zig").createRenderAPI();
        window = try @import("raylib/window.zig").createWindowAPI();
    }

    try Component.init();
    Timer.init();
    system.init();

    // register api based components and entity components
    Component.registerComponent(Entity);
    Component.registerComponent(system.SystemComponent);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    system.deinit();
    Component.deinit();
    rendering.deinit();
    rendering = undefined;
    window = undefined;
    Timer.deinit();

    UPDATE_EVENT_DISPATCHER.deinit();
    RENDER_EVENT_DISPATCHER.deinit();
    VIEW_RENDER_EVENT_DISPATCHER.deinit();
}

//////////////////////////////////////////////////////////////
//// Update Event and Render Event declarations
//////////////////////////////////////////////////////////////

var UPDATE_EVENT_DISPATCHER: EventDispatch(UpdateEvent) = undefined;
var RENDER_EVENT_DISPATCHER: EventDispatch(RenderEvent) = undefined;
var VIEW_RENDER_EVENT_DISPATCHER: EventDispatch(ViewRenderEvent) = undefined;

pub const UpdateEvent = struct {};
pub const UpdateListener = *const fn (UpdateEvent) void;
pub const RenderEventType = enum {
    PRE_RENDER,
    RENDER,
    POST_RENDER,
};
pub const RenderEvent = struct { type: RenderEventType };
pub const RenderListener = *const fn (RenderEvent) void;
pub const ViewRenderEvent = struct {
    view_id: ?Index = null,
    layer_id: ?Index = null,
};
pub const ViewRenderListener = *const fn (ViewRenderEvent) void;

pub inline fn subscribeUpdate(listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.register(listener);
}

pub inline fn subscribeUpdateAt(index: usize, listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.register(index, listener);
}

pub inline fn unsubscribeUpdate(listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.unregister(listener);
}

pub inline fn subscribeRender(listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.register(listener);
}

pub inline fn subscribeRenderAt(index: usize, listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.registerInsert(index, listener);
}

pub inline fn unsubscribeRender(listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.unregister(listener);
}

pub inline fn subscribeViewRender(listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.register(listener);
}

pub inline fn subscribeViewRenderAt(index: usize, listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.registerInsert(index, listener);
}

pub inline fn unsubscribeViewRender(listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.unregister(listener);
}

pub inline fn update(event: UpdateEvent) void {
    UPDATE_EVENT_DISPATCHER.notify(event);
}

pub inline fn render(event: RenderEvent) void {
    RENDER_EVENT_DISPATCHER.notify(event);
}

pub inline fn renderView(event: ViewRenderEvent) void {
    VIEW_RENDER_EVENT_DISPATCHER.notify(event);
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

pub const ShaderBinding = struct {
    id: BindingId = NO_BINDING,

    _set_uniform_float: *const fn (BindingId, String, *Float) bool = undefined,
    _set_uniform_vec2: *const fn (BindingId, String, *Vector2f) bool = undefined,
    _set_uniform_vec3: *const fn (BindingId, String, *Vector3f) bool = undefined,
    _set_uniform_vec4: *const fn (BindingId, String, *Vector4f) bool = undefined,
    _set_uniform_texture: *const fn (BindingId, String, BindingId) bool = undefined,
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
        loadTexture: *const fn (resource: String, is_mipmap: bool, filter: TextureFilter, wrap: TextureWrap) TextureBinding = undefined,
        /// Disposes the texture with given texture binding id from GPU memory
        /// @param textureId binding identifier of the texture to dispose.
        disposeTexture: *const fn (BindingId) void = undefined,

        createRenderTexture: *const fn (width: CInt, height: CInt) RenderTextureBinding = undefined,
        disposeRenderTexture: *const fn (BindingId) void = undefined,
        /// create new shader from given shader data and load it to GPU
        createShader: *const fn (vertex_shader: ?String, fragment_shade: ?String, file: bool) ShaderBinding = undefined,
        /// Dispose the shader with the given binding identifier (shaderId) from GPU
        /// @param shaderId identifier of the shader to dispose.
        disposeShader: *const fn (BindingId) void = undefined,
        /// Set the active sprite rendering shader. Note that the shader program must have been created before with createShader.
        /// @param shaderId The instance identifier of the shader.
        setActiveShader: *const fn (BindingId) void = undefined,

        bindTexture: *const fn (String, BindingId) void = undefined,
        /// Start rendering to the given RenderTextureData or to the screen if no binding index is given
        /// Uses Projection to update camera projection and clear target before start rendering
        startRendering: *const fn (texture: ?BindingId, projection: ?Projection) void = undefined,
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
