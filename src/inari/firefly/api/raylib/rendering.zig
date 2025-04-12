const std = @import("std");
const firefly = @import("../../firefly.zig");
const rl = @cImport(@cInclude("raylib.h"));
const rlgl = @cImport(@cInclude("rlgl.h"));

const NamePool = firefly.api.NamePool;
const Texture2D = rl.Texture2D;
const Font = rl.Font;
const RenderTexture2D = rl.RenderTexture2D;
const Shader = rl.Shader;
const Image = rl.Image;
const String = firefly.utils.String;
const IRenderAPI = firefly.api.IRenderAPI;
const Vector2f = firefly.utils.Vector2f;
const Vector3f = firefly.utils.Vector3f;
const Vector4f = firefly.utils.Vector4f;
const PosF = firefly.utils.PosF;
const RectF = firefly.utils.RectF;
const ImageBinding = firefly.api.ImageBinding;
const Color = firefly.utils.Color;
const ShapeType = firefly.api.ShapeType;
const BlendMode = firefly.api.BlendMode;
const TextureBinding = firefly.api.TextureBinding;
const ShaderBinding = firefly.api.ShaderBinding;
const TextureFilter = firefly.api.TextureFilter;
const TextureWrap = firefly.api.TextureWrap;
const RenderTextureBinding = firefly.api.RenderTextureBinding;
const Projection = firefly.api.Projection;
const BindingId = firefly.api.BindingId;
const DynArray = firefly.utils.DynArray;
const DynIndexArray = firefly.utils.DynIndexArray;
const StringBuffer = firefly.utils.StringBuffer;
const CInt = firefly.utils.CInt;
const String0 = firefly.utils.String0;
const Float = firefly.utils.Float;
const WindowHandle = firefly.api.WindowHandle;
const EMPTY_STRING = firefly.utils.EMPTY_STRING;

var singleton: ?IRenderAPI() = null;
pub fn createRenderAPI() !IRenderAPI() {
    if (singleton == null)
        singleton = IRenderAPI().init(RaylibRenderAPI.initImpl);

    return singleton.?;
}

const RaylibRenderAPI = struct {
    var initialized = false;

    fn initImpl(interface: *IRenderAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        active_clear_color = default_clear_color;

        textures = DynArray(Texture2D).newWithRegisterSize(firefly.api.ALLOC, 10);
        images = DynArray(Image).newWithRegisterSize(firefly.api.ALLOC, 10);
        render_textures = DynArray(RenderTexture2D).newWithRegisterSize(firefly.api.ALLOC, 10);
        fonts = DynArray(Font).newWithRegisterSize(firefly.api.ALLOC, 10);
        shaders = DynArray(Shader).newWithRegisterSize(firefly.api.ALLOC, 10);
        shader_stack = DynIndexArray.new(firefly.api.ALLOC, 10);

        interface.setRenderBatch = setRenderBatch;
        interface.showFPS = showFPS;

        interface.setOffset = setOffset;
        interface.addOffset = addOffset;

        interface.loadTexture = loadTexture;
        interface.disposeTexture = disposeTexture;

        interface.loadImageFromTexture = loadImageFromTexture;
        interface.loadImageRegionFromTexture = loadImageRegionFromTexture;
        interface.loadImageFromFile = loadImageFromFile;
        interface.disposeImage = disposeImage;

        interface.loadFont = loadFont;
        interface.disposeFont = disposeFont;
        interface.createRenderTexture = createRenderTexture;
        interface.disposeRenderTexture = disposeRenderTexture;
        interface.createShader = createShader;
        interface.disposeShader = disposeShader;

        interface.putShaderStack = putShaderStack;
        interface.popShaderStack = popShaderStack;
        interface.clearShaderStack = clearShaderStack;

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

        show_fps = false;
        var next = textures.slots.nextSetBit(0);
        while (next) |i| {
            disposeTexture(i);
            next = textures.slots.nextSetBit(i + 1);
        }
        textures.clear();
        textures.deinit();

        next = images.slots.nextSetBit(0);
        while (next) |i| {
            disposeImage(i);
            next = images.slots.nextSetBit(i + 1);
        }
        images.clear();
        images.deinit();

        next = render_textures.slots.nextSetBit(0);
        while (next) |i| {
            disposeRenderTexture(i);
            next = render_textures.slots.nextSetBit(i + 1);
        }
        render_textures.clear();
        render_textures.deinit();

        shader_stack.clear();
        shader_stack.deinit();
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

    var show_fps: bool = false;
    var show_fps_x: c_int = 0;
    var show_fps_y: c_int = 0;
    var default_font_size: CInt = 32;
    var default_char_num: CInt = 95;

    var window_handle: ?WindowHandle = null;
    var textures: DynArray(Texture2D) = undefined;
    var images: DynArray(Image) = undefined;
    var fonts: DynArray(Font) = undefined;
    var render_textures: DynArray(RenderTexture2D) = undefined;
    var shaders: DynArray(Shader) = undefined;
    var shader_stack: DynIndexArray = undefined;

    var active_render_texture: ?BindingId = null;
    var active_clear_color: ?rl.Color = undefined;

    var active_camera = rl.Camera2D{
        .offset = rl.Vector2{ .x = 0, .y = 0 },
        .target = rl.Vector2{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = 1,
    };
    var active_camera_zoom_vec: Vector2f = .{ 0, 0 };

    var render_batch: ?rlgl.rlRenderBatch = null;

    fn setRenderBatch(buffer_number: ?CInt, max_buffer_elements: ?CInt) void {
        if (render_batch) |rb| {
            rlgl.rlUnloadRenderBatch(rb);
            render_batch = null;
        }
        render_batch = rlgl.rlLoadRenderBatch(buffer_number orelse 1, max_buffer_elements orelse 8192);
        rlgl.rlSetRenderBatchActive(&render_batch.?);
    }

    fn showFPS(pos: Vector2f) void {
        show_fps = true;
        show_fps_x = firefly.utils.f32_cint(pos[0]);
        show_fps_y = firefly.utils.f32_cint(pos[1]);
    }

    fn setOffset(offset: PosF) void {
        active_camera.offset = @bitCast(offset);
        rl.BeginMode2D(active_camera);
    }

    fn addOffset(offset: Vector2f) void {
        active_camera.offset = @bitCast(@as(Vector2f, @bitCast(active_camera.offset)) + offset);
        rl.BeginMode2D(active_camera);
    }

    fn minusOffset(offset: Vector2f) void {
        active_camera.offset = @bitCast(@as(Vector2f, @bitCast(active_camera.offset)) - offset);
        rl.BeginMode2D(active_camera);
    }

    fn loadTexture(
        resource: String,
        is_mipmap: bool,
        filter: TextureFilter,
        wrap: TextureWrap,
    ) firefly.api.IOErrors!TextureBinding {
        const res = firefly.api.ALLOC.dupeZ(u8, resource) catch |err| firefly.api.handleUnknownError(err);
        defer firefly.api.ALLOC.free(res);

        var tex = rl.LoadTexture(res);
        if (!rl.IsTextureValid(tex))
            return firefly.api.IOErrors.LOAD_TEXTURE_ERROR;

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
        const tex = textures.get(binding) orelse return;

        rl.UnloadTexture(tex.*);
        textures.delete(binding);
    }

    fn loadImageFromTexture(texture_id: BindingId) firefly.api.IOErrors!ImageBinding {
        const texture: *Texture2D = textures.get(texture_id).?;
        const img: Image = rl.LoadImageFromTexture(texture.*);

        if (!rl.IsImageValid(img))
            return firefly.api.IOErrors.LOAD_IMAGE_ERROR;

        const img_id = images.add(img);
        return ImageBinding{
            .id = img_id,
            .data = img.data,
            .width = img.width,
            .height = img.height,
            .mipmaps = img.mipmaps,
            .format = img.format,
            .get_color_at = getImageColorAt,
            .set_color_at = setImageColorAt,
        };
    }

    fn loadImageRegionFromTexture(texture_id: BindingId, region: RectF) firefly.api.IOErrors!ImageBinding {
        const texture: *Texture2D = textures.get(texture_id).?;
        const img: Image = rl.LoadImageFromTexture(texture.*);

        if (!rl.IsImageValid(img))
            return firefly.api.IOErrors.LOAD_IMAGE_ERROR;

        var img_region = rl.ImageFromImage(
            img,
            .{
                .x = region[0],
                .y = region[1],
                .width = @abs(region[2]),
                .height = @abs(region[3]),
            },
        );

        if (!rl.IsImageValid(img_region))
            return firefly.api.IOErrors.LOAD_IMAGE_ERROR;

        if (region[2] < 0)
            rl.ImageFlipHorizontal(&img_region);
        if (region[3] < 0)
            rl.ImageFlipVertical(&img_region);
        const img_id = images.add(img_region);
        return ImageBinding{
            .id = img_id,
            .data = img_region.data,
            .width = img_region.width,
            .height = img_region.height,
            .mipmaps = img_region.mipmaps,
            .format = img_region.format,
            .get_color_at = getImageColorAt,
            .set_color_at = setImageColorAt,
        };
    }

    fn loadImageFromFile(resource: String) firefly.api.IOErrors!ImageBinding {
        const res = firefly.api.ALLOC.dupeZ(u8, resource) catch |err| firefly.api.handleUnknownError(err);
        defer firefly.api.ALLOC.free(res);
        const img: Image = rl.LoadImage(res);

        if (!rl.IsImageValid(img))
            return firefly.api.IOErrors.LOAD_IMAGE_ERROR;

        const img_id = images.add(img);
        return ImageBinding{
            .id = img_id,
            .data = img.data,
            .width = img.width,
            .height = img.height,
            .mipmaps = img.mipmaps,
            .format = img.format,
            .get_color_at = getImageColorAt,
            .set_color_at = setImageColorAt,
        };
    }

    fn disposeImage(image_id: BindingId) void {
        const img = images.get(image_id) orelse return;
        rl.UnloadImage(img.*);
        images.delete(image_id);
    }

    fn getImageColorAt(image_id: BindingId, x: CInt, y: CInt) ?Color {
        if (images.get(image_id)) |img| {
            return @bitCast(rl.GetImageColor(img.*, x, y));
        }
        return null;
    }

    fn setImageColorAt(image_id: BindingId, x: CInt, y: CInt, color: Color) void {
        if (images.get(image_id)) |img| {
            rl.ImageDrawPixel(img, x, y, @bitCast(color));
        }
    }

    fn loadFont(resource: String, size: ?CInt, char_num: ?CInt, code_points: ?CInt) firefly.api.IOErrors!BindingId {
        const res = firefly.api.ALLOC.dupeZ(u8, resource) catch |err| firefly.api.handleUnknownError(err);
        defer firefly.api.ALLOC.free(res);

        const font = if (size == null and char_num == null and code_points == null)
            rl.LoadFont(res)
        else
            rl.LoadFontEx(
                res,
                size orelse default_font_size,
                code_points orelse 0,
                char_num orelse default_char_num,
            );

        if (!rl.IsFontValid(font))
            return firefly.api.IOErrors.LOAD_FONT_ERROR;

        return fonts.add(font);
    }

    fn disposeFont(binding: BindingId) void {
        const f = fonts.get(binding) orelse return;
        rl.UnloadFont(f.*);
        fonts.delete(binding);
    }

    fn createRenderTexture(projection: *Projection) firefly.api.IOErrors!RenderTextureBinding {
        const tex = rl.LoadRenderTexture(
            @intFromFloat(projection.width),
            @intFromFloat(projection.height),
        );

        if (!rl.IsRenderTextureValid(tex))
            return firefly.api.IOErrors.LOAD_RENDER_TEXTURE_ERROR;

        rl.SetTextureFilter(tex.texture, rlgl.RL_TEXTURE_FILTER_LINEAR);
        rl.SetTextureWrap(tex.texture, rlgl.RL_TEXTURE_WRAP_CLAMP);

        const id = render_textures.add(tex);
        return RenderTextureBinding{
            .id = id,
            .width = @intFromFloat(projection.width),
            .height = @intFromFloat(projection.height),
        };
    }

    fn disposeRenderTexture(id: BindingId) void {
        const tex = render_textures.get(id) orelse return;
        rl.UnloadRenderTexture(tex.*);
        render_textures.delete(id);
    }

    fn createShader(vertex_shader: ?String, fragment_shade: ?String, file: bool) firefly.api.IOErrors!ShaderBinding {
        const vert = firefly.api.ALLOC.dupeZ(u8, vertex_shader orelse EMPTY_STRING) catch |err| firefly.api.handleUnknownError(err);
        defer firefly.api.ALLOC.free(vert);
        const frag = firefly.api.ALLOC.dupeZ(u8, fragment_shade orelse EMPTY_STRING) catch |err| firefly.api.handleUnknownError(err);
        defer firefly.api.ALLOC.free(frag);

        var shader: Shader = undefined;
        if (file) {
            shader = rl.LoadShader(vert, frag);
        } else {
            shader = rl.LoadShaderFromMemory(vert, frag);
        }

        if (!rl.IsShaderValid(shader))
            return firefly.api.IOErrors.LOAD_SHADER_ERROR;

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
        const shader = shaders.get(id) orelse return;
        rl.UnloadShader(shader.*);
        shaders.delete(id);
    }

    // raylib default shader settings:
    // https://github.com/raysan5/raylib/wiki/raylib-default-shader

    fn putShaderStack(binding_id: BindingId) void {
        if (shaders.get(binding_id)) |shader| {
            shader_stack.add(binding_id);
            rl.BeginShaderMode(shader.*);
        }
    }

    fn popShaderStack() void {
        if (shader_stack.size_pointer > 0)
            _ = shader_stack.removeAt(shader_stack.size_pointer - 1);

        if (shader_stack.size_pointer > 0) {
            const binding_id = shader_stack.get(shader_stack.size_pointer - 1);
            if (shaders.get(binding_id)) |shader| {
                shader_stack.add(binding_id);
                rl.BeginShaderMode(shader.*);
            } else {
                rl.EndShaderMode();
            }
        } else {
            rl.EndShaderMode();
        }
    }

    fn clearShaderStack() void {
        shader_stack.clear();
        rl.EndShaderMode();
    }

    fn startRendering(binding_id: ?BindingId, projection: *Projection) void {
        active_render_texture = binding_id;
        active_camera.offset = @bitCast(-projection.position);
        active_camera.target = @bitCast(projection.pivot);
        active_camera.rotation = projection.rotation;
        active_camera.zoom = projection.zoom;
        active_camera_zoom_vec[0] = projection.zoom;
        active_camera_zoom_vec[1] = projection.zoom;
        active_clear_color = if (projection.clear_color != null) @bitCast(projection.clear_color.?) else null;

        if (active_render_texture) |tex_id| {
            if (render_textures.get(tex_id)) |tex| {
                if (!rl.IsRenderTextureValid(tex.*))
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
        pivot: PosF,
        scale: PosF,
        rotation: Float,
        tint_color: ?Color,
        blend_mode: ?BlendMode,
        flip_x: bool,
        flip_y: bool,
    ) void {
        if (render_textures.get(texture_id)) |tex| {

            // set blend mode
            if (blend_mode) |bm|
                rl.BeginBlendMode(@intFromEnum(bm));

            rl.DrawTexturePro(
                tex.texture,
                .{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(if (flip_y) -tex.texture.width else tex.texture.width),
                    .height = @floatFromInt(if (flip_x) tex.texture.height else -tex.texture.height),
                },
                .{
                    .x = position[0],
                    .y = position[1],
                    .width = scale[0] * @as(Float, @floatFromInt(tex.texture.width)),
                    .height = scale[1] * @as(Float, @floatFromInt(tex.texture.height)),
                },
                @bitCast(pivot * scale),
                rotation,
                if (tint_color) |tc| @bitCast(tc) else default_tint_color,
            );
        }
        rl.EndShaderMode();
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
    ) void {

        // set blend mode
        if (blend_mode) |bm| {
            rl.BeginBlendMode(@intFromEnum(bm));
        }

        // apply translation functions if needed
        addOffset(offset * active_camera_zoom_vec);
        if (scale != null or rotation != null) {
            rlgl.rlPushMatrix();
            if (pivot) |p| rlgl.rlTranslatef(p[0], p[1], 0);
            if (scale) |s| rlgl.rlScalef(s[0], s[1], 0);
            if (rotation) |r| rlgl.rlRotatef(r, 0, 0, 1);
            if (pivot) |p| rlgl.rlTranslatef(-p[0], -p[1], 0);
        }

        switch (shape_type) {
            .POINT => renderPoint(vertices, color),
            .LINE => renderLine(vertices, color),
            .RECTANGLE => renderRect(vertices, color, color1, color2, color3, fill, thickness),
            .TRIANGLE => renderTriangles(vertices, color, fill),
            .CIRCLE => renderCircle(vertices, color, color1, fill),
            .ARC => renderArc(vertices, color, fill),
            .ELLIPSE => renderEllipse(vertices, color, fill),
        }

        // dispose translation functions if needed
        if (scale != null or rotation != null) {
            rlgl.rlPopMatrix();
        }
        minusOffset(offset * active_camera_zoom_vec);
    }

    fn renderText(
        font_id: ?BindingId,
        text: String0,
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
            if (fonts.get(fid)) |f|
                font = f.*;
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
            if (show_fps)
                rl.DrawFPS(show_fps_x, show_fps_y);
            rl.EndMode2D();
            rl.EndDrawing();
        }
    }

    fn setShaderValueFloat(shader_id: BindingId, name: String, val: Float) bool {
        return setShaderValue(shader_id, name, &val, rl.SHADER_UNIFORM_FLOAT);
    }
    fn setShaderValueVec2(shader_id: BindingId, name: String, val: Vector2f) bool {
        return setShaderValue(shader_id, name, &val, rl.SHADER_UNIFORM_VEC2);
    }
    fn setShaderValueVec3(shader_id: BindingId, name: String, val: Vector3f) bool {
        return setShaderValue(shader_id, name, &val, rl.SHADER_UNIFORM_VEC3);
    }
    fn setShaderValueVec4(shader_id: BindingId, name: String, val: Vector4f) bool {
        return setShaderValue(shader_id, name, &val, rl.SHADER_UNIFORM_VEC4);
    }
    fn setShaderValueTex(shader_id: BindingId, name: String, val: BindingId) bool {
        if (render_textures.get(val)) |rt| {
            return setShaderValue(shader_id, name, rt, rl.SHADER_UNIFORM_SAMPLER2D);
        }
        return false;
    }

    fn setShaderValue(shader_id: BindingId, name: String, val: anytype, v_type: CInt) bool {
        if (shaders.get(shader_id)) |shader| {
            const n = firefly.api.ALLOC.dupeZ(u8, name) catch |err| firefly.api.handleUnknownError(err);
            defer firefly.api.ALLOC.free(n);

            const location = rl.GetShaderLocation(
                shader.*,
                n,
            );
            if (location < 0) {
                firefly.api.Logger.warn("No shader uniform value with name: {s} found", .{name});
                return false;
            }

            rl.SetShaderValue(shader.*, location, val, v_type);
            return true;
        }
        return false;
    }

    inline fn renderPoint(
        vertices: []Float,
        color: Color,
    ) void {
        var i: usize = 0;
        while (i < vertices.len) {
            rl.DrawPixel(
                @intFromFloat(vertices[i]),
                @intFromFloat(vertices[i + 1]),
                @bitCast(color),
            );
            i += 2;
        }
    }

    inline fn renderLine(
        vertices: []Float,
        color: Color,
    ) void {
        var i: usize = 0;
        while (i < vertices.len) {
            rl.DrawLine(
                @intFromFloat(vertices[i]),
                @intFromFloat(vertices[i + 1]),
                @intFromFloat(vertices[i + 2]),
                @intFromFloat(vertices[i + 3]),
                @bitCast(color),
            );
            i += 4;
        }
    }

    inline fn renderRect(
        vertices: []Float,
        color: Color,
        color1: ?Color,
        color2: ?Color,
        color3: ?Color,
        fill: bool,
        thickness: ?Float,
    ) void {
        var i: usize = 0;
        while (i < vertices.len) {
            if (fill) {
                rl.DrawRectangleGradientEx(
                    .{
                        .x = vertices[i],
                        .y = vertices[i + 1],
                        .width = vertices[i + 2],
                        .height = vertices[i + 3],
                    },
                    @bitCast(color),
                    @bitCast(color1 orelse color),
                    @bitCast(color2 orelse color),
                    @bitCast(color3 orelse color),
                );
            } else {
                rl.DrawRectangleLinesEx(
                    .{
                        .x = vertices[i],
                        .y = vertices[i + 1],
                        .width = vertices[i + 2],
                        .height = vertices[i + 3],
                    },
                    thickness orelse 1.0,
                    @bitCast(color),
                );
            }
            i += 4;
        }
    }

    fn renderTriangles(
        vertices: []Float,
        color: Color,
        fill: bool,
    ) void {
        var i: usize = 0;
        while (i < vertices.len) {
            if (fill) {
                rl.DrawTriangle(
                    .{ .x = vertices[i], .y = vertices[i + 1] },
                    .{ .x = vertices[i + 2], .y = vertices[i + 3] },
                    .{ .x = vertices[i + 4], .y = vertices[i + 5] },
                    @bitCast(color),
                );
            } else {
                rl.DrawTriangleLines(
                    .{ .x = vertices[i], .y = vertices[i + 1] },
                    .{ .x = vertices[i + 2], .y = vertices[i + 3] },
                    .{ .x = vertices[i + 4], .y = vertices[i + 5] },
                    @bitCast(color),
                );
            }
            i += 6;
        }
    }

    inline fn renderCircle(
        vertices: []Float,
        color: Color,
        color1: ?Color,
        fill: bool,
    ) void {
        var i: usize = 0;
        while (i < vertices.len) {
            if (fill) {
                if (color1) |gc| {
                    rl.DrawCircleGradient(
                        @intFromFloat(vertices[i]),
                        @intFromFloat(vertices[i + 1]),
                        vertices[i + 2],
                        @bitCast(color),
                        @bitCast(gc),
                    );
                } else {
                    rl.DrawCircleV(
                        .{ .x = vertices[i], .y = vertices[i + 1] },
                        vertices[2],
                        @bitCast(color),
                    );
                }
            } else {
                rl.DrawCircleLinesV(
                    .{ .x = vertices[i], .y = vertices[i + 1] },
                    vertices[i + 2],
                    @bitCast(color),
                );
            }
            i += 3;
        }
    }

    inline fn renderArc(
        vertices: []Float,
        color: Color,
        fill: bool,
    ) void {
        var i: usize = 0;
        while (i < vertices.len) {
            if (fill) {
                rl.DrawCircleSector(
                    .{ .x = vertices[i], .y = vertices[i + 1] },
                    vertices[i + 2],
                    vertices[i + 3],
                    vertices[i + 4],
                    @intFromFloat(vertices[i + 5]),
                    @bitCast(color),
                );
            } else {
                rl.DrawCircleSectorLines(
                    .{ .x = vertices[i], .y = vertices[i + 1] },
                    vertices[i + 2],
                    vertices[i + 3],
                    vertices[i + 4],
                    @intFromFloat(vertices[i + 5]),
                    @bitCast(color),
                );
            }
            i += 5;
        }
    }

    inline fn renderEllipse(
        vertices: []Float,
        color: Color,
        fill: bool,
    ) void {
        var i: usize = 0;
        while (i < vertices.len) {
            if (fill) {
                rl.DrawEllipse(
                    @intFromFloat(vertices[i]),
                    @intFromFloat(vertices[i + 1]),
                    vertices[i + 2],
                    vertices[i + 3],
                    @bitCast(color),
                );
            } else {
                rl.DrawEllipseLines(
                    @intFromFloat(vertices[i]),
                    @intFromFloat(vertices[i + 1]),
                    vertices[i + 2],
                    vertices[i + 3],
                    @bitCast(color),
                );
            }
            i += 4;
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
        buffer.print("  active_render_texture: {any}\n", .{active_render_texture});
        buffer.print("  active_clear_color: {any}\n", .{active_clear_color});
    }
};
