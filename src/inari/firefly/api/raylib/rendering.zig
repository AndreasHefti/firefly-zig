const std = @import("std");
const inari = @import("../../../inari.zig");
const rl = @cImport(@cInclude("raylib.h"));
const rlgl = @cImport(@cInclude("rlgl.h"));

const utils = inari.utils;
const api = inari.firefly.api;

const String = utils.String;
const IRenderAPI = api.IRenderAPI;
const Vector2f = utils.Vector2f;
const Vector3f = utils.Vector3f;
const Vector4f = utils.Vector4f;
const PosF = utils.PosF;
const RectF = utils.RectF;
const Color = utils.Color;
const ShapeType = api.ShapeType;
const BlendMode = api.BlendMode;
const TextureBinding = api.TextureBinding;
const ShaderBinding = api.ShaderBinding;
const TextureFilter = api.TextureFilter;
const TextureWrap = api.TextureWrap;
const SpriteData = api.SpriteData;
const RenderTextureBinding = api.RenderTextureBinding;
const Projection = api.Projection;
const BindingId = api.BindingId;
const DynArray = utils.DynArray;
const StringBuffer = utils.StringBuffer;
const CUInt = utils.CUInt;
const CInt = utils.CInt;
const Float = utils.Float;
const NO_BINDING = api.NO_BINDING;
const EMPTY_STRING = utils.EMPTY_STRING;

const Texture2D = rl.Texture2D;
const Font = rl.Font;
const RenderTexture2D = rl.RenderTexture2D;
const Shader = rl.Shader;

var singleton: ?IRenderAPI() = null;
pub fn createRenderAPI() !IRenderAPI() {
    if (singleton == null)
        singleton = IRenderAPI().init(RaylibRenderAPI.initImpl);

    return singleton.?;
}

const DEFAULT_VERTEX_SHADER: String =
    \\#version 330
    \\
    \\layout (location = 0) in vec3 vertexPosition;
    \\in vec2 vertexTexCoord;            
    \\in vec4 vertexColor;
    \\out vec2 fragTexCoord;             
    \\out vec4 fragColor;                
    \\uniform mat4 mvp;            
    \\      
    \\void main()                        
    \\{             
    \\    fragTexCoord = vertexTexCoord; 
    \\    fragColor = vertexColor;       
    \\    gl_Position = mvp*vec4(vertexPosition, 1.0); 
    \\}
;

// TODO
const DEFAULT_FRAGMENT_SHADER: String = "";

const RaylibRenderAPI = struct {
    var initialized = false;

    fn initImpl(interface: *IRenderAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        active_clear_color = default_clear_color;

        textures = DynArray(Texture2D).new(api.ALLOC) catch unreachable;
        render_textures = DynArray(RenderTexture2D).new(api.ALLOC) catch unreachable;
        shaders = DynArray(Shader).new(api.ALLOC) catch unreachable;
        fonts = DynArray(Font).new(api.ALLOC) catch unreachable;

        interface.setRenderBatch = setRenderBatch;

        interface.setOffset = setOffset;
        interface.addOffset = addOffset;

        interface.loadTexture = loadTexture;
        interface.disposeTexture = disposeTexture;
        interface.loadFont = loadFont;
        interface.disposeFont = disposeFont;
        interface.createRenderTexture = createRenderTexture;
        interface.disposeRenderTexture = disposeRenderTexture;
        interface.createShader = createShader;
        interface.disposeShader = disposeShader;

        interface.setActiveShader = setActiveShader;
        interface.startRendering = startRendering;
        interface.renderTexture = renderTexture;
        interface.renderSprite = renderSprite;
        interface.renderShape = renderShape;
        interface.renderText = renderText;
        interface.endRendering = endRendering;

        interface.printDebug = printDebug;
        interface.deinit = deinit;
    }

    fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        var next = textures.slots.nextSetBit(0);
        while (next) |i| {
            disposeTexture(i);
            next = textures.slots.nextSetBit(i + 1);
        }
        textures.clear();
        textures.deinit();

        next = render_textures.slots.nextSetBit(0);
        while (next) |i| {
            disposeRenderTexture(i);
            next = render_textures.slots.nextSetBit(i + 1);
        }
        render_textures.clear();
        render_textures.deinit();

        next = shaders.slots.nextSetBit(0);
        while (next) |i| {
            disposeShader(i);
            next = shaders.slots.nextSetBit(i + 1);
        }
        shaders.clear();
        shaders.deinit();

        next = fonts.slots.nextSetBit(0);
        while (next) |i| {
            disposeFont(i);
            next = fonts.slots.nextSetBit(i + 1);
        }
        fonts.clear();
        fonts.deinit();

        singleton = null;
    }

    const default_offset = Vector2f{ 0, 0 };
    const default_tint_color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    const default_clear_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    const default_pivot = PosF{ 0, 0 };
    const default_blend_mode = BlendMode.ALPHA;

    var default_font_size: CInt = 32;
    var default_char_num: CInt = 95;

    var window_handle: ?api.WindowHandle = null;
    var textures: DynArray(Texture2D) = undefined;
    var fonts: DynArray(Font) = undefined;
    var render_textures: DynArray(RenderTexture2D) = undefined;
    var shaders: DynArray(Shader) = undefined;

    var active_shader: ?BindingId = null;
    var active_render_texture: ?BindingId = null;
    //var active_tint_color: rl.Color = undefined;
    var active_clear_color: ?rl.Color = undefined;

    var active_camera = rl.Camera2D{
        .offset = rl.Vector2{ .x = 0, .y = 0 },
        .target = rl.Vector2{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1,
    };

    var render_batch: ?rlgl.rlRenderBatch = null;

    fn setRenderBatch(buffer_number: ?CInt, max_buffer_elements: ?CInt) void {
        if (render_batch) |rb| {
            rlgl.rlUnloadRenderBatch(rb);
            render_batch = null;
        }
        render_batch = rlgl.rlLoadRenderBatch(buffer_number orelse 1, max_buffer_elements orelse 8192);
        rlgl.rlSetRenderBatchActive(&render_batch.?);
    }

    fn setOffset(offset: PosF) void {
        active_camera.offset = @bitCast(offset);
        rl.BeginMode2D(active_camera);
    }

    fn addOffset(offset: Vector2f) void {
        //rlgl.rlTranslatef(offset[0], offset[1], 0);
        active_camera.offset = @bitCast(@as(Vector2f, @bitCast(active_camera.offset)) + offset);
        rl.BeginMode2D(active_camera);
    }

    fn minusOffset(offset: Vector2f) void {
        //rlgl.rlTranslatef(-offset[0], -offset[1], 0);
        active_camera.offset = @bitCast(@as(Vector2f, @bitCast(active_camera.offset)) - offset);
        rl.BeginMode2D(active_camera);
    }

    fn loadTexture(
        resource: String,
        is_mipmap: bool,
        filter: TextureFilter,
        wrap: TextureWrap,
    ) TextureBinding {
        var tex = rl.LoadTexture(@ptrCast(resource));
        if (is_mipmap) {
            rl.GenTextureMipmaps(&tex);
        }

        rl.SetTextureFilter(tex, @intFromEnum(filter));
        rl.SetTextureWrap(tex, @intFromEnum(wrap));

        return TextureBinding{
            .width = @bitCast(tex.width),
            .height = @bitCast(tex.height),
            .id = textures.add(tex),
        };
    }

    fn disposeTexture(binding: BindingId) void {
        if (binding == NO_BINDING)
            return;

        if (textures.get(binding)) |tex| {
            rl.UnloadTexture(tex.*);
            textures.delete(binding);
        }
    }

    fn loadFont(resource: String, size: ?CInt, char_num: ?CInt, code_points: ?CInt) BindingId {
        return fonts.add(rl.LoadFontEx(
            @ptrCast(resource),
            size orelse default_font_size,
            code_points orelse 0,
            char_num orelse default_char_num,
        ));
    }

    fn disposeFont(binding: BindingId) void {
        if (binding == NO_BINDING)
            return;

        if (fonts.get(binding)) |f| {
            rl.UnloadFont(f.*);
            fonts.delete(binding);
        }
    }

    fn createRenderTexture(projection: *Projection) RenderTextureBinding {
        const tex = rl.LoadRenderTexture(
            @intFromFloat(projection.plain[2]),
            @intFromFloat(projection.plain[3]),
        );
        const id = render_textures.add(tex);
        return RenderTextureBinding{
            .id = id,
            .width = @intFromFloat(projection.plain[2]),
            .height = @intFromFloat(projection.plain[3]),
        };
    }

    fn disposeRenderTexture(id: BindingId) void {
        if (id == NO_BINDING)
            return;

        if (render_textures.get(id)) |tex| {
            rl.UnloadRenderTexture(tex.*);
            render_textures.delete(id);
        }
    }

    fn createShader(vertex_shader: ?String, fragment_shade: ?String, file: bool) ShaderBinding {
        var shader: Shader = undefined;
        if (file) {
            shader = rl.LoadShader(
                @ptrCast(vertex_shader orelse EMPTY_STRING),
                @ptrCast(fragment_shade orelse EMPTY_STRING),
            );
        } else {
            shader = rl.LoadShaderFromMemory(
                @ptrCast(vertex_shader orelse DEFAULT_VERTEX_SHADER),
                @ptrCast(fragment_shade orelse DEFAULT_FRAGMENT_SHADER),
            );
        }

        return .{
            .id = shaders.add(shader),
            ._set_uniform_float = setShaderValueFloat,
            ._set_uniform_vec2 = setShaderValueVec2,
            ._set_uniform_vec3 = setShaderValueVec3,
            ._set_uniform_vec4 = setShaderValueVec4,
            ._set_uniform_texture = setShaderValueTex,
        };
    }

    fn disposeShader(id: BindingId) void {
        if (id == NO_BINDING)
            return;

        if (shaders.get(id)) |shader| {
            rl.UnloadShader(shader.*);
            shaders.delete(id);
        }
    }

    fn setActiveShader(binding_id: BindingId) void {
        if (active_shader != null and active_shader.? != binding_id) {
            if (active_shader == NO_BINDING) {
                rl.EndShaderMode();
            } else {
                if (shaders.get(active_shader.?)) |shader| {
                    rl.BeginShaderMode(shader.*);
                }
            }
            active_shader = binding_id;
        }
    }

    fn startRendering(binding_id: ?BindingId, projection: *Projection) void {
        active_render_texture = binding_id;
        active_camera.offset.x = projection.plain[0];
        active_camera.offset.y = projection.plain[1];
        active_camera.target = @bitCast(projection.pivot);
        active_camera.rotation = projection.rotation;
        active_camera.zoom = projection.zoom;
        active_clear_color = if (projection.clear_color != null) @bitCast(projection.clear_color.?) else null;

        if (active_render_texture) |tex_id| {
            if (render_textures.get(tex_id)) |tex| {
                if (!rl.IsRenderTextureReady(tex.*))
                    @panic("Render Texture not ready!?");

                rl.BeginTextureMode(tex.*);
            }
        } else {
            rl.BeginDrawing();
        }
        rl.BeginMode2D(active_camera);

        if (active_clear_color) |cc|
            rl.ClearBackground(@bitCast(cc));

        rl.BeginBlendMode(@intFromEnum(default_blend_mode));
    }

    fn renderTexture(
        texture_id: BindingId,
        position: PosF,
        pivot: ?PosF,
        scale: ?PosF,
        rotation: ?Float,
        tint_color: ?Color,
        blend_mode: ?BlendMode,
    ) void {
        if (render_textures.get(texture_id)) |tex| {

            // set blend mode
            if (blend_mode) |bm|
                rl.BeginBlendMode(@intFromEnum(bm));

            if (scale) |s| {
                rl.DrawTexturePro(
                    tex.texture,
                    .{
                        .x = 0,
                        .y = 0,
                        .width = @floatFromInt(tex.texture.width),
                        .height = @floatFromInt(-tex.texture.height),
                    },
                    .{
                        .x = position[0],
                        .y = position[1],
                        .width = s[0] * @as(Float, @floatFromInt(tex.texture.width)),
                        .height = s[1] * @as(Float, @floatFromInt(tex.texture.height)),
                    },
                    @bitCast((pivot orelse default_pivot) * s),
                    rotation orelse 0,
                    if (tint_color) |tc| @bitCast(tc) else default_tint_color,
                );
            } else {
                rl.DrawTexturePro(
                    tex.texture,
                    .{
                        .x = 0,
                        .y = 0,
                        .width = @floatFromInt(tex.texture.width),
                        .height = @floatFromInt(-tex.texture.height),
                    },
                    .{
                        .x = position[0],
                        .y = position[1],
                        .width = @floatFromInt(tex.texture.width),
                        .height = @floatFromInt(-tex.texture.height),
                    },
                    if (scale) |s| @bitCast((pivot orelse default_pivot) * s) else @bitCast(pivot orelse default_pivot),
                    rotation orelse 0,
                    if (tint_color) |tc| @bitCast(tc) else default_tint_color,
                );
            }
        }
    }

    fn renderSprite(
        texture_id: BindingId,
        texture_bounds: RectF,
        position: PosF,
        pivot: ?PosF,
        scale: ?PosF,
        rotation: ?Float,
        tint_color: ?Color,
        blend_mode: ?BlendMode,
        multiplier: ?[]const PosF,
    ) void {
        if (textures.get(texture_id)) |tex| {

            // set blend mode
            if (blend_mode) |bm|
                rl.BeginBlendMode(@intFromEnum(bm));

            const tint: rl.Color = if (tint_color) |tc| @bitCast(tc) else default_tint_color;
            const _pivot: rl.Vector2 = if (scale) |s|
                @bitCast((pivot orelse default_pivot) * s)
            else
                @bitCast(pivot orelse default_pivot);

            var dest_rect = if (scale) |s|
                rl.Rectangle{
                    .x = 0,
                    .y = 0,
                    .width = @abs(texture_bounds[2]) * s[0],
                    .height = @abs(texture_bounds[3]) * s[1],
                }
            else
                rl.Rectangle{
                    .x = 0,
                    .y = 0,
                    .width = @abs(texture_bounds[2]),
                    .height = @abs(texture_bounds[3]),
                };

            if (multiplier) |m| {
                addOffset(position);
                for (0..m.len) |i| {
                    dest_rect.x = m[i][0];
                    dest_rect.y = m[i][1];
                    rl.DrawTexturePro(
                        tex.*,
                        @bitCast(texture_bounds),
                        dest_rect,
                        _pivot,
                        rotation orelse 0,
                        tint,
                    );
                }
                minusOffset(position);
            } else {
                dest_rect.x = position[0];
                dest_rect.y = position[1];
                rl.DrawTexturePro(
                    tex.*,
                    @bitCast(texture_bounds),
                    dest_rect,
                    _pivot,
                    rotation orelse 0,
                    tint,
                );
            }
        }
    }

    fn renderShape(
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
        multiplier: ?[]const PosF,
    ) void {

        // set blend mode
        if (blend_mode) |bm| {
            rl.BeginBlendMode(@intFromEnum(bm));
        }

        // apply translation functions if needed
        // TODO check if this must be done for each when multiplier is present
        addOffset(offset);
        if (scale != null or rotation != null) {
            rlgl.rlPushMatrix();
            if (pivot) |p| rlgl.rlTranslatef(p[0], p[1], 0);
            if (scale) |s| rlgl.rlScalef(s[0], s[1], 0);
            if (rotation) |r| rlgl.rlRotatef(r, 0, 0, 1);
            if (pivot) |p| rlgl.rlTranslatef(-p[0], -p[1], 0);
        }

        switch (shape_type) {
            ShapeType.POINT => renderPoint(vertices, color, multiplier),
            ShapeType.LINE => renderLine(vertices, color, multiplier),
            ShapeType.RECTANGLE => renderRect(vertices, color, multiplier, color1, color2, color3, fill, thickness),
            ShapeType.TRIANGLE => renderTriangles(vertices, color, multiplier, fill),
            ShapeType.CIRCLE => renderCircle(vertices, color, color1, multiplier, fill),
            ShapeType.ARC => renderArc(vertices, color, multiplier, fill),
            ShapeType.ELLIPSE => renderEllipse(vertices, color, multiplier, fill),
        }

        // dispose translation functions if needed
        if (scale != null or rotation != null) {
            rlgl.rlPopMatrix();
        }
        minusOffset(offset);
    }

    fn renderText(
        font_id: ?BindingId,
        text: String,
        position: PosF,
        pivot: ?PosF,
        rotation: ?Float,
        size: ?Float,
        char_spacing: ?Float,
        line_spacing: ?Float,
        tint_color: ?Color,
        blend_mode: ?BlendMode,
    ) void {
        var font = rl.GetFontDefault();
        if (font_id) |fid| {
            if (fonts.get(fid)) |f| font = f.*;
        }

        if (blend_mode) |bm| {
            rl.BeginBlendMode(@intFromEnum(bm));
        }

        if (line_spacing) |ls| {
            rl.SetTextLineSpacing(@as(CInt, @intFromFloat(ls)));
        }

        rl.DrawTextPro(
            font,
            @ptrCast(text),
            rl.Vector2{ .x = position[0], .y = position[1] },
            @bitCast(pivot orelse default_pivot),
            rotation orelse 0,
            size orelse 8,
            char_spacing orelse 10,
            if (tint_color) |tc| @bitCast(tc) else default_tint_color,
        );
    }

    fn endRendering() void {
        if (active_render_texture) |_| {
            rl.EndTextureMode();
            active_render_texture = null;
        } else {
            rl.DrawFPS(0, 0);
            rl.EndMode2D();
            rl.EndDrawing();
        }

        // TODO something else?
    }

    fn setShaderValueFloat(shader_id: BindingId, name: String, val: *Float) bool {
        return setShaderValue(shader_id, name, val, rl.SHADER_UNIFORM_FLOAT);
    }
    fn setShaderValueVec2(shader_id: BindingId, name: String, val: *Vector2f) bool {
        return setShaderValue(shader_id, name, val, rl.SHADER_UNIFORM_VEC2);
    }
    fn setShaderValueVec3(shader_id: BindingId, name: String, val: *Vector3f) bool {
        return setShaderValue(shader_id, name, val, rl.SHADER_UNIFORM_VEC3);
    }
    fn setShaderValueVec4(shader_id: BindingId, name: String, val: *Vector4f) bool {
        return setShaderValue(shader_id, name, val, rl.SHADER_UNIFORM_VEC4);
    }
    fn setShaderValueTex(shader_id: BindingId, name: String, val: BindingId) bool {
        if (render_textures.get(val)) |rt| {
            return setShaderValue(shader_id, name, rt, rl.SHADER_UNIFORM_SAMPLER2D);
        }
        return false;
    }

    fn setShaderValue(shader_id: BindingId, name: String, val: anytype, v_type: CInt) bool {
        if (shaders.get(shader_id)) |shader| {
            const location = rl.GetShaderLocation(shader.*, @ptrCast(name));
            if (location < 0)
                return false;

            rl.SetShaderValue(shader.*, location, val, v_type);
            return true;
        }
        return false;
    }

    inline fn renderPoint(
        vertices: []Float,
        color: Color,
        multiplier: ?[]const PosF,
    ) void {
        if (multiplier) |m| {
            for (0..m.len) |i| {
                rl.DrawPixel(
                    @intFromFloat(vertices[0] + m[i][0]),
                    @intFromFloat(vertices[1] + m[i][1]),
                    @bitCast(color),
                );
            }
        } else {
            rl.DrawPixel(
                @intFromFloat(vertices[0]),
                @intFromFloat(vertices[1]),
                @bitCast(color),
            );
        }
    }

    inline fn renderLine(
        vertices: []Float,
        color: Color,
        multiplier: ?[]const PosF,
    ) void {
        if (multiplier) |m| {
            for (0..m.len) |i| {
                rl.DrawLine(
                    @intFromFloat(vertices[0] + m[i][0]),
                    @intFromFloat(vertices[1] + m[i][1]),
                    @intFromFloat(vertices[2] + m[i][0]),
                    @intFromFloat(vertices[3] + m[i][1]),
                    @bitCast(color),
                );
            }
        } else {
            rl.DrawLine(
                @intFromFloat(vertices[0]),
                @intFromFloat(vertices[1]),
                @intFromFloat(vertices[2]),
                @intFromFloat(vertices[3]),
                @bitCast(color),
            );
        }
    }

    inline fn renderRect(
        vertices: []Float,
        color: Color,
        multiplier: ?[]const PosF,
        color1: ?Color,
        color2: ?Color,
        color3: ?Color,
        fill: bool,
        thickness: ?Float,
    ) void {
        var rect = rl.Rectangle{
            .x = vertices[0],
            .y = vertices[1],
            .width = vertices[2],
            .height = vertices[3],
        };

        if (multiplier) |m| {
            for (0..m.len) |i| {
                rect.x = vertices[0] + rect.x + m[i][0];
                rect.y = vertices[1] + rect.y + m[i][1];
                if (fill) {
                    rl.DrawRectangleGradientEx(
                        rect,
                        @bitCast(color),
                        @bitCast(color1 orelse color),
                        @bitCast(color2 orelse color),
                        @bitCast(color3 orelse color),
                    );
                } else {
                    rl.DrawRectangleLinesEx(rect, thickness orelse 1.0, @bitCast(color));
                }
            }
        } else {
            if (fill) {
                rl.DrawRectangleGradientEx(
                    rect,
                    @bitCast(color),
                    @bitCast(color1 orelse color),
                    @bitCast(color2 orelse color),
                    @bitCast(color3 orelse color),
                );
            } else {
                rl.DrawRectangleLinesEx(rect, thickness orelse 1.0, @bitCast(color));
            }
        }
    }

    inline fn renderTriangles(
        vertices: []Float,
        color: Color,
        multiplier: ?[]const PosF,
        fill: bool,
    ) void {
        if (multiplier) |m| {
            for (0..m.len) |i| {
                if (fill) {
                    rl.DrawTriangle(
                        .{ .x = vertices[0] + m[i][0], .y = vertices[1] + m[i][1] },
                        .{ .x = vertices[2] + m[i][0], .y = vertices[3] + m[i][1] },
                        .{ .x = vertices[4] + m[i][0], .y = vertices[5] + m[i][1] },
                        @bitCast(color),
                    );
                } else {
                    rl.DrawTriangleLines(
                        .{ .x = vertices[0] + m[i][0], .y = vertices[1] + m[i][1] },
                        .{ .x = vertices[2] + m[i][0], .y = vertices[3] + m[i][1] },
                        .{ .x = vertices[4] + m[i][0], .y = vertices[5] + m[i][1] },
                        @bitCast(color),
                    );
                }
            }
        } else {
            if (fill) {
                rl.DrawTriangle(
                    .{ .x = vertices[0], .y = vertices[1] },
                    .{ .x = vertices[2], .y = vertices[3] },
                    .{ .x = vertices[4], .y = vertices[5] },
                    @bitCast(color),
                );
            } else {
                rl.DrawTriangleLines(
                    .{ .x = vertices[0], .y = vertices[1] },
                    .{ .x = vertices[2], .y = vertices[3] },
                    .{ .x = vertices[4], .y = vertices[5] },
                    @bitCast(color),
                );
            }
        }
    }

    inline fn renderCircle(
        vertices: []Float,
        color: Color,
        color1: ?Color,
        multiplier: ?[]const PosF,
        fill: bool,
    ) void {
        if (multiplier) |m| {
            for (0..m.len) |i| {
                if (fill) {
                    if (color1) |gc| {
                        rl.DrawCircleGradient(
                            @intFromFloat(vertices[0] + m[i][0]),
                            @intFromFloat(vertices[1] + m[i][1]),
                            vertices[2],
                            @bitCast(color),
                            @bitCast(gc),
                        );
                    } else {
                        rl.DrawCircleV(
                            .{ .x = vertices[0] + m[i][0], .y = vertices[1] + m[i][1] },
                            vertices[2],
                            @bitCast(color),
                        );
                    }
                } else {
                    rl.DrawCircleLinesV(
                        .{ .x = vertices[0] + m[i][0], .y = vertices[1] + m[i][1] },
                        vertices[2],
                        @bitCast(color),
                    );
                }
            }
        } else {
            if (fill) {
                if (color1) |gc| {
                    rl.DrawCircleGradient(
                        @intFromFloat(vertices[0]),
                        @intFromFloat(vertices[1]),
                        vertices[2],
                        @bitCast(color),
                        @bitCast(gc),
                    );
                } else {
                    rl.DrawCircleV(
                        .{ .x = vertices[0], .y = vertices[1] },
                        vertices[2],
                        @bitCast(color),
                    );
                }
            } else {
                rl.DrawCircleLinesV(
                    .{ .x = vertices[0], .y = vertices[1] },
                    vertices[2],
                    @bitCast(color),
                );
            }
        }
    }

    inline fn renderArc(
        vertices: []Float,
        color: Color,
        multiplier: ?[]const PosF,
        fill: bool,
    ) void {
        if (multiplier) |m| {
            for (0..m.len) |i| {
                if (fill) {
                    rl.DrawCircleSector(
                        .{ .x = vertices[0] + m[i][0], .y = vertices[1] + m[i][1] },
                        vertices[2],
                        vertices[3],
                        vertices[4],
                        @intFromFloat(vertices[5]),
                        @bitCast(color),
                    );
                } else {
                    rl.DrawCircleSectorLines(
                        .{ .x = vertices[0] + m[i][0], .y = vertices[1] + m[i][1] },
                        vertices[2],
                        vertices[3],
                        vertices[4],
                        @intFromFloat(vertices[5]),
                        @bitCast(color),
                    );
                }
            }
        } else {
            if (fill) {
                rl.DrawCircleSector(
                    .{ .x = vertices[0], .y = vertices[1] },
                    vertices[2],
                    vertices[3],
                    vertices[4],
                    @intFromFloat(vertices[5]),
                    @bitCast(color),
                );
            } else {
                rl.DrawCircleSectorLines(
                    .{ .x = vertices[0], .y = vertices[1] },
                    vertices[2],
                    vertices[3],
                    vertices[4],
                    @intFromFloat(vertices[5]),
                    @bitCast(color),
                );
            }
        }
    }

    inline fn renderEllipse(
        vertices: []Float,
        color: Color,
        multiplier: ?[]const PosF,
        fill: bool,
    ) void {
        if (multiplier) |m| {
            for (0..m.len) |i| {
                if (fill) {
                    rl.DrawEllipse(
                        @intFromFloat(vertices[0] + m[i][0]),
                        @intFromFloat(vertices[1] + m[i][1]),
                        vertices[2],
                        vertices[3],
                        @bitCast(color),
                    );
                } else {
                    rl.DrawEllipseLines(
                        @intFromFloat(vertices[0] + m[i][0]),
                        @intFromFloat(vertices[1] + m[i][1]),
                        vertices[2],
                        vertices[3],
                        @bitCast(color),
                    );
                }
            }
        } else {
            if (fill) {
                rl.DrawEllipse(
                    @intFromFloat(vertices[0]),
                    @intFromFloat(vertices[1]),
                    vertices[2],
                    vertices[3],
                    @bitCast(color),
                );
            } else {
                rl.DrawEllipseLines(
                    @intFromFloat(vertices[0]),
                    @intFromFloat(vertices[1]),
                    vertices[2],
                    vertices[3],
                    @bitCast(color),
                );
            }
        }
    }

    fn printDebug(buffer: *StringBuffer) void {
        buffer.append("Raylib Renderer:\n");
        buffer.print("  default_offset: {any}\n", .{default_offset});
        buffer.print("  default_pivot: {any}\n", .{default_pivot});
        buffer.print("  default_blend_mode: {any}\n\n", .{default_blend_mode});

        buffer.print("  textures: {any}\n", .{textures});
        buffer.print("  render_textures: {any}\n", .{render_textures});
        buffer.print("  shaders: {any}\n\n", .{shaders});

        buffer.print("  active_camera: {any}\n", .{active_camera});
        buffer.print("  active_shader: {any}\n", .{active_shader});
        buffer.print("  active_render_texture: {any}\n", .{active_render_texture});
        buffer.print("  active_clear_color: {any}\n", .{active_clear_color});
    }
};
