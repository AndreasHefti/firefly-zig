const std = @import("std");
const inari = @import("../../../inari.zig");
const rl = @cImport(@cInclude("raylib.h"));

const utils = inari.utils;
const api = inari.firefly.api;

const String = utils.String;
const IRenderAPI = api.IRenderAPI;
const Vector2f = utils.Vector2f;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const RenderData = api.RenderData;
const TextureBinding = api.TextureBinding;
const TransformData = api.TransformData;
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

const Texture2D = rl.Texture2D;
const RenderTexture2D = rl.RenderTexture2D;
const Shader = rl.Shader;

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

        active_offset = default_offset;
        active_blend_mode = default_blend_mode;

        textures = DynArray(Texture2D).new(api.ALLOC) catch unreachable;
        render_textures = DynArray(RenderTexture2D).new(api.ALLOC) catch unreachable;
        shaders = DynArray(Shader).new(api.ALLOC) catch unreachable;

        interface.setOffset = setOffset;
        interface.addOffset = addOffset;
        interface.setBaseProjection = setBaseProjection;

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

    var window_handle: ?api.WindowHandle = null;

    var default_offset = Vector2f{ 0, 0 };
    var default_render_data = RenderData{};
    var default_projection = Projection{};
    var default_blend_mode = BlendMode.ALPHA;

    var textures: DynArray(Texture2D) = undefined;
    var render_textures: DynArray(RenderTexture2D) = undefined;
    var shaders: DynArray(Shader) = undefined;

    var active_shader: ?BindingId = null;
    var active_render_texture: ?BindingId = null;
    //var active_projection: Projection = undefined;
    var active_offset: Vector2f = undefined;
    var active_tint_color: rl.Color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    var active_clear_color: ?rl.Color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
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

    fn setOffset(offset: Vector2f) void {
        active_offset = offset;
    }

    fn addOffset(offset: Vector2f) void {
        active_offset += offset;
    }

    fn setBaseProjection(projection: Projection) void {
        default_projection = projection;
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

    fn createRenderTexture(width: CInt, height: CInt) RenderTextureBinding {
        var tex = rl.LoadRenderTexture(width, height);
        var id = render_textures.add(tex);
        return RenderTextureBinding{
            .id = id,
            .width = width,
            .height = height,
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

    fn createShader(
        vertex_shader: String,
        fragment_shade: String,
        file: bool,
    ) BindingId {
        var shader: Shader = undefined;
        if (file) {
            shader = rl.LoadShader(
                @ptrCast(vertex_shader),
                @ptrCast(fragment_shade),
            );
        } else {
            shader = rl.LoadShaderFromMemory(
                @ptrCast(vertex_shader),
                @ptrCast(fragment_shade),
            );
        }

        return shaders.add(shader);
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

    fn startRendering(binding_id: ?BindingId, projection: ?*const Projection) void {
        active_render_texture = binding_id;
        if (projection) |p| {
            active_camera.offset = @bitCast(p.offset);
            active_camera.target = @bitCast(p.pivot);
            active_camera.rotation = p.rotation;
            active_camera.zoom = p.zoom;
            active_clear_color = if (p.clear_color != null) @bitCast(p.clear_color.?) else null;
        } else {
            active_camera.offset = @bitCast(default_projection.offset);
            active_camera.target = @bitCast(default_projection.pivot);
            active_camera.rotation = default_projection.rotation;
            active_camera.zoom = default_projection.zoom;
            active_clear_color = if (default_projection.clear_color != null) @bitCast(default_projection.clear_color.?) else null;
        }

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
        binding_id: BindingId,
        transform: *const TransformData,
        render_data: ?*const RenderData,
        offset: ?Vector2f,
    ) void {
        if (render_textures.get(binding_id)) |tex| {

            // set offset
            if (offset) |o|
                active_offset += o;
            active_offset += transform.position;

            // set render data
            if (render_data) |rd| {
                active_tint_color = @bitCast(rd.tint_color);
                if (active_blend_mode != rd.blend_mode) {
                    rl.BeginBlendMode(@intFromEnum(active_blend_mode));
                    active_blend_mode = rd.blend_mode;
                }
            }

            // set source rect
            temp_source_rect.x = 0;
            temp_source_rect.y = 0;
            temp_source_rect.width = @floatFromInt(tex.texture.width);
            // NOTE: render to texture has inverted y axis.
            temp_source_rect.height = @floatFromInt(-tex.texture.height);
            // set destination rect
            if (transform.scale[0] != 1 or transform.scale[1] != 1) {
                temp_dest_rect.x = active_offset[0];
                temp_dest_rect.y = active_offset[1];
                temp_dest_rect.width = transform.scale[0] * @as(Float, @floatFromInt(tex.texture.width));
                temp_dest_rect.height = transform.scale[1] * @as(Float, @floatFromInt(tex.texture.height));
                temp_pivot = @bitCast(transform.pivot * transform.scale);
            } else {
                temp_dest_rect.x = active_offset[0];
                temp_dest_rect.y = active_offset[1];
                temp_dest_rect.width = @floatFromInt(tex.texture.width);
                temp_dest_rect.height = @floatFromInt(tex.texture.height);
                temp_pivot = @bitCast(transform.pivot);
            }

            //void DrawTexturePro(Texture2D texture, Rectangle source, Rectangle dest, Vector2 origin, float rotation, Color tint)
            rl.DrawTexturePro(tex.texture, temp_source_rect, temp_dest_rect, temp_pivot, transform.rotation, active_tint_color);

            // reset offset
            if (offset) |o|
                active_offset -= o;
            active_offset -= transform.position;
        }
    }

    fn renderSprite(
        sprite_data: *const SpriteData,
        transform: *const TransformData,
        render_data: ?*const RenderData,
        offset: ?Vector2f,
    ) void {
        if (textures.get(sprite_data.texture_binding)) |tex| {
            // set offset
            if (offset) |o|
                active_offset += o;
            active_offset += transform.position;

            // set render data
            if (render_data) |rd| {
                active_tint_color = @bitCast(rd.tint_color);
                if (active_blend_mode != rd.blend_mode) {
                    rl.BeginBlendMode(@intFromEnum(active_blend_mode));
                    active_blend_mode = rd.blend_mode;
                }
            }

            // set source rect
            // TODO try to directly set value with cast
            temp_source_rect.x = sprite_data.texture_bounds[0];
            temp_source_rect.y = sprite_data.texture_bounds[1];
            temp_source_rect.width = sprite_data.texture_bounds[2];
            temp_source_rect.height = sprite_data.texture_bounds[3];
            // set destination rect
            if (transform.scale[0] != 1 or transform.scale[1] != 1) {
                temp_dest_rect.x = active_offset[0]; // + (transform.pivot[0] * transform.scale[0]);
                temp_dest_rect.y = active_offset[1]; // + (transform.pivot[1] * transform.scale[1]);
                temp_dest_rect.width = sprite_data.texture_bounds[2] * transform.scale[0];
                temp_dest_rect.height = sprite_data.texture_bounds[3] * transform.scale[1];
                temp_pivot = @bitCast(transform.pivot * transform.scale);
            } else {
                temp_dest_rect.x = active_offset[0];
                temp_dest_rect.y = active_offset[1];
                temp_dest_rect.width = sprite_data.texture_bounds[2];
                temp_dest_rect.height = sprite_data.texture_bounds[3];
                temp_pivot = @bitCast(transform.pivot);
            }

            //void DrawTexturePro(Texture2D texture, Rectangle source, Rectangle dest, Vector2 origin, float rotation, Color tint)
            //std.log.info("***************** renderSprite: temp_source_rect {any} temp_dest_rect {any}", .{ temp_source_rect, temp_dest_rect });
            rl.DrawTexturePro(tex.*, temp_source_rect, temp_dest_rect, temp_pivot, transform.rotation, active_tint_color);

            // reset offset
            if (offset) |o|
                active_offset -= o;
            active_offset -= transform.position;
        }
    }

    fn endRendering() void {
        if (active_render_texture) |_| {
            rl.EndTextureMode();
            active_render_texture = null;
        } else {
            rl.EndMode2D();
            rl.EndDrawing();
        }

        // TODO something else?
    }

    fn printDebug(buffer: *StringBuffer) void {
        buffer.append("Raylib Renderer:\n");
        buffer.print("  default_offset: {any}\n", .{default_offset});
        buffer.print("  default_render_data: {any}\n", .{default_render_data});
        buffer.print("  default_projection: {any}\n", .{default_projection});
        buffer.print("  default_blend_mode: {any}\n\n", .{default_blend_mode});

        buffer.print("  textures: {any}\n", .{textures});
        buffer.print("  render_textures: {any}\n", .{default_projection});
        buffer.print("  shaders: {any}\n\n", .{shaders});

        buffer.print("  active_camera: {any}\n", .{active_camera});
        buffer.print("  active_shader: {any}\n", .{active_shader});
        buffer.print("  active_render_texture: {any}\n", .{active_render_texture});
        buffer.print("  active_offset: {any}\n", .{active_offset});
        buffer.print("  active_tint_color: {any}\n", .{active_tint_color});
        buffer.print("  active_clear_color: {any}\n", .{active_clear_color});
        buffer.print("  active_blend_mode: {any}\n", .{active_blend_mode});
    }
};
