const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;

const ArrayList = std.ArrayList;
const Float = utils.Float;

pub const UpdateScheduler = struct {
    resolution: Float = 60,
    needs_update: bool = false,
    ticks: usize = 0,
    last_update: usize = 0,
    fn update(self: *UpdateScheduler) void {
        if (lastUpdateTime - self.last_update >= 1000 / self.resolution) {
            self.last_update = lastUpdateTime;
            self.ticks += 1;
            self.needs_update = true;
        } else self.needs_update = false;
    }
};

var initialized = false;
var lastUpdateTime: usize = undefined;
var scheduler: ArrayList(UpdateScheduler) = undefined;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    scheduler = ArrayList(UpdateScheduler).init(api.ALLOC);
    lastUpdateTime = utils.i64_usize(std.time.milliTimestamp());
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    scheduler.deinit();
}

pub var time: usize = 0;
pub var timeElapsed: usize = 0;

pub fn tick() void {
    var currentTime: usize = utils.i64_usize(std.time.milliTimestamp());
    time += timeElapsed;
    timeElapsed = currentTime - lastUpdateTime;
    lastUpdateTime = currentTime;
}

pub fn update() void {
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
