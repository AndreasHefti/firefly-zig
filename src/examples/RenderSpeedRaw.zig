const std = @import("std");
const rl = @cImport(@cInclude("raylib.h"));
const firefly = @import("../inari/firefly/firefly.zig");
const Allocator = std.mem.Allocator;

const count: usize = 100000;

pub fn run(init_c: firefly.api.InitContext) !void {
    rl.InitWindow(960, 540, "Render Speed Raw");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    const resName: []const u8 = "resources/logo.png";
    const tex = rl.LoadTexture(@ptrCast(resName));
    const tint_color: rl.Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 };
    const clear_color: rl.Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 };

    var nanos = init_c.allocator.alloc(
        @Vector(4, f32),
        count,
    ) catch |err| firefly.api.handleUnknownError(err);

    defer init_c.allocator.free(nanos);
    var rndx = std.Random.DefaultPrng.init(32);
    const rx = rndx.random();
    for (0..count) |i| {
        nanos[i][0] = 0;
        nanos[i][1] = 0;
        nanos[i][2] = rx.float(f32) * 5;
        nanos[i][3] = rx.float(f32) * 5;
    }

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.ClearBackground(clear_color);

        for (0..count) |i| {
            rl.DrawTexturePro(
                tex,
                rl.Rectangle{ .x = 0, .y = 0, .width = 32, .height = 32 },
                rl.Rectangle{ .x = nanos[i][0], .y = nanos[i][1], .width = 32, .height = 32 },
                rl.Vector2{ .x = 0, .y = 0 },
                0,
                tint_color,
            );
        }
        rl.DrawFPS(10, 10);
        rl.EndDrawing();

        // update
        for (0..count) |i| {
            nanos[i][0] += nanos[i][2];
            nanos[i][1] += nanos[i][3];

            if (nanos[i][0] > 900 or nanos[i][0] < 0) nanos[i][2] *= -1;
            if (nanos[i][1] > 500 or nanos[i][1] < 0) nanos[i][3] *= -1;
        }
    }
}
