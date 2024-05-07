const std = @import("std");
const firefly = @import("../../firefly.zig");
const rl = @cImport(@cInclude("raylib.h"));
const utils = firefly.utils;
const api = firefly.api;

const IWindowAPI = api.IWindowAPI;
const WindowData = api.WindowData;
const CInt = utils.CInt;
const CUInt = utils.CUInt;
const WindowFlag = api.WindowFlag;

var singleton: ?IWindowAPI() = null;
pub fn createWindowAPI() !IWindowAPI() {
    if (singleton == null)
        singleton = IWindowAPI().init(RaylibWindowAPI.initImpl);

    return singleton.?;
}

const RaylibWindowAPI = struct {
    var initialized = false;
    var window_data: WindowData = undefined;

    fn initImpl(interface: *IWindowAPI()) void {
        defer initialized = true;
        if (initialized)
            return;

        interface.openWindow = openWindow;
        interface.hasWindowClosed = hasWindowClosed;
        interface.getWindowData = getWindowData;
        interface.closeWindow = closeWindow;

        interface.showFPS = showFPS;
        interface.toggleFullscreen = toggleFullscreen;
        interface.toggleBorderlessWindowed = toggleBorderlessWindowed;
        interface.setWindowFlags = setWindowFlags;

        interface.deinit = deinit;
    }

    fn deinit() void {}

    fn openWindow(data: WindowData) void {
        if (!initialized)
            @panic("Not initialized");

        window_data = data;
        if (window_data.flags) |wf|
            setWindowFlags(wf);
        rl.SetTargetFPS(window_data.fps);
        rl.InitWindow(window_data.width, window_data.height, window_data.title);
    }

    fn hasWindowClosed() bool {
        return rl.WindowShouldClose();
    }

    fn getWindowData() *WindowData {
        return &window_data;
    }

    fn closeWindow() void {
        defer initialized = false;
        if (!initialized)
            @panic("Not initialized");

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

    fn setWindowFlags(flags: []const WindowFlag) void {
        var flag: CUInt = 0;
        for (flags) |f|
            flag |= @intFromEnum(f);
        rl.SetWindowState(flag);
    }
};
