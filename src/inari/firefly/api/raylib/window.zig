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

        interface.showFPS = showFPS;
        interface.toggleFullscreen = toggleFullscreen;
        interface.toggleBorderlessWindowed = toggleBorderlessWindowed;
        interface.setWindowFlags = setWindowFlags;
        interface.setOpacity = setOpacity;

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

        window_data = data;
        rl.SetTargetFPS(window_data.fps);
        rl.InitWindow(window_data.width, window_data.height, window_data.title);
        if (window_data.flags) |wf|
            setWindowFlags(wf);
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

    fn showFPS(x: CInt, y: CInt) void {
        rl.DrawFPS(x, y);
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

    fn setWindowFlags(flags: []const api.WindowFlag) void {
        var flag: CUInt = 0;
        for (flags) |f|
            flag |= @intFromEnum(f);
        rl.SetWindowState(flag);
    }
};
