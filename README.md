# firefly-zig

Firefly is a 2D Game API and engine strongly based on ECS design. Uses Raylib under the hood 

Note: Firefly is unter heavy development and way far from release or completed feature set. 

TODO:
  - Reimplement Asset(Shader) and Asset(SpriteSet)
  - Go on with porting from FlyKo
      - ~~Tiles~~
      - ~~Text~~
      - ~~Shapes~~
      - ~~Move Collision-Detection~~ and Collision-Resolving
      - ~~Audio~~
      - Behavior and ~~State Engine~~
      - ~~TileMap~~ and WorldMap
      - ...

 
 ## Code Example:

![](inari.gif)

``` zig
var sprite_id = SpriteTemplate.new(.{
    .texture_asset_name = "TestTexture",
    .sprite_data = .{ .texture_bounds = .{ 0, 0, 32, 32 } },
});

Texture.newAnd(.{
    .name = "TestTexture",
    .resource = "resources/logo.png",
    .is_mipmap = false,
}).load();

_ = Entity.newAnd(.{ .name = "TestEntity" })
    .with(ETransform{ .position = .{ 64, 164 }, .scale = .{ 4, 4 }, .pivot = .{ 16, 16 }, .rotation = 180 } )
    .with(ESprite{ .template_id = sprite_id })
    .withAnd(EAnimation{})
    .withAnimation(
        .{ .duration = 1000, .looping = true, .inverse_on_loop = true },
        EasedValueIntegration{ .start_value = 164.0, .end_value = 264.0, .easing = Easing.Linear, .property_ref = ETransform.Property.XPos },
    )
    .withAnimationAnd(
        .{ .duration = 2000, .looping = true, .inverse_on_loop = true },
        EasedValueIntegration{ .start_value = 0.0, .end_value = 180.0, .easing = Easing.Linear, .property_ref = ETransform.Property.Rotation },
    )
    .activate();
```

