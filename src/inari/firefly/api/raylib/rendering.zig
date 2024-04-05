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

        //active_offset = default_offset;
        active_blend_mode = default_blend_mode;
        active_tint_color = default_tint_color;
        active_clear_color = default_clear_color;

        textures = DynArray(Texture2D).new(api.ALLOC) catch unreachable;
        render_textures = DynArray(RenderTexture2D).new(api.ALLOC) catch unreachable;
        shaders = DynArray(Shader).new(api.ALLOC) catch unreachable;

        interface.setOffset = setOffset;
        interface.addOffset = addOffset;

        interface.loadTexture = loadTexture;
        interface.disposeTexture = disposeTexture;
        interface.createRenderTexture = createRenderTexture;
        interface.disposeRenderTexture = disposeRenderTexture;
        interface.createShader = createShader;
        interface.disposeShader = disposeShader;

        interface.setActiveShader = setActiveShader;
        interface.startRendering = startRendering;
        interface.renderTexture = renderTexture;
        interface.renderSprite = renderSprite;
        interface.renderShape = renderShape;
        interface.endRendering = endRendering;

        interface.printDebug = printDebug;
        interface.deinit = deinit;
    }

    fn deinit() void {
        defer initialized = false;
        if (!initialized)
            return;

        textures.clear();
        textures.deinit();
        render_textures.clear();
        render_textures.deinit();
        shaders.clear();
        shaders.deinit();
        singleton = null;
    }

    const default_offset = Vector2f{ 0, 0 };
    const default_tint_color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    const default_clear_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    const default_pivot = PosF{ 0, 0 };

    const default_blend_mode = BlendMode.ALPHA;

    var window_handle: ?api.WindowHandle = null;
    var textures: DynArray(Texture2D) = undefined;
    var render_textures: DynArray(RenderTexture2D) = undefined;
    var shaders: DynArray(Shader) = undefined;

    var active_shader: ?BindingId = null;
    var active_render_texture: ?BindingId = null;
    //var active_offset: Vector2f = undefined;
    var active_tint_color: rl.Color = undefined;
    var active_clear_color: ?rl.Color = undefined;
    var active_blend_mode: BlendMode = undefined;
    var active_camera = rl.Camera2D{
        .offset = rl.Vector2{ .x = 0, .y = 0 },
        .target = rl.Vector2{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1,
    };

    var temp_source_rect = rl.Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var temp_dest_rect = rl.Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var temp_pivot = rl.Vector2{ .x = 0, .y = 0 };
    var temp_rect = rl.Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 };
    var temp_p1 = rl.Vector2{ .x = 0, .y = 0 };
    var temp_p2 = rl.Vector2{ .x = 0, .y = 0 };
    var temp_p3 = rl.Vector2{ .x = 0, .y = 0 };
    var temp_p4 = rl.Vector2{ .x = 0, .y = 0 };

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

    fn createRenderTexture(projection: *Projection) RenderTextureBinding {
        var tex = rl.LoadRenderTexture(projection.plain[2], projection.plain[3]);
        var id = render_textures.add(tex);
        return RenderTextureBinding{
            .id = id,
            .width = projection.plain[2],
            .height = projection.plain[3],
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
        active_camera.offset.x = @floatFromInt(projection.plain[0]);
        active_camera.offset.y = @floatFromInt(projection.plain[1]);
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

        rl.BeginBlendMode(@intFromEnum(active_blend_mode));
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
            rl.BeginBlendMode(@intFromEnum(blend_mode orelse active_blend_mode));

            // set source rect
            temp_source_rect.width = @floatFromInt(tex.texture.width);
            // NOTE: render to texture has inverted y axis.
            temp_source_rect.height = @floatFromInt(-tex.texture.height);
            // set destination rect
            if (scale) |s| {
                temp_dest_rect.x = position[0];
                temp_dest_rect.y = position[1];
                temp_dest_rect.width = s[0] * @as(Float, @floatFromInt(tex.texture.width));
                temp_dest_rect.height = s[1] * @as(Float, @floatFromInt(tex.texture.height));
                temp_pivot = @bitCast((pivot orelse default_pivot) * s);
            } else {
                temp_dest_rect.x = position[0];
                temp_dest_rect.y = position[1];
                temp_dest_rect.width = @floatFromInt(tex.texture.width);
                temp_dest_rect.height = @floatFromInt(tex.texture.height);
                temp_pivot = @bitCast(pivot orelse default_pivot);
            }

            rl.DrawTexturePro(
                tex.texture,
                temp_source_rect,
                temp_dest_rect,
                temp_pivot,
                rotation orelse 0,
                if (tint_color) |tc| @bitCast(tc) else active_tint_color,
            );
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
            rl.BeginBlendMode(@intFromEnum(blend_mode orelse active_blend_mode));

            // scaling
            if (scale) |s| {
                temp_dest_rect.width = @fabs(texture_bounds[2]) * s[0];
                temp_dest_rect.height = @fabs(texture_bounds[3]) * s[1];
                temp_pivot = @bitCast((pivot orelse default_pivot) * s);
            } else {
                temp_dest_rect.width = @fabs(texture_bounds[2]);
                temp_dest_rect.height = @fabs(texture_bounds[3]);
                temp_pivot = @bitCast(pivot orelse default_pivot);
            }

            if (multiplier) |m| {
                addOffset(position);
                for (0..m.len) |i| {
                    temp_dest_rect.x = m[i][0];
                    temp_dest_rect.y = m[i][1];
                    rl.DrawTexturePro(
                        tex.*,
                        @bitCast(texture_bounds),
                        temp_dest_rect,
                        temp_pivot,
                        rotation orelse 0,
                        if (tint_color) |tc| @bitCast(tc) else active_tint_color,
                    );
                }
                minusOffset(position);
            } else {
                temp_dest_rect.x = position[0];
                temp_dest_rect.y = position[1];
                rl.DrawTexturePro(
                    tex.*,
                    @bitCast(texture_bounds),
                    temp_dest_rect,
                    temp_pivot,
                    rotation orelse 0,
                    if (tint_color) |tc| @bitCast(tc) else active_tint_color,
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
        rl.BeginBlendMode(@intFromEnum(blend_mode orelse active_blend_mode));

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
            var location = rl.GetShaderLocation(shader.*, @ptrCast(name));
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
        temp_rect.x = vertices[0];
        temp_rect.y = vertices[1];
        temp_rect.width = vertices[2];
        temp_rect.height = vertices[3];
        if (multiplier) |m| {
            temp_p1.x = temp_rect.x;
            temp_p1.y = temp_rect.y;
            for (0..m.len) |i| {
                temp_rect.x = vertices[0] + temp_p1.x + m[i][0];
                temp_rect.y = vertices[1] + temp_p1.y + m[i][1];
                if (fill) {
                    rl.DrawRectangleGradientEx(
                        temp_rect,
                        @bitCast(color),
                        @bitCast(color1 orelse color),
                        @bitCast(color2 orelse color),
                        @bitCast(color3 orelse color),
                    );
                } else {
                    rl.DrawRectangleLinesEx(temp_rect, thickness orelse 1.0, @bitCast(color));
                }
            }
        } else {
            if (fill) {
                rl.DrawRectangleGradientEx(
                    temp_rect,
                    @bitCast(color),
                    @bitCast(color1 orelse color),
                    @bitCast(color2 orelse color),
                    @bitCast(color3 orelse color),
                );
            } else {
                rl.DrawRectangleLinesEx(temp_rect, thickness orelse 1.0, @bitCast(color));
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
                temp_p1.x = vertices[0] + m[i][0];
                temp_p1.y = vertices[1] + m[i][1];
                temp_p2.x = vertices[2] + m[i][0];
                temp_p2.y = vertices[3] + m[i][1];
                temp_p3.x = vertices[4] + m[i][0];
                temp_p3.y = vertices[5] + m[i][1];
                if (fill) {
                    rl.DrawTriangle(temp_p1, temp_p2, temp_p3, @bitCast(color));
                } else {
                    rl.DrawTriangleLines(temp_p1, temp_p2, temp_p3, @bitCast(color));
                }
            }
        } else {
            temp_p1.x = vertices[0];
            temp_p1.y = vertices[1];
            temp_p2.x = vertices[2];
            temp_p2.y = vertices[3];
            temp_p3.x = vertices[4];
            temp_p3.y = vertices[5];
            if (fill) {
                rl.DrawTriangle(temp_p1, temp_p2, temp_p3, @bitCast(color));
            } else {
                rl.DrawTriangleLines(temp_p1, temp_p2, temp_p3, @bitCast(color));
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
                temp_p1.x = vertices[0] + m[i][0];
                temp_p1.y = vertices[1] + m[i][1];
                if (fill) {
                    if (color1) |gc| {
                        rl.DrawCircleGradient(@intFromFloat(temp_p1.x), @intFromFloat(temp_p1.y), vertices[2], @bitCast(color), @bitCast(gc));
                    } else {
                        rl.DrawCircleV(temp_p1, vertices[2], @bitCast(color));
                    }
                } else {
                    rl.DrawCircleLinesV(temp_p1, vertices[2], @bitCast(color));
                }
            }
        } else {
            temp_p1.x = vertices[0];
            temp_p1.y = vertices[1];
            if (fill) {
                if (color1) |gc| {
                    rl.DrawCircleGradient(@intFromFloat(temp_p1.x), @intFromFloat(temp_p1.y), vertices[2], @bitCast(color), @bitCast(gc));
                } else {
                    rl.DrawCircleV(temp_p1, vertices[2], @bitCast(color));
                }
            } else {
                rl.DrawCircleLinesV(temp_p1, vertices[2], @bitCast(color));
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
                temp_p1.x = vertices[0] + m[i][0];
                temp_p1.y = vertices[1] + m[i][1];
                if (fill) {
                    rl.DrawCircleSector(temp_p1, vertices[2], vertices[3], vertices[4], @intFromFloat(vertices[5]), @bitCast(color));
                } else {
                    rl.DrawCircleSectorLines(temp_p1, vertices[2], vertices[3], vertices[4], @intFromFloat(vertices[5]), @bitCast(color));
                }
            }
        } else {
            temp_p1.x = vertices[0];
            temp_p1.y = vertices[1];
            if (fill) {
                rl.DrawCircleSector(temp_p1, vertices[2], vertices[3], vertices[4], @intFromFloat(vertices[5]), @bitCast(color));
            } else {
                rl.DrawCircleSectorLines(temp_p1, vertices[2], vertices[3], vertices[4], @intFromFloat(vertices[5]), @bitCast(color));
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
                temp_p1.x = vertices[0] + m[i][0];
                temp_p1.y = vertices[1] + m[i][1];
                if (fill) {
                    rl.DrawEllipse(@intFromFloat(temp_p1.x), @intFromFloat(temp_p1.y), vertices[2], vertices[3], @bitCast(color));
                } else {
                    rl.DrawEllipseLines(@intFromFloat(temp_p1.x), @intFromFloat(temp_p1.y), vertices[2], vertices[3], @bitCast(color));
                }
            }
        } else {
            temp_p1.x = vertices[0];
            temp_p1.y = vertices[1];
            if (fill) {
                rl.DrawEllipse(@intFromFloat(temp_p1.x), @intFromFloat(temp_p1.y), vertices[2], vertices[3], @bitCast(color));
            } else {
                rl.DrawEllipseLines(@intFromFloat(temp_p1.x), @intFromFloat(temp_p1.y), vertices[2], vertices[3], @bitCast(color));
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
        buffer.print("  active_tint_color: {any}\n", .{active_tint_color});
        buffer.print("  active_clear_color: {any}\n", .{active_clear_color});
        buffer.print("  active_blend_mode: {any}\n", .{active_blend_mode});
    }
};
