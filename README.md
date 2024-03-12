# firefly-zig

![](inari.gif)

Example Code:

``` zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

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

}
```

