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
        if (last_update_time - self.last_update >= @as(usize, @intFromFloat(1000 / self.resolution))) {
            self.last_update = last_update_time;
            self.ticks += 1;
            self.needs_update = true;
        } else self.needs_update = false;
    }
};

var initialized = false;
var last_update_time: usize = undefined;
var scheduler: ArrayList(UpdateScheduler) = undefined;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    scheduler = ArrayList(UpdateScheduler).init(api.ALLOC);
    last_update_time = utils.i64_usize(std.time.milliTimestamp());
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    scheduler.deinit();
}

pub var time: usize = 0;
pub var time_elapsed: usize = 0;

pub fn tick() void {
    const current_time: usize = utils.i64_usize(std.time.milliTimestamp());
    time += time_elapsed;
    time_elapsed = current_time - last_update_time;
    last_update_time = current_time;
    // update schedulers
    for (scheduler.items) |*s| s.update();
}

pub fn getScheduler(resolution: Float) *UpdateScheduler {
    // try to find scheduler with same resolution
    for (scheduler.items) |*s| {
        if (s.resolution == resolution) {
            return s;
        }
    }

    // otherwise create new one
    scheduler.append(UpdateScheduler{ .resolution = resolution }) catch unreachable;
    return &scheduler.items[scheduler.items.len - 1];
}
