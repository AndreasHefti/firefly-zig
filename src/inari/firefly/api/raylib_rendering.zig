const std = @import("std");
const inari = @import("../../inari.zig");
const rl = @cImport(@cInclude("raylib.h"));
const utils = inari.utils;
const api = inari.firefly.api;

const RenderAPI = api.RenderAPI;
const Vector2f = utils.Vector2f;
const RenderData = api.RenderData;
const TextureData = api.TextureData;
const ShaderData = api.ShaderData;
const RenderTextureData = api.RenderTextureData;
const Projection = api.Projection;
const BindingId = api.BindingId;
const DynArray = utils.DynArray;
const CInt = utils.CInt;
const PosI = utils.PosI;
const NO_BINDING = api.NO_BINDING;

const Texture2D = rl.Texture2D;
const RenderTexture2D = rl.RenderTexture2D;
const Shader = rl.Shader;

const RaylibRenderAPI = struct {
    var initialized = false;

    fn initImpl(interface: *RenderAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        textures = DynArray(Texture2D).new(api.ALLOC, null) catch unreachable;
        renderTextures = DynArray(RenderTexture2D).new(api.ALLOC, null) catch unreachable;
        shaders = DynArray(Shader).new(api.ALLOC, null) catch unreachable;

        interface.screenWidth = screenWidth;
        interface.screenHeight = screenHeight;
        interface.showFPS = showFPS;

        interface.loadTexture = loadTexture;
        interface.disposeTexture = disposeTexture;
        interface.createRenderTexture = createRenderTexture;
        interface.disposeRenderTexture = disposeRenderTexture;
        interface.createShader = createShader;
        interface.disposeShader = disposeShader;

        interface.startRendering = startRendering;
        interface.setActiveShader = setActiveShader;
        interface.setOffset = setOffset;
        interface.addOffset = addOffset;
        interface.removeOffset = removeOffset;
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
    }

    const default_offset = Vector2f{ 0, 0 };
    const default_render_data = RenderData{};

    var textures: DynArray(Texture2D) = undefined;
    var renderTextures: DynArray(RenderTexture2D) = undefined;
    var shaders: DynArray(Shader) = undefined;

    var currentRenderTexture: ?BindingId = null;
    var currentShader: ?BindingId = null;
    var currentProjection: *const Projection = &Projection{};
    var currentOffset: *const Vector2f = &default_offset;
    var currentRenderData: *const RenderData = &default_render_data;

    pub fn screenWidth() CInt {
        return rl.GetScreenWidth();
    }

    pub fn screenHeight() CInt {
        return rl.GetScreenHeight();
    }

    pub fn showFPS(pos: *PosI) void {
        rl.DrawFPS(@bitCast(pos[0]), @bitCast(pos[1]));
    }

    pub fn loadTexture(td: *TextureData) void {
        var tex = rl.LoadTexture(@ptrCast(td.resource));
        td.width = @bitCast(tex.width);
        td.height = @bitCast(tex.height);

        if (td.is_mipmap) {
            rl.GenTextureMipmaps(&tex);
        }

        if (td.mag_filter > 0) {
            rl.SetTextureFilter(tex, td.mag_filter);
        }
        if (td.min_filter > 0) {
            rl.SetTextureFilter(tex, td.min_filter);
        }
        if (td.s_wrap > 0) {
            rl.SetTextureWrap(tex, td.s_wrap);
        }
        if (td.t_wrap > 0) {
            rl.SetTextureWrap(tex, td.t_wrap);
        }

        td.binding = textures.add(tex);
    }

    pub fn disposeTexture(td: *TextureData) void {
        if (td.binding == NO_BINDING)
            return;

        var tex = textures.get(td.binding);
        rl.UnloadTexture(tex);
        textures.reset(td.binding);
        td.binding = NO_BINDING;
    }

    pub fn createRenderTexture(td: *RenderTextureData) void {
        var tex = rl.LoadRenderTexture(td.width, td.height);
        td.binding = renderTextures.add(tex);
    }

    pub fn disposeRenderTexture(td: *RenderTextureData) void {
        if (td.binding == NO_BINDING)
            return;

        var tex = textures.get(td.binding);
        rl.UnloadRenderTexture(tex);
        renderTextures.remove(td.binding);
        td.binding = NO_BINDING;
    }

    pub fn createShader(sd: *ShaderData) void {
        var shader: Shader = undefined;
        if (sd.file_resource) {
            shader = rl.LoadShader(
                @ptrCast(sd.vertex_shader_resource),
                @ptrCast(sd.fragment_shader_resource),
            );
        } else {
            shader = rl.LoadShaderFromMemory(
                @ptrCast(sd.vertex_shader_resource),
                @ptrCast(sd.fragment_shader_resource),
            );
        }

        sd.binding = shaders.add(shader);
    }

    pub fn disposeShader(sd: *ShaderData) void {
        if (sd.binding == NO_BINDING)
            return;

        var shader = shaders.get(sd.binding);
        rl.UnloadShader(shader);
        shaders.reset(sd.binding);
        sd.binding = NO_BINDING;
    }
};
