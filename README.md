# firefly-zig

Firefly is a 2D Game API and engine strongly based on ECS design. Uses Raylib under the hood 

Note: Firefly is unter heavy development and way far from release or completed feature set. 

TODO:
  - Reimplement Asset(Shader) and Asset(SpriteSet)
  - Go on with porting from FlyKo
      - [x] Tiles
      - [x] Text
      - [x] Shapes
      - [x] Move Collision-Detection
      - [x] Collision-Resolving
      - [x] Audio
      - [ ] Behavior
      - [x] State Engine
      - [x] TileMap
      - [x] WorldMap
      - [ ] Global index/id register (per component?) 
      - [ ] Global name register (per component?) 
      - [ ] ...

TODO Refactoring:
    - [ ] All control functions should use global register if possible
    - [ ] Use HashMap(Index, T) for additional data stores instead of DynArray(T) where possible
    - [ ] SimpleRoomTransitionScene rename to SimpleFadeInOutScene and shall be a composite with additional data that one can instantiate

 
 ## Code Example:

![](inari.gif)

``` zig
Texture.new(.{
    .name = "TestTexture",
    .resource = "resources/logo.png",
    .is_mipmap = false,
}).load();

const sprite_id = SpriteTemplate.new(.{
    .texture_name = "TestTexture",
    .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
}).id;

_ = Entity.new(.{ .name = "TestEntity" })
    .withComponent(ETransform{
    .position = .{ 64, 164 },
    .scale = .{ 4, 4 },
    .pivot = .{ 16, 16 },
    .rotation = 180,
})
    .withComponent(ESprite{ .template_id = sprite_id })
    .withComponent(EAnimation{})
    .withAnimation(
    .{ .duration = 1000, .looping = true, .inverse_on_loop = true, .active_on_init = true },
    EasedValueIntegration{
        .start_value = 164.0,
        .end_value = 264.0,
        .easing = Easing.Linear,
        .property_ref = ETransform.Property.XPos,
    },
)
    .withAnimation(
    .{ .duration = 2000, .looping = true, .inverse_on_loop = true, .active_on_init = true },
    EasedValueIntegration{
        .start_value = 0.0,
        .end_value = 180.0,
        .easing = Easing.Linear,
        .property_ref = ETransform.Property.Rotation,
    },
).entity().activate();
```

