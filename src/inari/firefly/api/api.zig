const std = @import("std");
const Allocator = std.mem.Allocator;

const rendering = @import("rendering_api.zig");
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

// public API
pub const utils = @import("../../utils/utils.zig");
pub const Component = @import("Component.zig");
pub const System = @import("System.zig");
pub const Timer = @import("Timer.zig");
pub const Entity = @import("Entity.zig");
pub const Asset = @import("Asset.zig");
pub const rendering_api = @import("rendering_api.zig");
pub const Index = usize;
pub const UNDEF_INDEX = std.math.maxInt(Index);
pub const BindingIndex = usize;
pub const NO_BINDING: BindingIndex = std.math.maxInt(usize);

pub const UpdateEvent = struct {};
pub const UpdateListener = *const fn (*const UpdateEvent) void;
pub const RenderEventType = enum { PRE_RENDER, RENDER, POST_RENDER };
pub const RenderEvent = struct { type: RenderEventType };
pub const RenderListener = *const fn (*const RenderEvent) void;

// public API constants
pub var COMPONENT_ALLOC: Allocator = undefined;
pub var ENTITY_ALLOC: Allocator = undefined;
pub var ALLOC: Allocator = undefined;
pub var RENDERING_API: rendering.RenderAPI() = undefined;

// private state
var UPDATE_EVENT_DISPATCHER: EventDispatch(*const UpdateEvent) = undefined;
var RENDER_EVENT_DISPATCHER: EventDispatch(*const RenderEvent) = undefined;
var UPDATE_EVENT = UpdateEvent{};
var RENDER_EVENT = RenderEvent{
    .type = RenderEventType.PRE_RENDER,
};

// initialization
var initialized = false;
pub fn init(component_allocator: Allocator, entity_allocator: Allocator, allocator: Allocator) !void {
    defer initialized = true;
    if (initialized)
        return;

    COMPONENT_ALLOC = component_allocator;
    ENTITY_ALLOC = entity_allocator;
    ALLOC = allocator;

    try utils.aspect.init(allocator);

    // TODO make this configurable
    RENDERING_API = try rendering.createDebugRenderAPI(allocator);

    UPDATE_EVENT_DISPATCHER = EventDispatch(*const UpdateEvent).init(allocator);
    RENDER_EVENT_DISPATCHER = EventDispatch(*const RenderEvent).init(allocator);

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

    UPDATE_EVENT_DISPATCHER.deinit();
    RENDER_EVENT_DISPATCHER.deinit();

    Timer.deinit();
    Component.deinit();
    RENDERING_API.deinit();
    utils.aspect.deinit();
}

pub fn subscribeUpdate(listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.register(listener);
}

pub fn subscribeUpdateAt(index: usize, listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.register(index, listener);
}

pub fn unsubscribeUpdate(listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.unregister(listener);
}

pub fn subscribeRender(listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.register(listener);
}

pub fn subscribeRenderAt(index: usize, listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.register(index, listener);
}

pub fn unsubscribeRender(listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.unregister(listener);
}

/// Performs a tick.Update the Timer, notify UpdateEvent, notify Pre-Render, Render, Post-Render events
pub fn tick() void {
    Timer.tick();
    UPDATE_EVENT_DISPATCHER.notify(&UPDATE_EVENT);

    RENDER_EVENT.type = RenderEventType.PRE_RENDER;
    RENDER_EVENT_DISPATCHER.notify(&RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.RENDER;
    RENDER_EVENT_DISPATCHER.notify(&RENDER_EVENT);

    RENDER_EVENT.type = RenderEventType.POST_RENDER;
    RENDER_EVENT_DISPATCHER.notify(&RENDER_EVENT);
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
    binding: BindingIndex = NO_BINDING,
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
    bindTexture: *const fn (String, BindingIndex) void = undefined,
};

pub const ShaderData = struct {
    binding: BindingIndex = NO_BINDING,
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
