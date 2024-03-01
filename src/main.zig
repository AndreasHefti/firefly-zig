const std = @import("std");
pub const inari = @import("inari/inari.zig");
const rl = @cImport(@cInclude("raylib.h"));

pub fn main() !void {
    // raylib binding
    rl.InitWindow(960, 540, "Hello Zig Hello Firefly");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        rl.BeginMode2D(rl.Camera2D{
            .offset = rl.Vector2{
                .x = 0,
                .y = 0,
            },
            .target = rl.Vector2{
                .x = 0,
                .y = 0,
            },
            .rotation = 10,
            .zoom = 1,
        });
        rl.ClearBackground(rl.BLACK);
        rl.DrawFPS(10, 10);
        rl.DrawText("Hello Zig Hello Firefly", 100, 100, 100, rl.RED);
        rl.EndMode2D();
        rl.EndDrawing();
    }
}

test {
    std.testing.refAllDecls(@import("inari/libtest.zig"));
}
