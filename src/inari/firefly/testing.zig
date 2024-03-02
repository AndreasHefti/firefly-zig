const std = @import("std");
const inari = @import("../inari.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const api = firefly.api;

const Component = api.Component;
const ComponentListener = Component.ComponentListener;
const ComponentEvent = Component.ComponentEvent;
const ComponentPool = api.Component.ComponentPool;
const Aspect = utils.Aspect;
const String = utils.String;
const FFAPIError = FFAPIError;
const Color = utils.Color;
const PosF = utils.PosF;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;
const Entity = api.Entity;
const Engine = firefly.Engine;
const ETransform = firefly.graphics.ETransform;
const TransformData = firefly.api.TransformData;
const ESprite = firefly.graphics.ESprite;
const Asset = firefly.api.Asset;
const TextureAsset = firefly.graphics.TextureAsset;
const SpriteAsset = firefly.graphics.SpriteAsset;

test {
    std.testing.refAllDecls(@import("api/testing.zig"));
    std.testing.refAllDecls(@import("graphics/testing.zig"));
    std.testing.refAllDecls(@import("physics/testing.zig"));
}

// //////////////////////////////////////////////////////////////
// //// TESTING Firefly
// //////////////////////////////////////////////////////////////

test "Firefly init" {
    try firefly.initTesting();
    defer firefly.deinit();
    var sb = utils.StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    utils.debug.printAspects(&sb);
    api.Component.print(&sb);

    var output: utils.String =
        \\Aspects:
        \\  Group[COMPONENT_ASPECT_GROUP|0]:
        \\    Aspect[Asset|0]
        \\    Aspect[Entity|1]
        \\    Aspect[System|2]
        \\    Aspect[Layer|3]
        \\    Aspect[View|4]
        \\  Group[ASSET_TYPE_ASPECT_GROUP|1]:
        \\    Aspect[Texture|0]
        \\    Aspect[Shader|1]
        \\    Aspect[Sprite|2]
        \\    Aspect[SpriteSet|3]
        \\  Group[ENTITY_KIND_ASP_GROUP|2]:
        \\    Aspect[ETransform|0]
        \\    Aspect[EMultiplier|1]
        \\    Aspect[ESprite|2]
        \\
        \\Components:
        \\  Asset size: 0
        \\  Entity size: 0
        \\  System size: 3
        \\    (a) ViewRenderer[ id:0, info:Emits ViewRenderEvent in order of active Views and its Layers ]
        \\    (a) SimpleSpriteRenderer[ id:1, info:Render Entities with ETransform and ESprite components ]
        \\    (a) AnimationSystem [ id:2, info:Updates all active animations ]
        \\  Layer size: 0
        \\  View size: 0
    ;

    try std.testing.expectEqualStrings(output, sb.toString());
}

// //////////////////////////////////////////////////////////////
// //// TESTING ExampleComponent
// //////////////////////////////////////////////////////////////

const ExampleComponent = struct {
    pub usingnamespace Component.API.Adapter(@This(), .{ .name = "ExampleComponent" });

    // struct fields
    id: Index = UNDEF_INDEX,
    name: String = NO_NAME,
    color: Color = Color{ 0, 0, 0, 255 },
    position: PosF = PosF{ 0, 0 },

    // methods
    pub fn activate(self: ExampleComponent, active: bool) void {
        @This().pool.activate(self.id, active);
    }

    // following methods will automatically be called by Component interface when defined
    pub fn init() !void {
        // testing
    }

    pub fn deinit() void {}

    pub fn construct(self: *ExampleComponent) void {
        std.testing.expect(self.id != UNDEF_INDEX) catch unreachable;
    }

    pub fn activation(self: *ExampleComponent, active: bool) void {
        _ = active;
        std.testing.expect(self.id != UNDEF_INDEX) catch unreachable;
    }

    pub fn destruct(self: *ExampleComponent) void {
        std.testing.expect(self.id != UNDEF_INDEX) catch unreachable;
    }
};

test "initialization" {
    try firefly.initTesting();
    defer firefly.deinit();
    Component.API.registerComponent(ExampleComponent);

    var newC = ExampleComponent.new(ExampleComponent{
        .color = Color{ 1, 2, 3, 255 },
        .position = PosF{ 10, 20 },
    });
    var newCPtr = ExampleComponent.byId(newC.id);

    try std.testing.expectEqual(newC.*, newCPtr.*);
    try std.testing.expectEqual(@as(String, "ExampleComponent"), ExampleComponent.pool.c_aspect.name);
}

test "valid component" {
    try firefly.initTesting();
    defer firefly.deinit();
    Component.API.registerComponent(ExampleComponent);

    var newC = ExampleComponent.new(ExampleComponent{
        .color = Color{ 1, 2, 3, 255 },
        .position = PosF{ 10, 20 },
    });
    var newCPtr = ExampleComponent.byId(newC.id);

    var invalid1 = ExampleComponent{
        //.id = 0,
        .color = Color{ 1, 2, 3, 255 },
        .position = PosF{ 10, 20 },
    };

    try std.testing.expect(Component.API.checkComponentValidity(newC));
    try std.testing.expect(Component.API.checkComponentValidity(newCPtr));
    try std.testing.expect(!Component.API.checkComponentValidity(invalid1));
    //try std.testing.expect(!Component.isValid(firefly.graphics.ETransform{}));
}

test "create/dispose component" {
    try firefly.initTesting();
    defer firefly.deinit();
    Component.API.registerComponent(ExampleComponent);

    var cPtr = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });

    try std.testing.expect(cPtr.id == 0);

    try std.testing.expect(ExampleComponent.pool.count() == 1);
    try std.testing.expect(ExampleComponent.pool.activeCount() == 0);

    try std.testing.expect(cPtr.color[0] == 0);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 10);
    try std.testing.expect(cPtr.position[1] == 10);

    cPtr.position[0] = 111;

    try std.testing.expect(cPtr.color[0] == 0);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 111);
    try std.testing.expect(cPtr.position[1] == 10);

    cPtr.activate(true);

    try std.testing.expect(ExampleComponent.pool.count() == 1);
    try std.testing.expect(ExampleComponent.pool.activeCount() == 1);

    var editableCPtr = ExampleComponent.get(cPtr.id);

    try std.testing.expect(editableCPtr.id == 0);
    try std.testing.expect(editableCPtr.color[0] == 0);
    try std.testing.expect(editableCPtr.color[1] == 0);
    try std.testing.expect(editableCPtr.color[2] == 0);
    try std.testing.expect(editableCPtr.color[3] == 255);
    try std.testing.expect(editableCPtr.position[0] == 111);
    try std.testing.expect(editableCPtr.position[1] == 10);

    editableCPtr.color[0] = 255;

    try std.testing.expect(cPtr.color[0] == 255);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 111);
    try std.testing.expect(cPtr.position[1] == 10);

    ExampleComponent.disposeById(editableCPtr.id);

    try std.testing.expect(cPtr.color[0] == 0);
    try std.testing.expect(cPtr.color[1] == 0);
    try std.testing.expect(cPtr.color[2] == 0);
    try std.testing.expect(cPtr.color[3] == 255);
    try std.testing.expect(cPtr.position[0] == 0);
    try std.testing.expect(cPtr.position[1] == 0);

    try std.testing.expect(ExampleComponent.pool.count() == 0);
    try std.testing.expect(ExampleComponent.pool.activeCount() == 0);
}

test "name mapping" {
    try firefly.initTesting();
    defer firefly.deinit();
    Component.API.registerComponent(ExampleComponent);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    _ = c1;

    var c2 = ExampleComponent.new(.{
        .name = "c2",
        .color = Color{ 2, 0, 0, 255 },
        .position = PosF{ 20, 20 },
    });

    try std.testing.expect(ExampleComponent.existsName("c2"));
    try std.testing.expect(!ExampleComponent.existsName("c1"));

    var _c2 = ExampleComponent.byName("c2");
    var c3 = ExampleComponent.byName("c3"); // c3 doesn't exists so it gives back the NULL VALUE

    try std.testing.expect(_c2.id != ExampleComponent.NULL_VALUE.id);
    try std.testing.expectEqual(c2.*, _c2.*);
    try std.testing.expect(c3.id == ExampleComponent.NULL_VALUE.id);
    try std.testing.expectEqual(c3.*, ExampleComponent.NULL_VALUE);
}

test "event propagation" {
    try firefly.initTesting();
    defer firefly.deinit();
    Component.API.registerComponent(ExampleComponent);

    // also triggers auto init
    ExampleComponent.subscribe(testListener);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    c1.activate(true);
    c1.activate(false);
}

fn testListener(event: Component.ComponentEvent) void {
    std.debug.print("received: {any}\n", .{event});
}

test "get poll and process" {
    try firefly.initTesting();
    defer firefly.deinit();
    Component.API.registerComponent(ExampleComponent);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    c1.activate(true);

    var c2 = ExampleComponent.new(.{
        .color = Color{ 2, 0, 0, 255 },
        .position = PosF{ 20, 20 },
    });
    _ = c2;

    var c3 = ExampleComponent.new(.{
        .color = Color{ 0, 5, 0, 255 },
        .position = PosF{ 40, 70 },
    });
    _ = c3;

    process();
}

test "function pointer equality op" {
    const p1: *const fn () void = process;
    const p2: *const fn () void = process;

    try std.testing.expect(p1 == p2);
}

// fn processViaIdCast(id: component.ComponentId) void {
//     if (ComponentPool(ExampleComponent).typeCheck(id.aspect)) {
//         var arr = [1]usize{id.cIndex};
//         id.cTypePtr.cast(ComponentPool(ExampleComponent)).processIndexed(&arr, processOne);
//     }
// }

fn process() void {
    ExampleComponent.pool.processActive(processOne);
}

fn processOne(c: *const ExampleComponent) void {
    std.debug.print("process {any}\n", .{c});
}

fn processOneUnknown(c: anytype) void {
    std.debug.print("process {any}\n", .{c});
}

test "testStructFnc" {
    const f1 = testStructFnc(1);
    const f2 = testStructFnc(2);
    try std.testing.expect(f1.i == 1);
    try std.testing.expect(f2.i == 2);
}

fn testStructFnc(comptime index: usize) type {
    return struct {
        pub var i = index;
    };
}

//////////////////////////////////////////////////////////////
//// TESTING Render one Entity no View and Layer
//////////////////////////////////////////////////////////////

test "Init Rendering one sprite entity with no view and layer" {
    try firefly.initTesting();
    defer firefly.deinit();
    var sb = utils.StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    var texture_asset: *Asset = TextureAsset.new(.{
        .name = "TestTexture",
        .resource_path = "path/TestTexture",
        .is_mipmap = false,
    });

    var sprite_asset: *Asset = SpriteAsset.new(.{
        .name = "TestSprite",
        .texture_asset_id = texture_asset.id,
        .texture_bounds = utils.RectF{ 0, 0, 20, 20 },
        .flip_x = true,
    });

    _ = Entity.new(.{ .name = "TestEntity" })
        .withComponent(ETransform{ .transform = .{ .position = .{ 50, 50 } } })
        .withComponent(ESprite.fromAsset(sprite_asset))
        .activate();

    var output: utils.String =
        \\
        \\Components:
        \\  Asset size: 2
        \\    (a) Asset[0|Aspect[ASSET_TYPE_ASPECT_GROUP|Texture|0]|TestTexture| resource_id=0, parent_asset_id=18446744073709551615 ]
        \\    (a) Asset[1|Aspect[ASSET_TYPE_ASPECT_GROUP|Sprite|2]|TestSprite| resource_id=0, parent_asset_id=0 ]
        \\  Entity size: 1
        \\    (a) Entity[0|TestEntity|Kind[ group: ENTITY_KIND_ASP_GROUP, aspects: ETransform ESprite ]]
        \\  System size: 3
        \\    (a) ViewRenderer[ id:0, info:Emits ViewRenderEvent in order of active Views and its Layers ]
        \\    (a) SimpleSpriteRenderer[ id:1, info:Render Entities with ETransform and ESprite components ]
        \\    (a) AnimationSystem [ id:2, info:Updates all active animations ]
        \\  Layer size: 0
        \\  View size: 0
    ;

    api.Component.print(&sb);
    try std.testing.expectEqualStrings(output, sb.toString());

    // no rendering yet but texture data loaded
    sb.clear();
    var api_out: String =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\   TextureData[ res:path/TestTexture, bind:0, w:1, h:1, mipmap:false, wrap:-1|-1, minmag:-1|-1]
        \\ loaded render textures:
        \\ loaded shaders:
        \\ current state:
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\
    ;
    api.rendering.printDebug(&sb);
    try std.testing.expectEqualStrings(api_out, sb.toString());

    // simulate one tick
    Engine.tick();
    // and watch rendering, should have one render action for the sprite entity now
    sb.clear();
    api_out =
        \\
        \\******************************
        \\Debug Rendering API State:
        \\ loaded textures:
        \\   TextureData[ res:path/TestTexture, bind:0, w:1, h:1, mipmap:false, wrap:-1|-1, minmag:-1|-1]
        \\ loaded render textures:
        \\ loaded shaders:
        \\ current state:
        \\   Projection[ clear_color:{ 0, 0, 0, 255 }, offset:{ 0.0e+00, 0.0e+00 }, pivot:{ 0.0e+00, 0.0e+00 }, zoom:1, rot:0 ]
        \\   null
        \\   RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ]
        \\   null
        \\   Offset: { 0.0e+00, 0.0e+00 }
        \\ render actions:
        \\   render SpriteData[ bind:0, bounds:{ 2.0e+01, 0.0e+00, -2.0e+01, 2.0e+01 } ] -->
        \\     TransformData[ pos:{ 5.0e+01, 5.0e+01 }, pivot:{ 0.0e+00, 0.0e+00 }, scale:{ 1.0e+00, 1.0e+00 }, rot:0 ],
        \\     RenderData[ tint:{ 255, 255, 255, 255 }, blend:ALPHA ],
        \\     offset:{ 0.0e+00, 0.0e+00 }
        \\
    ;
    api.rendering.printDebug(&sb);
    try std.testing.expectEqualStrings(api_out, sb.toString());
}
