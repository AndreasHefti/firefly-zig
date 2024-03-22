# firefly-zig

TODO:

  - Refactor System like Asset but for singletons DONE!
  - Refactor Shader handling like Texture handling DONE!
  - Test Viewport rendering (render to texture) DONE!
  - Reimplement Asset(Shader) and Asset(SpriteSet)
  - Adapt old tests DONE!
  - Go on with porting from FlyKo

 
 ##Code Example:

![](inari.gif)

``` zig
var sprite_id = SpriteTemplate.new(.{
    .texture_asset_name = "TestTexture",
    .sprite_data = .{ .texture_bounds = utils.RectF{ 0, 0, 32, 32 } },
});

Texture.newAnd(.{
    .name = "TestTexture",
    .resource = "resources/logo.png",
    .is_mipmap = false,
}).load();

_ = Entity.newAnd(.{ .name = "TestEntity" })
    .with(ETransform{ .transform = .{ .position = .{ 64, 164 }, .scale = .{ 4, 4 }, .pivot = .{ 16, 16 }, .rotation = 180 } })
    .with(ESprite{ .template_id = sprite_id })
    .withAnd(EAnimation{})
    .withAnimation(
    .{ .duration = 1000, .looping = true, .inverse_on_loop = true, .active_on_init = true },
    EasedValueIntegration{ .start_value = 164.0, .end_value = 264.0, .easing = Easing.Linear, .property_ref = ETransform.Property.XPos },
)
    .withAnimationAnd(
    .{ .duration = 2000, .looping = true, .inverse_on_loop = true, .active_on_init = true },
    EasedValueIntegration{ .start_value = 0.0, .end_value = 180.0, .easing = Easing.Linear, .property_ref = ETransform.Property.Rotation },
)
    .activate();
```

