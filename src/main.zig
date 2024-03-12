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
const EAnimation = firefly.physics.EAnimation;
const Animation = firefly.physics.Animation;
const AnimationSystem = firefly.physics.AnimationSystem;
const IAnimation = firefly.physics.IAnimation;
const EasedValueIntegration = firefly.physics.EasedValueIntegration;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    //try Example_Test_Hello_Zig_Window(allocator);
    try Example_One_Entity_No_Views(allocator);
}

fn Example_Test_Hello_Zig_Window(allocator: Allocator) !void {
    try firefly.init(
        allocator,
        allocator,
        allocator,
        firefly.api.InitMode.DEVELOPMENT,
    );
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Zig", null);
}

fn Example_One_Entity_No_Views(allocator: Allocator) !void {
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
        .withComponent(ETransform{ .transform = .{
        .position = .{ 64, 164 },
        .scale = .{ 4, 4 },
        .pivot = .{ 16, 16 },
        .rotation = 180,
    } })
        .withComponent(ESprite.fromAsset(sprite_asset))
        .withComponentAnd(EAnimation{})
        .withAnimation(.{
        .duration = 1000,
        .looping = true,
        .inverse_on_loop = true,
        .active_on_init = true,
    }, EasedValueIntegration{
        .start_value = 164.0,
        .end_value = 264.0,
        .easing = utils.Easing_Linear,
        .property_ref = ETransform.Property.XPos,
    })
        .withAnimationAnd(.{
        .duration = 2000,
        .looping = true,
        .inverse_on_loop = true,
        .active_on_init = true,
    }, EasedValueIntegration{
        .start_value = 0.0,
        .end_value = 180.0,
        .easing = utils.Easing_Linear,
        .property_ref = ETransform.Property.Rotation,
    })
        .activate();

    //AnimationSystem.activateById(0, false);
    AnimationSystem.setLoopCallbackById(1, loopCallback1);
}

fn loopCallback1(count: usize) void {
    std.log.info("Loop: {any}", .{count});
}

test "API Tests" {
    std.testing.refAllDecls(@import("inari/libtest.zig"));
}
