const std = @import("std");
const ArrayList = std.ArrayList;

const api = @import("api.zig");
const utils = api.utils;
const Float = utils.Float;

const UpdateScheduler = struct {
    resolution: Float = 60,
    needsUpdate: bool = false,
    ticks: i64 = 0,
    lastUpdate: i64 = 0,
    fn update(self: *UpdateScheduler) void {
        if (lastUpdateTime - self.lastUpdate >= 1000 / self.resolution) {
            self.lastUpdate = lastUpdateTime;
            self.ticks += 1;
            self.needsUpdate = true;
        } else self.needsUpdate = false;
    }
};

var initialized = false;
var lastUpdateTime = std.time.milliTimestamp();
var scheduler: ArrayList(UpdateScheduler) = undefined;

pub fn init() void {
    defer initialized = true;
    if (initialized) return;
    scheduler = ArrayList(UpdateScheduler).init(api.ALLOC);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized) return;
    scheduler.deinit();
}

pub var time: i64 = 0;
pub var timeElapsed: i64 = 0;

pub fn tick() void {
    var currentTime = std.time.milliTimestamp();
    time += timeElapsed;
    timeElapsed = currentTime - lastUpdateTime;
    lastUpdateTime = currentTime;
}

pub fn updateScheduler() void {
    for (scheduler.items) |*s| {
        s.update();
    }
}

pub fn getScheduler(resolution: Float) *UpdateScheduler {
    // try to find scheduler with same resolution
    for (scheduler.items) |*s| {
        if (s.resolution == resolution) {
            return s;
        }
    }

    // otherwise create new one
    scheduler.append(UpdateScheduler{
        .resolution = resolution,
    });
    return &scheduler.items[scheduler.items.len - 1];
}
