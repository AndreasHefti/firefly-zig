const std = @import("std");
const inari = @import("inari/inari.zig");
const firefly = inari.firefly;
const utils = inari.utils;
const Asset = firefly.api.Asset;
const TextureAsset = firefly.graphics.TextureAsset;
const SpriteAsset = firefly.graphics.SpriteAsset;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;

pub fn main() !void {
    //try Example_Test_Hello_Zig_Window();
    try Example_One_Entity_No_Views();
}

fn Example_Test_Hello_Zig_Window() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try firefly.init(
        allocator,
        allocator,
        allocator,
        firefly.api.InitMode.DEVELOPMENT,
    );
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Zig");
}

fn Example_One_Entity_No_Views() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try firefly.init(
        allocator,
        allocator,
        allocator,
        firefly.api.InitMode.DEVELOPMENT,
    );
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Sprite", _Example_One_Entity_No_Views);
}

fn _Example_One_Entity_No_Views() void {
    var texture_asset: *Asset = TextureAsset.new(.{
        .name = "TestTexture",
        .resource_path = "resources/logo.png",
        .is_mipmap = false,
    });

    var sprite_asset: *Asset = SpriteAsset.new(.{
        .name = "TestSprite",
        .texture_asset_id = texture_asset.id,
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    _ = Entity.new(.{ .name = "TestEntity" })
        .withComponent(ETransform{ .transform = .{ .position = .{ 64, 64 }, .scale = .{ 4, 4 }, .pivot = .{ 16, 16 }, .rotation = 180 } })
        .withComponent(ESprite.fromAsset(sprite_asset))
        .activate();
}

test "API Tests" {
    std.testing.refAllDecls(@import("inari/libtest.zig"));
}
