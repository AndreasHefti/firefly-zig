const std = @import("std");

const firefly = @import("firefly.zig");
const api = @import("api/api.zig"); // TODO module
const utils = api.utils;
const Component = api.Component;
const ComponentPool = api.Component.ComponentPool;
const CompLifecycleEvent = Component.CompLifecycleEvent;
const Aspect = utils.aspect.Aspect;
const String = utils.String;
const FFAPIError = FFAPIError;
const Color = utils.geom.Color;
const PosF = utils.geom.PosF;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;

test {
    std.testing.refAllDecls(@import("api/testing.zig"));
    std.testing.refAllDecls(@import("graphics/testing.zig"));
}

// //////////////////////////////////////////////////////////////
// //// TESTING Firefly
// //////////////////////////////////////////////////////////////

test "Firefly init" {
    try firefly.initTesting();
    defer firefly.deinit();
    var sb = utils.StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    utils.aspect.print(&sb);
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
        \\  Group[ENTITY_COMPONENT_ASPECT_GROUP|2]:
        \\    Aspect[ETransform|0]
        \\    Aspect[EMultiplier|1]
        \\    Aspect[ESprite|2]
        \\
        \\Components:
        \\  Asset size: 0
        \\  Entity size: 0
        \\  System size: 2
        \\    a ViewRenderer[ id:0, info:Emits ViewRenderEvent in order of active Views and its Layers ]
        \\    a SimpleSpriteRenderer[ id:1, info:Render Entities with ETransform and ESprite components ]
        \\  Layer size: 0
        \\  View size: 0
    ;

    try std.testing.expectEqualStrings(output, sb.toString());
}

// //////////////////////////////////////////////////////////////
// //// TESTING ExampleComponent
// //////////////////////////////////////////////////////////////

const ExampleComponent = struct {

    // component type fields needed by the Component interface
    pub const NULL_VALUE = ExampleComponent{};
    pub const COMPONENT_NAME = "ExampleComponent";
    pub const pool = ComponentPool(ExampleComponent);
    pub var type_aspect: *Aspect = undefined;
    pub var new: *const fn (ExampleComponent) *ExampleComponent = undefined;
    pub var exists: *const fn (Index) bool = undefined;
    pub var existsName: *const fn (String) bool = undefined;
    pub var get: *const fn (Index) *ExampleComponent = undefined;
    pub var byId: *const fn (Index) *const ExampleComponent = undefined;
    pub var byName: *const fn (String) *const ExampleComponent = undefined;
    pub var activateById: *const fn (Index, bool) void = undefined;
    pub var activateByName: *const fn (String, bool) void = undefined;
    pub var disposeById: *const fn (Index) void = undefined;
    pub var disposeByName: *const fn (String) void = undefined;
    pub var subscribe: *const fn (Component.EventListener) void = undefined;
    pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

    // struct fields
    id: Index = UNDEF_INDEX,
    name: String = NO_NAME,
    color: Color = Color{ 0, 0, 0, 255 },
    position: PosF = PosF{ 0, 0 },

    // methods
    pub fn activate(self: ExampleComponent, active: bool) void {
        pool.activate(self.id, active);
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
    Component.registerComponent(ExampleComponent);

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
    Component.registerComponent(ExampleComponent);

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

    try std.testing.expect(Component.isValid(newC));
    try std.testing.expect(Component.isValid(newCPtr));
    try std.testing.expect(!Component.isValid(invalid1));
    //try std.testing.expect(!Component.isValid(firefly.graphics.ETransform{}));
}

test "create/dispose component" {
    try firefly.initTesting();
    defer firefly.deinit();
    Component.registerComponent(ExampleComponent);

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
    Component.registerComponent(ExampleComponent);

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
    Component.registerComponent(ExampleComponent);

    // also triggers auto init
    ExampleComponent.subscribe(testListener);

    var c1 = ExampleComponent.new(.{
        .color = Color{ 0, 0, 0, 255 },
        .position = PosF{ 10, 10 },
    });
    c1.activate(true);
    c1.activate(false);
}

fn testListener(event: *const Component.ComponentEvent) void {
    std.debug.print("received: {any}\n", .{event});
}

test "get poll and process" {
    try firefly.initTesting();
    defer firefly.deinit();
    Component.registerComponent(ExampleComponent);

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

    process();

    // var ptr = component.CompPoolPtr{
    //     .aspect = ExampleComponent.pool.c_aspect,
    //     .address = @intFromPtr(ExampleComponent.pool),
    // };
    // _ = ptr;

    var compId = Component.ComponentId{
        .aspect = ExampleComponent.type_aspect,
        .id = c3.id,
    };
    _ = compId;

    //component.processById(ExampleComponent, &compId, processOne);

    //processViaIdCast(compId);
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
