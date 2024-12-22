const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;

const SimplePivotCamera = firefly.game.SimplePivotCamera;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const EView = firefly.graphics.EView;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EShape = firefly.graphics.EShape;
const EMultiplier = firefly.api.EMultiplier;
const EControl = firefly.api.EControl;
const ShapeType = firefly.api.ShapeType;
const InputButtonType = firefly.api.InputButtonType;
const InputActionType = firefly.api.InputActionType;
const Allocator = std.mem.Allocator;
const String = utils.String;
const Float = utils.Float;
const UpdateEvent = firefly.api.UpdateEvent;
const KeyboardKey = firefly.api.KeyboardKey;
const GamepadAction = firefly.api.GamepadAction;
const InputDevice = firefly.api.InputDevice;
const View = firefly.graphics.View;
const BlendMode = firefly.api.BlendMode;
const Vector2f = firefly.utils.Vector2f;
const Index = utils.Index;
const WindowFlag = firefly.api.WindowFlag;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 480, 60, "Hello Camera", init);
}

fn init() void {
    _ = Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = SpriteTemplate.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    const view = View.Component.newAndGet(.{
        .name = "TestView",
        .position = .{ 20, 40 },
        .pivot = .{ 0, 0 },
        .scale = .{ 1, 1 },
        .rotation = 0,
        .tint_color = .{ 255, 255, 255, 150 },
        .blend_mode = BlendMode.ALPHA,
        .projection = .{
            .clear_color = .{ 30, 30, 30, 255 },
            .position = .{ 0, 0 },
            .width = 600,
            .height = 400,
            .pivot = .{ 0, 0 },
            .zoom = 1,
            .rotation = 0,
        },
    });

    const entity_id = Entity.newActive(.{ .name = "TestEntity" }, .{
        EControl{ .name = "PlayerControl", .update = entity_control },
        EView{ .view_id = view.id },
        ETransform{ .position = .{ 100, 100 } },
        ESprite{ .sprite_id = sprite_id },
    });

    View.Control.addActiveOf(
        view.id,
        SimplePivotCamera{
            .name = "Camera1",
            .pixel_perfect = false,
            .snap_to_bounds = .{ -100, -100, 800, 800 },
            .pivot = &ETransform.Component.byId(entity_id).position,
            .offset = .{ 16, 16 },
            .velocity_relative_to_pivot = .{ 0.1, 0.1 },
        },
    );

    firefly.api.input.setKeyMapping(KeyboardKey.KEY_UP, InputButtonType.UP);
    firefly.api.input.setKeyMapping(KeyboardKey.KEY_DOWN, InputButtonType.DOWN);
    firefly.api.input.setKeyMapping(KeyboardKey.KEY_LEFT, InputButtonType.LEFT);
    firefly.api.input.setKeyMapping(KeyboardKey.KEY_RIGHT, InputButtonType.RIGHT);

    View.Activation.activate(view.id);

    const eid = Entity.Component.new(.{ .name = "RefEntity" });
    EView.Component.new(eid, .{ .view_id = view.id });
    ETransform.Component.new(eid, .{ .position = .{ 100, 100 } });
    ESprite.Component.new(eid, .{ .sprite_id = sprite_id });
    EMultiplier.Component.new(eid, .{ .positions = firefly.api.allocVec2FArray([_]Vector2f{
        .{ 50, 50 },
        .{ 200, 50 },
        .{ 50, 150 },
        .{ 200, 150 },
        .{ 300, 250 },
        .{ 400, 350 },
        .{ 500, 450 },
        .{ 200, 450 },
        .{ 300, 350 },
        .{ 400, 250 },
        .{ 500, 150 },
    }) });
    Entity.Activation.activate(eid);

    _ = Entity.newActive(.{ .name = "Border" }, .{
        EView{ .view_id = view.id },
        ETransform{ .position = .{ 0, 0 } },
        EShape{ .shape_type = ShapeType.RECTANGLE, .vertices = firefly.api.allocFloatArray([_]Float{ -100, -100, 800, 800 }), .fill = false, .thickness = 2, .color = .{ 150, 0, 0, 255 } },
    });
}

const speed = 2;
fn entity_control(ctx: *firefly.api.CallContext) void {
    if (firefly.api.input.checkButtonPressed(InputButtonType.UP))
        ETransform.Component.byId(ctx.caller_id).position[1] -= speed;
    if (firefly.api.input.checkButtonPressed(InputButtonType.DOWN))
        ETransform.Component.byId(ctx.caller_id).position[1] += speed;
    if (firefly.api.input.checkButtonPressed(InputButtonType.LEFT))
        ETransform.Component.byId(ctx.caller_id).position[0] -= speed;
    if (firefly.api.input.checkButtonPressed(InputButtonType.RIGHT))
        ETransform.Component.byId(ctx.caller_id).position[0] += speed;
}
