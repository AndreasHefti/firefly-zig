const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;

const Allocator = std.mem.Allocator;
const asset = @import("asset.zig");
const component = @import("component.zig");
const system = @import("system.zig");
const timer = @import("timer.zig");
const entity = @import("entity.zig");
const control = @import("control.zig");

const String = utils.String;
const CString = utils.CString;
const Index = utils.Index;
const CInt = utils.CInt;
const CUInt = firefly.utils.CUInt;
const Float = utils.Float;
const PosF = utils.PosF;
const RectF = utils.RectF;
const Color = utils.Color;
const Vector2f = utils.Vector2f;
const Vector3f = utils.Vector3f;
const Vector4f = utils.Vector4f;
const StringBuffer = utils.StringBuffer;

fn dummyDeinit() void {}

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const RUN_ON = enum { RAYLIB, TEST };
pub const RUN_ON_SET: RUN_ON = RUN_ON.RAYLIB;

pub const InitContext = struct {
    component_allocator: Allocator,
    entity_allocator: Allocator,
    allocator: Allocator,
};

pub var COMPONENT_ALLOC: Allocator = undefined;
pub var ENTITY_ALLOC: Allocator = undefined;
pub var ALLOC: Allocator = undefined;

pub var rendering: IRenderAPI() = undefined;
pub var window: IWindowAPI() = undefined;
pub var input: IInputAPI() = undefined;
pub var audio: IAudioAPI() = undefined;

pub const Asset = asset.Asset;
pub const AssetAspectGroup = asset.AssetAspectGroup;
pub const AssetKind = AssetAspectGroup.Kind;
pub const AssetAspect = AssetAspectGroup.Aspect;
pub const AssetComponent = asset.AssetComponent;
pub const AssetTrait = asset.AssetTrait;

pub const Component = component;
pub const CReference = component.CReference;
pub const ComponentAspectGroup = component.ComponentAspectGroup;
pub const ComponentKind = ComponentAspectGroup.Kind;
pub const ComponentAspect = ComponentAspectGroup.Aspect;
pub const ComponentEvent = component.ComponentEvent;
pub const ComponentListener = component.ComponentListener;
pub const GroupAspect = component.GroupAspect;
pub const GroupKind = component.GroupKind;
pub const GroupAspectGroup = component.GroupAspectGroup;

pub const Condition = control.Condition;
pub const ConditionFunction = control.ConditionFunction;
pub const System = system.System;
pub const Timer = timer;
pub const UpdateScheduler = timer.UpdateScheduler;
pub const Entity = entity.Entity;
pub const EntityTypeCondition = entity.EntityTypeCondition;
pub const EMultiplier = entity.EMultiplier;
pub const EComponent = entity.EComponent;
pub const EComponentAspectGroup = entity.EComponentAspectGroup;
pub const EComponentKind = EComponentAspectGroup.Kind;
pub const EComponentAspect = EComponentAspectGroup.Aspect;
pub const ControlFunction = control.ControlFunction;
pub const ControlDispose = control.ControlDispose;
pub const ActionResult = control.ActionResult;
pub const UpdateActionFunction = control.UpdateActionFunction;
pub const UpdateActionCallback = control.UpdateActionCallback;
pub const Task = control.Task;
pub const TaskContext = control.TaskContext;
pub const TaskFunction = control.TaskFunction;
pub const TaskCallback = control.TaskCallback;
pub const Trigger = control.Trigger;
pub const ComponentControl = control.ComponentControl;
pub const ControlTypeTrait = control.ControlTypeTrait;
pub const ComponentControlType = control.ComponentControlType;
pub const Composite = component.Composite;
pub const CompositeLifeCycle = component.CompositeLifeCycle;
pub const CompositeTrait = component.CompositeTrait;
pub const OWNER_COMPOSITE_TASK_ATTRIBUTE = component.OWNER_COMPOSITE_TASK_ATTRIBUTE;
pub const CompositeObject = component.CompositeObject;
pub const State = control.State;
pub const StateEngine = control.StateEngine;
pub const EntityStateEngine = control.EntityStateEngine;
pub const EState = control.EState;

pub const BindingId = usize;
pub const Deinit = *const fn () void;

pub fn activateSystem(name: String, active: bool) void {
    system.activateSystem(name, active);
}

pub fn isSystemActive(name: String) bool {
    return system.isSystemActive(name);
}

//////////////////////////////////////////////////////////////
//// Initialization
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init(context: InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    COMPONENT_ALLOC = context.component_allocator;
    ENTITY_ALLOC = context.entity_allocator;
    ALLOC = context.allocator;

    UPDATE_EVENT_DISPATCHER = utils.EventDispatch(UpdateEvent).new(ALLOC);
    RENDER_EVENT_DISPATCHER = utils.EventDispatch(RenderEvent).new(ALLOC);
    VIEW_RENDER_EVENT_DISPATCHER = utils.EventDispatch(ViewRenderEvent).new(ALLOC);

    if (RUN_ON_SET == RUN_ON.RAYLIB) {
        rendering = try @import("raylib/rendering.zig").createRenderAPI();
        window = try @import("raylib/window.zig").createWindowAPI();
        input = try @import("raylib/input.zig").createInputAPI();
        audio = try @import("raylib/audio.zig").createInputAPI();
    } else {
        rendering = IRenderAPI().initDummy();
        window = IWindowAPI().initDummy();
        input = IInputAPI().initDummy();
        audio = IAudioAPI().initDummy();
    }

    NamePool.init();
    Component.init();
    Timer.init();
    system.init();

    // register api based components and entity components
    Component.registerComponent(Entity);
    EComponent.registerEntityComponent(EMultiplier);

    asset.init();
    control.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    asset.deinit();
    control.deinit();
    system.deinit();
    Component.deinit();
    rendering.deinit();
    rendering = undefined;
    window.deinit();
    window = undefined;
    input.deinit();
    input = undefined;
    audio.deinit();
    audio = undefined;
    Timer.deinit();
    NamePool.deinit();

    UPDATE_EVENT_DISPATCHER.deinit();
    RENDER_EVENT_DISPATCHER.deinit();
    VIEW_RENDER_EVENT_DISPATCHER.deinit();
}

//////////////////////////////////////////////////////////////
//// Name Pool used for none constant Strings not living
//// in zigs data mem. These can be de-allocated by call
//// or will be freed all on package deinit
//////////////////////////////////////////////////////////////

pub const NamePool = struct {
    var names: std.BufSet = undefined;
    var c_names: std.ArrayList([:0]const u8) = undefined;

    fn init() void {
        names = std.BufSet.init(ALLOC);
        c_names = std.ArrayList([:0]const u8).init(ALLOC);
    }

    fn deinit() void {
        names.deinit();

        freeCNames();
        c_names.deinit();
    }

    pub fn alloc(name: ?String) ?String {
        if (name) |n| {
            if (names.contains(n))
                return names.hash_map.getKey(n);

            names.insert(n) catch unreachable;
            //std.debug.print("************ NamePool names add: {s}\n", .{n});
            return names.hash_map.getKey(n);
        }
        return null;
    }

    pub fn concat(s1: String, s2: String, delimiter: ?String) String {
        const c = if (delimiter) |d|
            std.fmt.allocPrint(ALLOC, "{s}{s}{s}", .{ s1, s2, d }) catch unreachable
        else
            std.fmt.allocPrint(ALLOC, "{s}{s}", .{ s1, s2 }) catch unreachable;
        defer ALLOC.free(c);
        return alloc(c).?;
    }

    pub fn getCName(name: ?String) ?CString {
        if (name) |n| {
            const _n = firefly.api.ALLOC.dupeZ(u8, n) catch unreachable;
            c_names.append(_n) catch unreachable;
            //std.debug.print("************ NamePool c_names add: {s}\n", .{_n});
            return @ptrCast(_n);
        }
        return null;
    }

    pub fn freeCNames() void {
        for (c_names.items) |item|
            firefly.api.ALLOC.free(item);
        c_names.clearRetainingCapacity();
    }

    pub fn indexToString(index: ?Index) ?String {
        if (index) |i| {
            const str = std.fmt.allocPrint(ALLOC, "{d}", i) catch return null;
            defer ALLOC.free(str);
            names.insert(str) catch unreachable;
            return names.hash_map.getKey(str);
        }
        return null;
    }

    pub fn free(name: String) void {
        names.remove(name);
    }
};

//////////////////////////////////////////////////////////////
//// Attributes
//////////////////////////////////////////////////////////////

pub const Attributes = struct {
    c_ref1: ?Index = null,
    c_ref2: ?Index = null,
    c_ref3: ?Index = null,
    _map: std.StringHashMap(String),

    pub fn new() Attributes {
        return .{ ._map = std.StringHashMap(String).init(ALLOC) };
    }

    pub fn of(attributes: anytype) ?Attributes {
        if (@typeInfo(@TypeOf(attributes)) == .Optional)
            if (attributes != null)
                return @as(Attributes, attributes.?);

        if (@typeInfo(@TypeOf(attributes)) == .Struct) {
            if (@hasField(@TypeOf(attributes), "_map")) {
                return @as(Attributes, attributes);
            } else {
                var result: Attributes = .{ ._map = std.StringHashMap(String).init(ALLOC) };

                inline for (attributes) |v| {
                    result.set(v[0], v[1]);
                }

                return result;
            }
        }

        return null;
    }

    pub fn deinit(self: *Attributes) void {
        self.clear();
        self._map.deinit();
    }

    pub fn clear(self: *Attributes) void {
        var it = self._map.iterator();
        while (it.next()) |e| {
            ALLOC.free(e.key_ptr.*);
            ALLOC.free(e.value_ptr.*);
        }

        self._map.clearAndFree();
    }

    pub fn set(self: *Attributes, name: String, value: String) void {
        if (self._map.contains(name))
            self.remove(name);

        self._map.put(
            ALLOC.dupe(u8, name) catch unreachable,
            ALLOC.dupe(u8, value) catch unreachable,
        ) catch unreachable;
    }

    pub fn setAll(self: *Attributes, attributes: Attributes) void {
        var it = attributes._map.iterator();
        while (it.next()) |e|
            self.set(e.key_ptr.*, e.value_ptr.*);
    }

    pub fn get(self: Attributes, name: String) ?String {
        return self._map.get(name);
    }

    pub fn remove(self: *Attributes, name: String) void {
        if (self._map.fetchRemove(name)) |kv| {
            ALLOC.free(kv.key);
            ALLOC.free(kv.value);
        }
    }

    pub fn format(
        self: Attributes,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Attributes[ c_ref1:{any}, c_ref2:{any}, c_ref2:{any}, attrs: ",
            .{ self.c_ref1, self.c_ref2, self.c_ref3 },
        );
        var it = self._map.iterator();
        while (it.next()) |e| {
            try writer.print("{s}={s}, ", .{ e.key_ptr.*, e.value_ptr.* });
        }
        try writer.print("]", .{});
    }
};

//////////////////////////////////////////////////////////////
//// Convenient Functions
//////////////////////////////////////////////////////////////

pub fn loadFromFile(file_name: String) String {
    return std.fs.cwd().readFileAlloc(ALLOC, file_name, 1000000) catch unreachable;
}

pub fn writeToFile(file_name: String, text: String) void {
    const file: std.fs.File = try std.fs.cwd().createFile(
        file_name,
        .{ .read = true },
    ) catch unreachable;
    defer file.close();

    file.writeAll(text.*) catch unreachable;
}

pub fn loadFromJSONFile(file_name: String, comptime T: type) std.json.Parsed(T) {
    const json_text = loadFromFile(file_name);
    const parsed = std.json.parseFromSlice(
        T,
        ALLOC,
        json_text,
        .{ .ignore_unknown_fields = true },
    ) catch unreachable;
    return parsed;
}

pub fn writeToJSONFile(file_name: String, value: anytype) void {
    const json: String = std.json.stringifyAlloc(ALLOC, value, .{});
    defer ALLOC.free(json);
    writeToFile(file_name, json);
}

// pub fn encrypt(cipher: String, password: String) String {
//     //TODO
//     var ctx: std.crypto.core.aesAesEncryptCtx(std.crypto.core.aesAes256) = std.crypto.core.aes.Aes256.initEnc(password);
//     ctx.encrypt(dst: *[16]u8, src: *const [16]u8)
//     ctx.encryptWide(comptime count: usize, dst: *[16*count]u8, src: *const [16*count]u8)
// }

pub fn allocFloatArray(array: anytype) []Float {
    return firefly.api.ALLOC.dupe(Float, &array) catch unreachable;
}

pub fn allocVec2FArray(array: anytype) []const Vector2f {
    return firefly.api.ALLOC.dupe(Vector2f, &array) catch unreachable;
}

//////////////////////////////////////////////////////////////
//// Update Event and Render Event declarations
//////////////////////////////////////////////////////////////

var UPDATE_EVENT_DISPATCHER: utils.EventDispatch(UpdateEvent) = undefined;
var RENDER_EVENT_DISPATCHER: utils.EventDispatch(RenderEvent) = undefined;
var VIEW_RENDER_EVENT_DISPATCHER: utils.EventDispatch(ViewRenderEvent) = undefined;

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
    projection: ?*Projection = null,
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

    const BlendModeNameTable = [@typeInfo(BlendMode).Enum.fields.len][:0]const u8{
        "ALPHA",
        "ADDITIVE",
        "MULTIPLIED",
        "ADD_COLORS",
        "SUBTRACT_COLORS",
        "ALPHA_PREMULTIPLY",
        "CUSTOM",
        "CUSTOM_SEPARATE",
    };

    pub fn byName(name: ?String) ?BlendMode {
        if (name) |n| {
            for (0..BlendModeNameTable.len) |i| {
                if (firefly.utils.stringEquals(BlendModeNameTable[i], n))
                    return @enumFromInt(i);
            }
        }
        return null;
    }

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

pub const ShapeType = enum {
    POINT,
    LINE,
    RECTANGLE,
    CIRCLE,
    ARC,
    ELLIPSE,
    TRIANGLE,
};

pub const Projection = struct {
    clear_color: ?Color = .{ 0, 0, 0, 255 },
    position: PosF = .{ 0, 0 },
    width: Float = 0,
    height: Float = 0,
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
            "Projection[ clear_color:{any}, position:{any}, w:{any}, h{any}, pivot:{any}, zoom:{d}, rot:{d} ]",
            self,
        );
    }
};

pub const TextureBinding = struct {
    id: BindingId,
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
    id: BindingId,
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

pub const ShaderBinding = struct {
    id: BindingId,

    _set_uniform_float: *const fn (BindingId, CString, *Float) bool,
    _set_uniform_vec2: *const fn (BindingId, CString, *Vector2f) bool,
    _set_uniform_vec3: *const fn (BindingId, CString, *Vector3f) bool,
    _set_uniform_vec4: *const fn (BindingId, CString, *Vector4f) bool,
    _set_uniform_texture: *const fn (BindingId, CString, BindingId) bool,
};

pub const ImageBinding = struct {
    id: BindingId,
    data: ?*anyopaque,
    width: CInt,
    height: CInt,
    mipmaps: CInt,
    format: CInt,

    get_color_at: *const fn (BindingId, CInt, CInt) ?Color,
    set_color_at: *const fn (BindingId, CInt, CInt, Color) void,
};

pub fn IRenderAPI() type {
    return struct {
        const Self = @This();

        setRenderBatch: *const fn (
            buffer_number: ?CInt,
            max_buffer_elements: ?CInt,
        ) void = undefined,

        /// Set rendering offset
        setOffset: *const fn (Vector2f) void = undefined,
        /// Adds given offset to actual offset of the rendering engine
        addOffset: *const fn (Vector2f) void = undefined,

        /// Loads image data from file system and create new texture data loaded into GPU
        /// @param textureData The texture DAO. Sets binding, width and height to the DAO
        loadTexture: *const fn (resource: String, is_mipmap: bool, filter: TextureFilter, wrap: TextureWrap) TextureBinding = undefined,
        /// Disposes the texture with given texture binding id from GPU memory
        /// @param textureId binding identifier of the texture to dispose.
        disposeTexture: *const fn (BindingId) void = undefined,

        loadImageFromTexture: *const fn (BindingId) ImageBinding = undefined,
        loadImageRegionFromTexture: *const fn (BindingId, RectF) ImageBinding = undefined,
        loadImageFromFile: *const fn (String) ImageBinding = undefined,
        disposeImage: *const fn (BindingId) void = undefined,

        loadFont: *const fn (resource: String, size: ?CInt, char_num: ?CInt, code_points: ?CInt) BindingId = undefined,
        disposeFont: *const fn (BindingId) void = undefined,

        createRenderTexture: *const fn (projection: *Projection) RenderTextureBinding = undefined,
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
        startRendering: *const fn (texture_id: ?BindingId, projection: *Projection) void = undefined,
        /// This renders a given RenderTextureData (BindingId) to the actual render target that can be
        /// rendering texture or the screen
        renderTexture: *const fn (
            texture_id: BindingId,
            position: PosF,
            pivot: ?PosF,
            scale: ?PosF,
            rotation: ?Float,
            tint_color: ?Color,
            blend_mode: ?BlendMode,
        ) void = undefined,
        // TODO
        renderSprite: *const fn (
            texture_id: BindingId,
            texture_bounds: RectF,
            position: PosF,
            pivot: ?PosF,
            scale: ?PosF,
            rotation: ?Float,
            tint_color: ?Color,
            blend_mode: ?BlendMode,
            multiplier: ?[]const PosF,
        ) void = undefined,
        // TODO
        renderShape: *const fn (
            shape_type: ShapeType,
            vertices: []Float,
            fill: bool,
            thickness: ?Float,
            offset: PosF,
            color: Color,
            blend_mode: ?BlendMode,
            pivot: ?PosF,
            scale: ?PosF,
            rotation: ?Float,
            color1: ?Color,
            color2: ?Color,
            color3: ?Color,
        ) void = undefined,

        renderText: *const fn (
            font_id: ?BindingId,
            text: CString,
            position: PosF,
            pivot: ?PosF,
            rotation: ?Float,
            size: ?Float,
            char_spacing: ?Float,
            line_spacing: ?Float,
            tint_color: ?Color,
            blend_mode: ?BlendMode,
        ) void = undefined,

        /// This is called form the firefly API to notify the end of rendering for the actual render target (RenderTextureData).
        /// switches back to screen rendering
        endRendering: *const fn () void = undefined,

        printDebug: *const fn (*StringBuffer) void = undefined,

        deinit: Deinit = undefined,

        pub fn init(initImpl: *const fn (*IRenderAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        pub fn initDummy() Self {
            var self = Self{};
            self.deinit = dummyDeinit;
            return self;
        }
    };
}

pub const WindowFlag = enum(CUInt) {
    FLAG_VSYNC_HINT = 0x00000040, // Set to try enabling V-Sync on GPU
    FLAG_FULLSCREEN_MODE = 0x00000002, // Set to run program in fullscreen
    FLAG_WINDOW_RESIZABLE = 0x00000004, // Set to allow resizable window
    FLAG_WINDOW_UNDECORATED = 0x00000008, // Set to disable window decoration (frame and buttons)
    FLAG_WINDOW_HIDDEN = 0x00000080, // Set to hide window
    FLAG_WINDOW_MINIMIZED = 0x00000200, // Set to minimize window (iconify)
    FLAG_WINDOW_MAXIMIZED = 0x00000400, // Set to maximize window (expanded to monitor)
    FLAG_WINDOW_UNFOCUSED = 0x00000800, // Set to window non focused
    FLAG_WINDOW_TOPMOST = 0x00001000, // Set to window always on top
    FLAG_WINDOW_ALWAYS_RUN = 0x00000100, // Set to allow windows running while minimized
    FLAG_WINDOW_TRANSPARENT = 0x00000010, // Set to allow transparent framebuffer
    FLAG_WINDOW_HIGHDPI = 0x00002000, // Set to support HighDPI
    FLAG_WINDOW_MOUSE_PASSTHROUGH = 0x00004000, // Set to support mouse passthrough, only supported when FLAG_WINDOW_UNDECORATED
    FLAG_BORDERLESS_WINDOWED_MODE = 0x00008000, // Set to run program in borderless windowed mode
    FLAG_MSAA_4X_HINT = 0x00000020, // Set to try enabling MSAA 4X
    FLAG_INTERLACED_HINT = 0x00010000, // Set to try enabling interlaced video format (for V3D)
};

pub const WindowData = struct {
    width: CInt,
    height: CInt,
    fps: CInt,
    title: CString,
    flags: ?[]const WindowFlag = null,
};

pub fn IWindowAPI() type {
    return struct {
        const Self = @This();

        getCurrentMonitor: *const fn () CInt = undefined,
        getMonitorWidth: *const fn (CInt) CInt = undefined,
        getMonitorHeight: *const fn (CInt) CInt = undefined,

        openWindow: *const fn (WindowData) void = undefined,
        hasWindowClosed: *const fn () bool = undefined,
        getWindowData: *const fn () *WindowData = undefined,
        closeWindow: *const fn () void = undefined,

        showFPS: *const fn (CInt, CInt) void = undefined,
        toggleFullscreen: *const fn () void = undefined,
        toggleBorderlessWindowed: *const fn () void = undefined,
        setWindowFlags: *const fn ([]WindowFlag) void = undefined,

        deinit: Deinit = undefined,

        pub fn init(initImpl: *const fn (*IWindowAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        pub fn initDummy() Self {
            var self = Self{};
            self.deinit = dummyDeinit;
            return self;
        }
    };
}

pub const InputDevice = enum(u8) {
    KEYBOARD,
    GAME_PAD_1,
    GAME_PAD_2,
    MOUSE,
};

pub const InputActionType = enum(u8) {
    ON,
    OFF,
    TYPED,
    RELEASED,
};

pub const InputButtonType = enum(usize) {
    UP,
    RIGHT,
    DOWN,
    LEFT,

    ENTER,
    QUIT,
    FIRE_1,
    FIRE_2,
    PAUSE,

    BUTTON_A,
    BUTTON_B,
    BUTTON_C,
    BUTTON_D,

    BUTTON_W,
    BUTTON_X,
    BUTTON_Y,
    BUTTON_Z,

    BUTTON_0,
    BUTTON_1,
    BUTTON_2,
    BUTTON_3,
    BUTTON_4,
    BUTTON_5,
    BUTTON_6,
    BUTTON_7,
    BUTTON_8,
    BUTTON_9,
};

// Keyboard keys (US keyboard layout)
// NOTE: Use GetKeyPressed() to allow redefining
// required keys for alternative layouts
pub const KeyboardKey = enum(usize) {
    KEY_NULL = 0, // Key: NULL, used for no key pressed
    // Alphanumeric keys
    KEY_APOSTROPHE = 39, // Key: '
    KEY_COMMA = 44, // Key: ,
    KEY_MINUS = 45, // Key: -
    KEY_PERIOD = 46, // Key: .
    KEY_SLASH = 47, // Key: /
    KEY_ZERO = 48, // Key: 0
    KEY_ONE = 49, // Key: 1
    KEY_TWO = 50, // Key: 2
    KEY_THREE = 51, // Key: 3
    KEY_FOUR = 52, // Key: 4
    KEY_FIVE = 53, // Key: 5
    KEY_SIX = 54, // Key: 6
    KEY_SEVEN = 55, // Key: 7
    KEY_EIGHT = 56, // Key: 8
    KEY_NINE = 57, // Key: 9
    KEY_SEMICOLON = 59, // Key: ;
    KEY_EQUAL = 61, // Key: =
    KEY_A = 65, // Key: A | a
    KEY_B = 66, // Key: B | b
    KEY_C = 67, // Key: C | c
    KEY_D = 68, // Key: D | d
    KEY_E = 69, // Key: E | e
    KEY_F = 70, // Key: F | f
    KEY_G = 71, // Key: G | g
    KEY_H = 72, // Key: H | h
    KEY_I = 73, // Key: I | i
    KEY_J = 74, // Key: J | j
    KEY_K = 75, // Key: K | k
    KEY_L = 76, // Key: L | l
    KEY_M = 77, // Key: M | m
    KEY_N = 78, // Key: N | n
    KEY_O = 79, // Key: O | o
    KEY_P = 80, // Key: P | p
    KEY_Q = 81, // Key: Q | q
    KEY_R = 82, // Key: R | r
    KEY_S = 83, // Key: S | s
    KEY_T = 84, // Key: T | t
    KEY_U = 85, // Key: U | u
    KEY_V = 86, // Key: V | v
    KEY_W = 87, // Key: W | w
    KEY_X = 88, // Key: X | x
    KEY_Y = 89, // Key: Y | y
    KEY_Z = 90, // Key: Z | z
    KEY_LEFT_BRACKET = 91, // Key: [
    KEY_BACKSLASH = 92, // Key: '\'
    KEY_RIGHT_BRACKET = 93, // Key: ]
    KEY_GRAVE = 96, // Key: `
    // Function keys
    KEY_SPACE = 32, // Key: Space
    KEY_ESCAPE = 256, // Key: Esc
    KEY_ENTER = 257, // Key: Enter
    KEY_TAB = 258, // Key: Tab
    KEY_BACKSPACE = 259, // Key: Backspace
    KEY_INSERT = 260, // Key: Ins
    KEY_DELETE = 261, // Key: Del
    KEY_RIGHT = 262, // Key: Cursor right
    KEY_LEFT = 263, // Key: Cursor left
    KEY_DOWN = 264, // Key: Cursor down
    KEY_UP = 265, // Key: Cursor up
    KEY_PAGE_UP = 266, // Key: Page up
    KEY_PAGE_DOWN = 267, // Key: Page down
    KEY_HOME = 268, // Key: Home
    KEY_END = 269, // Key: End
    KEY_CAPS_LOCK = 280, // Key: Caps lock
    KEY_SCROLL_LOCK = 281, // Key: Scroll down
    KEY_NUM_LOCK = 282, // Key: Num lock
    KEY_PRINT_SCREEN = 283, // Key: Print screen
    KEY_PAUSE = 284, // Key: Pause
    KEY_F1 = 290, // Key: F1
    KEY_F2 = 291, // Key: F2
    KEY_F3 = 292, // Key: F3
    KEY_F4 = 293, // Key: F4
    KEY_F5 = 294, // Key: F5
    KEY_F6 = 295, // Key: F6
    KEY_F7 = 296, // Key: F7
    KEY_F8 = 297, // Key: F8
    KEY_F9 = 298, // Key: F9
    KEY_F10 = 299, // Key: F10
    KEY_F11 = 300, // Key: F11
    KEY_F12 = 301, // Key: F12
    KEY_LEFT_SHIFT = 340, // Key: Shift left
    KEY_LEFT_CONTROL = 341, // Key: Control left
    KEY_LEFT_ALT = 342, // Key: Alt left
    KEY_LEFT_SUPER = 343, // Key: Super left
    KEY_RIGHT_SHIFT = 344, // Key: Shift right
    KEY_RIGHT_CONTROL = 345, // Key: Control right
    KEY_RIGHT_ALT = 346, // Key: Alt right
    KEY_RIGHT_SUPER = 347, // Key: Super right
    KEY_KB_MENU = 348, // Key: KB menu
    // Keypad keys
    KEY_KP_0 = 320, // Key: Keypad 0
    KEY_KP_1 = 321, // Key: Keypad 1
    KEY_KP_2 = 322, // Key: Keypad 2
    KEY_KP_3 = 323, // Key: Keypad 3
    KEY_KP_4 = 324, // Key: Keypad 4
    KEY_KP_5 = 325, // Key: Keypad 5
    KEY_KP_6 = 326, // Key: Keypad 6
    KEY_KP_7 = 327, // Key: Keypad 7
    KEY_KP_8 = 328, // Key: Keypad 8
    KEY_KP_9 = 329, // Key: Keypad 9
    KEY_KP_DECIMAL = 330, // Key: Keypad .
    KEY_KP_DIVIDE = 331, // Key: Keypad /
    KEY_KP_MULTIPLY = 332, // Key: Keypad *
    KEY_KP_SUBTRACT = 333, // Key: Keypad -
    KEY_KP_ADD = 334, // Key: Keypad +
    KEY_KP_ENTER = 335, // Key: Keypad Enter
    KEY_KP_EQUAL = 336, // Key: Keypad =
    // Android key buttons
    KEY_BACK = 4, // Key: Android back button
    KEY_MENU = 5, // Key: Android menu button
    KEY_VOLUME_UP = 24, // Key: Android volume up button
    KEY_VOLUME_DOWN = 25, // Key: Android volume down button
};

// Mouse buttons
pub const MouseAction = enum(usize) {
    MOUSE_BUTTON_LEFT = 0, // Mouse button left
    MOUSE_BUTTON_RIGHT = 1, // Mouse button right
    MOUSE_BUTTON_MIDDLE = 2, // Mouse button middle (pressed wheel)
    MOUSE_BUTTON_SIDE = 3, // Mouse button side (advanced mouse device)
    MOUSE_BUTTON_EXTRA = 4, // Mouse button extra (advanced mouse device)
    MOUSE_BUTTON_FORWARD = 5, // Mouse button forward (advanced mouse device)
    MOUSE_BUTTON_BACK = 6, // Mouse button back (advanced mouse device)
};

pub const GamepadAction = enum(usize) {
    GAMEPAD_BUTTON_UNKNOWN = 0, // Unknown button, just for error checking
    GAMEPAD_BUTTON_LEFT_FACE_UP = 1, // Gamepad left DPAD up button
    GAMEPAD_BUTTON_LEFT_FACE_RIGHT = 2, // Gamepad left DPAD right button
    GAMEPAD_BUTTON_LEFT_FACE_DOWN = 3, // Gamepad left DPAD down button
    GAMEPAD_BUTTON_LEFT_FACE_LEFT = 4, // Gamepad left DPAD left button
    GAMEPAD_BUTTON_RIGHT_FACE_UP = 5, // Gamepad right button up (i.e. PS3: Triangle, Xbox: Y)
    GAMEPAD_BUTTON_RIGHT_FACE_RIGHT = 6, // Gamepad right button right (i.e. PS3: Circle, Xbox: B)
    GAMEPAD_BUTTON_RIGHT_FACE_DOWN = 7, // Gamepad right button down (i.e. PS3: Cross, Xbox: A)
    GAMEPAD_BUTTON_RIGHT_FACE_LEFT = 8, // Gamepad right button left (i.e. PS3: Square, Xbox: X)
    GAMEPAD_BUTTON_LEFT_TRIGGER_1 = 9, // Gamepad top/back trigger left (first), it could be a trailing button
    GAMEPAD_BUTTON_LEFT_TRIGGER_2 = 10, // Gamepad top/back trigger left (second), it could be a trailing button
    GAMEPAD_BUTTON_RIGHT_TRIGGER_1 = 11, // Gamepad top/back trigger right (one), it could be a trailing button
    GAMEPAD_BUTTON_RIGHT_TRIGGER_2 = 12, // Gamepad top/back trigger right (second), it could be a trailing button
    GAMEPAD_BUTTON_MIDDLE_LEFT = 13, // Gamepad center buttons, left one (i.e. PS3: Select)
    GAMEPAD_BUTTON_MIDDLE = 14, // Gamepad center buttons, middle one (i.e. PS3: PS, Xbox: XBOX)
    GAMEPAD_BUTTON_MIDDLE_RIGHT = 15, // Gamepad center buttons, right one (i.e. PS3: Start)
    GAMEPAD_BUTTON_LEFT_THUMB = 16, // Gamepad joystick pressed button left
    GAMEPAD_BUTTON_RIGHT_THUMB = 17, // Gamepad joystick pressed button right
};

pub const GamepadAxis = enum(CInt) {
    GAMEPAD_AXIS_LEFT_X = 0, // Gamepad left stick X axis
    GAMEPAD_AXIS_LEFT_Y = 1, // Gamepad left stick Y axis
    GAMEPAD_AXIS_RIGHT_X = 2, // Gamepad right stick X axis
    GAMEPAD_AXIS_RIGHT_Y = 3, // Gamepad right stick Y axis
    GAMEPAD_AXIS_LEFT_TRIGGER = 4, // Gamepad back trigger left, pressure level: [1..-1]
    GAMEPAD_AXIS_RIGHT_TRIGGER = 5, // Gamepad back trigger right, pressure level: [1..-1]
};

pub fn IInputAPI() type {
    return struct {
        const Self = @This();

        pub fn checkButtonPressed(self: Self, button: InputButtonType) bool {
            return self.checkButton(button, InputActionType.ON, null);
        }

        pub fn checkButtonOff(self: Self, button: InputButtonType) bool {
            return self.checkButton(button, InputActionType.OFF, null);
        }

        pub fn checkButtonReleased(self: Self, button: InputButtonType) bool {
            return self.checkButton(button, InputActionType.RELEASED, null);
        }

        pub fn checkButtonTyped(self: Self, button: InputButtonType) bool {
            return self.checkButton(button, InputActionType.TYPED, null);
        }

        pub fn setKeyMapping(self: Self, key: KeyboardKey, button: InputButtonType) void {
            self.setKeyButtonMapping(@intFromEnum(key), button);
        }

        // check the button type for specified action. Button type must have been mapped on one or many devices
        checkButton: *const fn (InputButtonType, InputActionType, ?InputDevice) bool = undefined,
        // get the current normalized action value between -1 and 1
        // if the action is digital on/off --> 0 <= off, > 0 = on
        getButtonValue: *const fn (InputButtonType, ?InputDevice) Float = undefined,
        // clears all mappings
        clear_mappings: *const fn () void = undefined,

        // KEYBOARD
        // Get key pressed (keycode), call it multiple times for keys queued, returns 0 when the queue is empty
        getKeyPressed: *const fn () CInt = undefined,
        // Get char pressed (unicode), call it multiple times for chars queued, returns 0 when the queue is empty
        getCharPressed: *const fn () CInt = undefined,
        // key mappings
        setKeyButtonMapping: *const fn (keycode: usize, InputButtonType) void = undefined,

        // GAMEPAD
        // Check if a gamepad is available
        isGamepadAvailable: *const fn (InputDevice) bool = undefined,
        // Get gamepad internal name id
        getGamepadName: *const fn (InputDevice) String = undefined,

        getGamepadAxisMovement: *const fn (InputDevice, GamepadAxis) Float = undefined,
        // gamepad mappings
        setGamepad1Mapping: *const fn (InputDevice) void = undefined,
        setGamepad2Mapping: *const fn (InputDevice) void = undefined,
        setGamepadButtonMapping: *const fn (InputDevice, GamepadAction, InputButtonType) void = undefined,

        // MOUSE
        getMousePosition: *const fn () PosF = undefined,
        getMouseDelta: *const fn () Vector2f = undefined,
        setMouseButtonMapping: *const fn (MouseAction, InputButtonType) void = undefined,

        deinit: Deinit = undefined,

        pub fn init(initImpl: *const fn (*IInputAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        pub fn initDummy() Self {
            var self = Self{};
            self.deinit = dummyDeinit;
            return self;
        }
    };
}

pub const SoundBinding = struct {
    id: BindingId,
    channel_1: ?BindingId = null,
    channel_2: ?BindingId = null,
    channel_3: ?BindingId = null,
    channel_4: ?BindingId = null,
    channel_5: ?BindingId = null,
    channel_6: ?BindingId = null,
};

pub fn IAudioAPI() type {
    return struct {
        const Self = @This();

        initAudioDevice: *const fn () void = undefined,
        closeAudioDevice: *const fn () void = undefined,
        setMasterVolume: *const fn (volume: Float) void = undefined,
        getMasterVolume: *const fn () Float = undefined,

        loadSound: *const fn (file: String, channels: usize) SoundBinding = undefined,
        disposeSound: *const fn (SoundBinding) void = undefined,
        playSound: *const fn (BindingId, volume: ?Float, pitch: ?Float, pan: ?Float) void = undefined,
        stopSound: *const fn (BindingId) void = undefined,
        pauseSound: *const fn (BindingId) void = undefined,
        resumeSound: *const fn (BindingId) void = undefined,
        isSoundPlaying: *const fn (BindingId) bool = undefined,
        setSoundVolume: *const fn (BindingId, volume: Float) void = undefined,
        setSoundPitch: *const fn (BindingId, pitch: Float) void = undefined,
        setSoundPan: *const fn (BindingId, pan: Float) void = undefined,

        loadMusic: *const fn (file: String) BindingId = undefined,
        disposeMusic: *const fn (BindingId) void = undefined,
        playMusic: *const fn (BindingId) void = undefined,
        stopMusic: *const fn (BindingId) void = undefined,
        pauseMusic: *const fn (BindingId) void = undefined,
        resumeMusic: *const fn (BindingId) void = undefined,
        isMusicPlaying: *const fn (BindingId) bool = undefined,
        setMusicVolume: *const fn (BindingId, volume: Float) void = undefined,
        setMusicPitch: *const fn (BindingId, pitch: Float) void = undefined,
        setMusicPan: *const fn (BindingId, pan: Float) void = undefined,
        getMusicTimeLength: *const fn (BindingId) Float = undefined,
        getMusicTimePlayed: *const fn (BindingId) Float = undefined,

        deinit: Deinit = undefined,

        pub fn init(initImpl: *const fn (*IAudioAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        pub fn initDummy() Self {
            var self = Self{};
            self.deinit = dummyDeinit;
            return self;
        }
    };
}
