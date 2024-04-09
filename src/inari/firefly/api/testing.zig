const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;

const StringBuffer = utils.StringBuffer;
const String = utils.String;
const FFAPIError = api.FFAPIError;
const DynArray = utils.DynArray;
const BindingId = api.BindingId;
const NO_BINDING = api.NO_BINDING;
const TextureBinding = api.TextureBinding;
const TextureFilter = api.TextureFilter;
const TextureWrap = api.TextureWrap;
const RenderTextureBinding = api.RenderTextureBinding;
const ShaderBinding = api.ShaderBinding;
const PosI = utils.PosI;
const CInt = utils.CInt;
const Vector2f = utils.Vector2f;
const Vector3f = utils.Vector3f;
const Vector4f = utils.Vector4f;
const PosF = utils.PosF;
const RectF = utils.RectF;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const Projection = api.Projection;
const IRenderAPI = api.IRenderAPI;
const Float = utils.Float;
const ShapeType = api.ShapeType;

// Singleton Debug RenderAPI
var singletonDebugRenderAPI: IRenderAPI() = undefined;
pub fn createTestRenderAPI() !IRenderAPI() {
    if (DebugRenderAPI.initialized) {
        return singletonDebugRenderAPI;
    }
    singletonDebugRenderAPI = IRenderAPI().init(DebugRenderAPI.initImpl);
    return singletonDebugRenderAPI;
}

/// This implementation of RenderAPI can be used for debugging
///
/// var render_api = RenderAPI().init(DebugRenderAPI.initImpl);
/// or
/// var render_api = RenderAPI().init(DebugRenderAPI.initScreen(800, 600).initImpl);
pub const DebugRenderAPI = struct {
    pub var screen_width: CInt = 800;
    pub var screen_height: CInt = 600;
    var initialized = false;

    const defaultOffset = Vector2f{ 0, 0 };
    //const defaultRenderData = RenderData{};

    const RenderAction = struct {
        texture_binding: BindingId,
        texture_bounds: ?RectF = null,
        position: PosF,
        pivot: ?PosF = null,
        scale: ?PosF = null,
        rotation: ?Float = null,
        tint_color: ?Color = null,
        blend_mode: ?BlendMode = null,

        pub fn format(
            self: RenderAction,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            if (self.texture_bounds) |_| {
                try writer.print("render sprite --> texture_binding={any}, texture_bounds={any}, position={any}, pivot={any}, scale={any}, rotation={any}, tint_color={any}, blend_mode={any}", self);
            } else {
                try writer.print("render texture --> texture_binding={any}, texture_bounds={any}, position={any}, pivot={any}, scale={any}, rotation={any}, tint_color={any}, blend_mode={any}", self);
            }
        }
    };
    const ShaderData = struct {
        binding: BindingId,
        vertex_shader: ?String,
        fragment_shader: ?String,
        file: bool = true,

        pub fn format(
            self: ShaderData,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print(
                "ShaderData[ binding:{d}, vert:{?s}, frag:{?s}, file_resource:{any} ]",
                self,
            );
        }
    };

    var textures: DynArray(TextureBinding) = undefined;
    var renderTextures: DynArray(RenderTextureBinding) = undefined;
    var shaders: DynArray(ShaderData) = undefined;

    var renderActionQueue: DynArray(RenderAction) = undefined;

    var currentProjection: Projection = Projection{};
    var currentRenderTexture: ?BindingId = null;
    var currentShader: ?BindingId = null;
    var currentOffset: Vector2f = defaultOffset;

    fn initImpl(interface: *IRenderAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        textures = DynArray(TextureBinding).new(api.ALLOC) catch unreachable;
        renderTextures = DynArray(RenderTextureBinding).new(api.ALLOC) catch unreachable;
        shaders = DynArray(ShaderData).new(api.ALLOC) catch unreachable;
        renderActionQueue = DynArray(RenderAction).new(api.ALLOC) catch unreachable;

        interface.setRenderBatch = setRenderBatch;
        interface.setOffset = setOffset;
        interface.addOffset = addOffset;

        interface.loadTexture = loadTexture;
        interface.disposeTexture = disposeTexture;
        interface.createRenderTexture = createRenderTexture;
        interface.disposeRenderTexture = disposeRenderTexture;
        interface.createShader = createShader;
        interface.disposeShader = disposeShader;

        interface.startRendering = startRendering;
        interface.setActiveShader = setActiveShader;
        interface.renderTexture = renderTexture;
        interface.renderSprite = renderSprite;
        interface.endRendering = endRendering;

        interface.printDebug = printDebug;
        interface.deinit = deinit;

        DebugRenderAPI.currentRenderTexture = null;
        DebugRenderAPI.currentShader = null;
        DebugRenderAPI.currentOffset = defaultOffset;
    }

    fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        renderActionQueue.deinit();
        textures.deinit();
        renderTextures.deinit();
        shaders.deinit();
    }

    fn setRenderBatch(_: ?CInt, _: ?CInt) void {}

    pub fn screenWidth() CInt {
        return screen_width;
    }

    pub fn screenHeight() CInt {
        return screen_height;
    }

    pub fn showFPS(pos: *PosI) void {
        std.debug.print("showFPS: {any}\n", .{pos.*});
    }

    pub fn loadTexture(
        _: String,
        _: bool,
        _: TextureFilter,
        _: TextureWrap,
    ) TextureBinding {
        var binding = TextureBinding{
            .width = 1,
            .height = 1,
        };
        var id = textures.add(binding);
        var b = textures.get(id).?;
        b.id = id;
        return b.*;
    }

    pub fn disposeTexture(binding: BindingId) void {
        textures.delete(binding);
    }

    pub fn createRenderTexture(projection: *Projection) RenderTextureBinding {
        var binding = RenderTextureBinding{
            .id = renderTextures.nextFreeSlot(),
            .width = @intFromFloat(projection.plain[2]),
            .height = @intFromFloat(projection.plain[3]),
        };
        _ = renderTextures.add(binding);
        return binding;
    }

    pub fn disposeRenderTexture(id: BindingId) void {
        if (id != NO_BINDING) {
            renderTextures.delete(id);
        }
    }

    fn createShader(vertex_shader: ?String, fragment_shader: ?String, file: bool) ShaderBinding {
        return .{
            .id = shaders.add(ShaderData{
                .binding = shaders.nextFreeSlot(),
                .vertex_shader = vertex_shader,
                .fragment_shader = fragment_shader,
                .file = file,
            }),

            ._set_uniform_float = setShaderValueFloat,
            ._set_uniform_vec2 = setShaderValueVec2,
            ._set_uniform_vec3 = setShaderValueVec3,
            ._set_uniform_vec4 = setShaderValueVec4,
            ._set_uniform_texture = setShaderValueTex,
        };
    }

    fn setShaderValueFloat(shader_id: BindingId, name: String, val: *Float) bool {
        _ = shader_id;
        _ = name;
        _ = val;
        return true;
    }
    fn setShaderValueVec2(shader_id: BindingId, name: String, val: *Vector2f) bool {
        _ = shader_id;
        _ = name;
        _ = val;
        return true;
    }
    fn setShaderValueVec3(shader_id: BindingId, name: String, val: *Vector3f) bool {
        _ = shader_id;
        _ = name;
        _ = val;
        return true;
    }
    fn setShaderValueVec4(shader_id: BindingId, name: String, val: *Vector4f) bool {
        _ = shader_id;
        _ = name;
        _ = val;
        return true;
    }
    fn setShaderValueTex(shader_id: BindingId, name: String, val: BindingId) bool {
        _ = shader_id;
        _ = name;
        _ = val;
        return true;
    }

    pub fn disposeShader(id: BindingId) void {
        if (id != NO_BINDING) {
            shaders.delete(id);
        }
    }

    pub fn startRendering(textureId: ?BindingId, projection: *Projection) void {
        if (textureId) |id| {
            currentRenderTexture = id;
        }

        currentProjection = projection.*;
    }

    pub fn setActiveShader(shaderId: BindingId) void {
        currentShader = shaderId;
    }

    pub fn setOffset(offset: Vector2f) void {
        currentOffset = offset;
    }

    pub fn addOffset(offset: Vector2f) void {
        currentOffset[0] += offset[0];
        currentOffset[1] += offset[1];
    }

    pub fn renderTexture(
        texture_id: BindingId,
        position: PosF,
        pivot: ?PosF,
        scale: ?PosF,
        rotation: ?Float,
        tint_color: ?Color,
        blend_mode: ?BlendMode,
    ) void {
        _ = renderActionQueue.add(RenderAction{
            .texture_binding = texture_id,
            .position = position,
            .pivot = pivot,
            .scale = scale,
            .rotation = rotation,
            .tint_color = tint_color,
            .blend_mode = blend_mode,
        });
    }

    pub fn renderSprite(
        texture_id: BindingId,
        texture_bounds: RectF,
        position: PosF,
        pivot: ?PosF,
        scale: ?PosF,
        rotation: ?Float,
        tint_color: ?Color,
        blend_mode: ?BlendMode,
        _: ?[]const Vector2f,
    ) void {
        _ = renderActionQueue.add(RenderAction{
            .texture_binding = texture_id,
            .texture_bounds = texture_bounds,
            .position = position,
            .pivot = pivot,
            .scale = scale,
            .rotation = rotation,
            .tint_color = tint_color,
            .blend_mode = blend_mode,
        });
    }

    fn renderShape(
        _: ShapeType,
        _: []Float,
        _: bool,
        _: ?Float,
        _: PosF,
        _: Color,
        _: ?BlendMode,
        _: ?PosF,
        _: ?PosF,
        _: ?Float,
        _: ?Color,
        _: ?Color,
        _: ?Color,
        _: ?[]const PosF,
    ) void {}

    pub fn endRendering() void {
        currentRenderTexture = null;
    }

    pub fn printDebug(buffer: *StringBuffer) void {
        buffer.append("\n******************************\n");
        buffer.append("Debug Rendering API State:\n");

        buffer.append(" loaded textures:\n");
        var texitr = DebugRenderAPI.textures.iterator();
        while (texitr.next()) |tex| {
            buffer.print("   {any}\n", .{tex});
        }

        buffer.append(" loaded render textures:\n");
        var rtexitr = DebugRenderAPI.renderTextures.iterator();
        while (rtexitr.next()) |tex| {
            buffer.print("   {any}\n", .{tex});
        }

        buffer.append(" loaded shaders:\n");
        var sitr = DebugRenderAPI.shaders.iterator();
        while (sitr.next()) |s| {
            buffer.print("   {any}\n", .{s});
        }

        buffer.append(" current state:\n");

        buffer.print("   {any}\n", .{DebugRenderAPI.currentProjection});
        buffer.print("   {any}\n", .{DebugRenderAPI.currentRenderTexture});
        buffer.print("   {any}\n", .{DebugRenderAPI.currentShader});
        buffer.print("   Offset: {any}\n", .{DebugRenderAPI.currentOffset});

        buffer.append(" render actions:\n");
        var aitr = DebugRenderAPI.renderActionQueue.iterator();
        while (aitr.next()) |a| {
            buffer.print("   {any}\n", .{a});
        }
    }
};

// //////////////////////////////////////////////////////////////
// //// TESTING RenderAPI
// //////////////////////////////////////////////////////////////

test "RenderAPI debug init" {
    try inari.firefly.initTesting();
    defer inari.firefly.deinit();

    var tex_1_binding = api.rendering.loadTexture("t1", false, TextureFilter.TEXTURE_FILTER_POINT, TextureWrap.TEXTURE_WRAP_CLAMP);
    try std.testing.expect(tex_1_binding.id != NO_BINDING);

    var t2: RenderTextureBinding = api.rendering.createRenderTexture(10, 10);
    try std.testing.expect(t2.id != NO_BINDING);

    api.rendering.renderSprite(
        tex_1_binding.id,
        &RectF{ 0, 0, 32, 32 },
        &PosF{ 10, 100 },
        utils.getNullPointer(PosF),
        utils.getNullPointer(PosF),
        utils.getNullPointer(Float),
        utils.getNullPointer(Color),
        null,
    );

    // test creating another DebugGraphics will get the same instance back
    var debugGraphics2 = try createTestRenderAPI();
    try std.testing.expectEqual(api.rendering, debugGraphics2);
    var offset = Vector2f{ 10, 10 };
    debugGraphics2.setOffset(offset);
    debugGraphics2.renderSprite(
        tex_1_binding.id,
        &RectF{ 0, 0, 32, 32 },
        &PosF{ 10, 100 },
        utils.getNullPointer(PosF),
        utils.getNullPointer(PosF),
        utils.getNullPointer(Float),
        utils.getNullPointer(Color),
        null,
    );

    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    const api_out: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\   TextureBinding[ id:0, width:1, height:1 ]
        \\ loaded render textures:
        \\   RenderTextureBinding[ bind:0, w:10, h:10 ]
        \\ loaded shaders:
        \\ current state:
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   null
        \\   Offset: { 1.0e+01, 1.0e+01 }
        \\ render actions:
        \\   render sprite --> texture_binding=0, texture_bounds={ 0.0e+00, 0.0e+00, 3.2e+01, 3.2e+01 }, position={ 1.0e+01, 1.0e+02 }, pivot=null, scale=null, rotation=null, tint_color=null, blend_mode=null
        \\   render sprite --> texture_binding=0, texture_bounds={ 0.0e+00, 0.0e+00, 3.2e+01, 3.2e+01 }, position={ 1.0e+01, 1.0e+02 }, pivot=null, scale=null, rotation=null, tint_color=null, blend_mode=null
        \\
    ;
    api.rendering.printDebug(&sb);
    //std.debug.print("\n{s}", .{sb.toString()});
    try std.testing.expectEqualStrings(api_out, sb.toString());
}

// test "TransformData operations" {
//     var td1 = TransformData{
//         .position = Vector2f{ 10, 10 },
//         .pivot = Vector2f{ 0, 0 },
//         .scale = Vector2f{ 1, 1 },
//         .rotation = 2,
//     };
//     var td2 = TransformData{
//         .position = Vector2f{ 10, 10 },
//         .pivot = Vector2f{ 1, 1 },
//         .scale = Vector2f{ 2, 2 },
//         .rotation = 5,
//     };
//     var td3 = TransformData{};
//     td3.set(td1);

//     var sb = StringBuffer.init(std.testing.allocator);
//     defer sb.deinit();
//     sb.print("{any}", .{td3});
//     try std.testing.expectEqualStrings(
//         "TransformData[ pos:{ 1.0e+01, 1.0e+01 }, pivot:{ 0.0e+00, 0.0e+00 }, scale:{ 1.0e+00, 1.0e+00 }, rot:2 ]",
//         sb.toString(),
//     );

//     sb.clear();
//     td3.add(td2);
//     sb.print("{any}", .{td3});
//     try std.testing.expectEqualStrings(
//         "TransformData[ pos:{ 2.0e+01, 2.0e+01 }, pivot:{ 1.0e+00, 1.0e+00 }, scale:{ 3.0e+00, 3.0e+00 }, rot:7 ]",
//         sb.toString(),
//     );
// }
