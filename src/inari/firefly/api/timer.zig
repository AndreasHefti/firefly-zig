const std = @import("std");
const firefly = @import("../firefly.zig");

const Float = firefly.utils.Float;

/// With FrameScheduler you can schedule on a fixed frame resolution.
/// For example if you use 2 as frame resolution needsUpdate will give you true for every second frame
///
/// Please note that this applies directly on frame and frame rate. If the frame rate itself is unstable
/// this will also be unstable. If you want to use frame rate independent update you need to use delta time.
/// The d_time of the timer itself refers to the overall frame rate and not of the a FrameScheduler resolution.
/// If you need a delta time regarding to a FrameScheduler you need to implement and update it yourself.
pub const FrameScheduler = struct {
    resolution: usize = 1,

    pub fn needsUpdate(self: *FrameScheduler) bool {
        return @mod(ticks, self.resolution) == 0;
    }
};

var initialized = false;
var scheduler: std.ArrayList(FrameScheduler) = undefined;

var last_update_time: usize = undefined;
pub var time: usize = 0;
pub var d_time: usize = 0;
pub var ticks: usize = 0;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    scheduler = std.ArrayList(FrameScheduler).init(firefly.api.ALLOC);
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
    ticks = 0;
    last_update_time = firefly.utils.i64_usize(std.time.milliTimestamp());
}

pub fn tick() void {
    const current_time: usize = firefly.utils.i64_usize(std.time.milliTimestamp());
    time += d_time;
    d_time = current_time - last_update_time;
    last_update_time = current_time;
    ticks += 1;
}

pub fn getScheduler(resolution: usize) *FrameScheduler {
    // try to find scheduler with same resolution
    for (scheduler.items) |*s| {
        if (s.resolution == resolution) {
            return s;
        }
    }

    // otherwise create new one
    scheduler.append(FrameScheduler{ .resolution = resolution }) catch |err| firefly.api.handleUnknownError(err);
    return &scheduler.items[scheduler.items.len - 1];
}
