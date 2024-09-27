# firefly-zig

Firefly is a 2D Game API and engine strongly based on ECS design. Uses [raylib](https://github.com/raysan5/raylib) under the hood 

Note: Firefly is under heavy development and way far from release or completed feature set. 

Features:

    - [x] utils - geometry utilities
    - [x] utils - DynArray, DynIndexArray and DynIndexMap for index mapping
    - [x] utils - Event and EventDispatcher for define and using events
    - [x] utils - Aspects, Aspect Groups and Kind (TODO Aspects Mixin?)
    - [x] utils - Bitset and Bit-Mask

    - [x] api - NamePool to store arbitrary names on the heap
    - [x] api - Components, Entities/Components, Systems (with Mixins)
    - [x] api - Attributes Component and CallContext (with Mixins)
    - [x] api - Composite Component(with Mixin)
    - [x] api - Assets Component (with Mixin)
    - [x] api - Control Component (with Mixin)
    - [x] api - Trigger Component
    - [x] api - Task Component
    - [x] api - State Engine Component
    - [x] api - State Engine and Entity State Engine Components

    - [x] graphics - Shader
    - [x] graphics - Texture Asset
    - [x] graphics - View and Layer Components
    - [x] graphics - Transform Entity Component
    - [x] graphics - Sprites Entity Component
    - [x] graphics - Tiles and TileMap Component
    - [x] graphics - Text Entity Component
    - [x] graphics - Shapes Entity Component

    - [x] physics - Animation
    - [x] physics - Movement 
    - [x] physics - Collision-Detection
    - [x] physics - Collision-Resolving
    - [ ] physics - Ray-Cast
    - [x] physics - Audio
    
    - [ ] game - Behavior 
    - [x] game - TileSet (created in code or loaded from JSON file)
    - [x] game - TileMap (created in code or loaded from JSON file)
    - [x] game - Camera (simple pivot camera)
    - [x] game - Player 
    - [x] game - Area (created in code or loaded from JSON file)
    - [x] game - Room (created in code or loaded from JSON file)
    - [ ] game - Adaptable main View that fits to different screens without losing resolution


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
).activate();
```

 ## Platformer essentials and Room loading from JSON file now working:

 ![](platformer.gif)

