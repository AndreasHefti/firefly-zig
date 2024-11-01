const std = @import("std");
const firefly = @import("../firefly.zig");

const Float = firefly.utils.Float;

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
var scheduler: std.ArrayList(UpdateScheduler) = undefined;

var last_update_time: usize = undefined;
pub var time: usize = 0;
pub var d_time: usize = 0;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    scheduler = std.ArrayList(UpdateScheduler).init(firefly.api.ALLOC);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    scheduler.deinit();
}

pub fn reset() void {
    time = 0;
    d_time = 0;
    last_update_time = firefly.utils.i64_usize(std.time.milliTimestamp());
}

pub fn tick() void {
    const current_time: usize = firefly.utils.i64_usize(std.time.milliTimestamp());
    time += d_time;
    d_time = current_time - last_update_time;
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
