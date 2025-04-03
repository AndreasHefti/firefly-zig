const std = @import("std");
const firefly = @import("../../firefly.zig");
const api = firefly.api;
const rl = @cImport(@cInclude("raylib.h"));

const Float = firefly.utils.Float;
const CInt = firefly.utils.CInt;
const CUInt = firefly.utils.CUInt;

var singleton: ?api.IWindowAPI() = null;
pub fn createWindowAPI() !api.IWindowAPI() {
    if (singleton == null)
        singleton = api.IWindowAPI().init(RaylibWindowAPI.initImpl);

    return singleton.?;
}

const RaylibWindowAPI = struct {
    var initialized = false;
    var window_data: api.WindowData = undefined;

    fn initImpl(interface: *api.IWindowAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        interface.getCurrentMonitor = getCurrentMonitor;
        interface.getMonitorWidth = getMonitorWidth;
        interface.getMonitorHeight = getMonitorHeight;

        interface.openWindow = openWindow;
        interface.isWindowReady = isWindowReady;
        interface.getWindowData = getWindowData;
        interface.closeWindow = closeWindow;

        interface.hasWindowClosed = hasWindowClosed;
        interface.isWindowResized = isWindowResized;
        interface.isWindowFullscreen = isWindowFullscreen;
        interface.isWindowHidden = isWindowHidden;
        interface.isWindowMinimized = isWindowMinimized;
        interface.isWindowMaximized = isWindowMaximized;
        interface.isWindowFocused = isWindowFocused;
        interface.isWindowState = isWindowState;

        interface.getScreenWidth = getScreenWidth;
        interface.getScreenHeight = getScreenHeight;
        interface.getRenderWidth = getRenderWidth;
        interface.getRenderHeight = getRenderHeight;
        interface.getWindowPosition = getWindowPosition;
        interface.getWindowScaleDPI = getWindowScaleDPI;

        interface.setWindowSize = setWindowSize;
        interface.restoreWindow = restoreWindow;

        interface.showFPS = showFPS;
        interface.getFPS = getFPS;
        interface.toggleFullscreen = toggleFullscreen;
        interface.toggleBorderlessWindowed = toggleBorderlessWindowed;
        interface.setWindowFlags = setWindowFlags;
        interface.setOpacity = setOpacity;
        interface.setExitKey = setExitKey;

        interface.deinit = deinit;
    }

    fn deinit() void {}

    fn getCurrentMonitor() CInt {
        return rl.GetCurrentMonitor();
    }

    fn getMonitorWidth(m: CInt) CInt {
        return rl.GetMonitorWidth(m);
    }

    fn getMonitorHeight(m: CInt) CInt {
        return rl.GetMonitorHeight(m);
    }

    fn openWindow(data: api.WindowData) void {
        if (!initialized)
            @panic("Not initialized");

        const title = firefly.api.ALLOC.dupeZ(u8, window_data.title) catch |err| firefly.api.handleUnknownError(err);
        defer firefly.api.ALLOC.free(title);

        window_data = data;
        rl.SetTargetFPS(window_data.fps);
        rl.InitWindow(
            window_data.width,
            window_data.height,
            title,
        );
        if (data.icon) |icon| {
            const ic = firefly.api.ALLOC.dupeZ(u8, icon) catch |err| firefly.api.handleUnknownError(err);
            defer firefly.api.ALLOC.free(ic);
            rl.SetWindowIcon(rl.LoadImage(ic));
        }

        if (window_data.flags) |wf|
            setWindowFlags(wf);

        const pos = rl.GetWindowPosition();
        window_data.position = @bitCast(pos);
    }

    fn isWindowReady() bool {
        return rl.IsWindowReady();
    }

    fn hasWindowClosed() bool {
        return rl.WindowShouldClose();
    }

    fn isWindowResized() bool {
        return rl.IsWindowResized();
    }

    fn isWindowFullscreen() bool {
        return rl.IsWindowFullscreen();
    }

    fn isWindowHidden() bool {
        return rl.IsWindowHidden();
    }

    fn isWindowMinimized() bool {
        return rl.IsWindowMinimized();
    }

    fn isWindowMaximized() bool {
        return rl.IsWindowMaximized();
    }

    fn isWindowFocused() bool {
        return rl.IsWindowFocused();
    }

    fn isWindowState(state: CUInt) bool {
        return rl.IsWindowState(state);
    }

    fn getWindowData() *api.WindowData {
        return &window_data;
    }

    fn closeWindow() void {
        defer initialized = false;
        if (!initialized)
            @panic("Not initialized");

        if (rl.IsWindowReady())
            rl.CloseWindow();

        singleton = null;
    }

    fn getScreenWidth() CInt {
        return rl.GetScreenWidth();
    }
    fn getScreenHeight() CInt {
        return rl.GetScreenHeight();
    }

    fn getRenderWidth() CInt {
        return rl.GetRenderWidth();
    }

    fn getRenderHeight() CInt {
        return rl.GetRenderHeight();
    }

    fn getWindowPosition() firefly.utils.Vector2f {
        return @bitCast(rl.GetWindowPosition());
    }

    fn getWindowScaleDPI() firefly.utils.Vector2f {
        return @bitCast(rl.GetWindowScaleDPI());
    }

    fn showFPS(x: CInt, y: CInt) void {
        rl.DrawFPS(x, y);
    }

    fn getFPS() Float {
        return @floatFromInt(rl.GetFPS());
    }

    fn toggleFullscreen() void {
        rl.ToggleFullscreen();
    }

    fn toggleBorderlessWindowed() void {
        rl.ToggleBorderlessWindowed();
    }

    fn setOpacity(o: Float) void {
        rl.SetWindowOpacity(o);
    }

    fn setExitKey(key: api.KeyboardKey) void {
        rl.SetExitKey(firefly.utils.usize_cint(@intFromEnum(key)));
    }

    fn setWindowFlags(flags: []const api.WindowFlag) void {
        var flag: CUInt = 0;
        for (flags) |f|
            flag |= @intFromEnum(f);
        rl.SetWindowState(flag);
    }

    fn setWindowSize(w: CInt, h: CInt) void {
        rl.SetWindowSize(w, h);
    }

    fn restoreWindow() void {
        if (rl.IsWindowFullscreen()) {
            rl.ToggleFullscreen();
        }

        rl.SetWindowSize(window_data.width, window_data.height);
        if (window_data.position) |pos| {
            rl.SetWindowPosition(firefly.utils.f32_cint(pos[0]), firefly.utils.f32_cint(pos[1]));
        }
        if (rl.IsWindowState(@intFromEnum(api.WindowFlag.FLAG_BORDERLESS_WINDOWED_MODE))) {
            rl.ToggleBorderlessWindowed();
        }
    }
};
