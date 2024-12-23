const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const physics = firefly.physics;
const game = firefly.game;

const Texture = firefly.graphics.Texture;
const Sprite = firefly.graphics.Sprite;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const Float = utils.Float;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Behavior", init);
}

pub fn init() void {
    firefly.game.BehaviorSystem.System.activate();

    _ = Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    const sprite_id = Sprite.Component.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    const behavior_id = game.BehaviorTreeBuilder
        .newTreeWithSequence("Test Behavior")
        .addAction(go_right, "go right")
        .addAction(go_down, "go down")
        .addAction(go_left, "go left")
        .addAction(go_up, "go up")
        .build();

    const entity_id = Entity.newActive(.{}, .{
        ETransform{ .position = .{ 0, 0 } },
        ESprite{ .sprite_id = sprite_id },
        game.EBehavior{ .root_node_id = behavior_id },
    });

    var behavior = game.EBehavior.Component.byId(entity_id);
    behavior.call_context.id_1 = 0;
}

fn go_right(_: *game.BehaviorNode, ctx: *api.CallContext) void {
    if (ctx.id_1 > 0) {
        ctx.result = api.ActionResult.Success;
        return;
    }

    var transform = graphics.ETransform.Component.byId(ctx.caller_id);
    transform.position[0] += 2;
    if (transform.position[0] < 200) {
        ctx.result = api.ActionResult.Running;
    } else {
        ctx.id_1 = 1;
        ctx.result = api.ActionResult.Success;
    }
}

fn go_down(_: *game.BehaviorNode, ctx: *api.CallContext) void {
    if (ctx.id_1 > 1) {
        ctx.result = api.ActionResult.Success;
        return;
    }

    var transform = graphics.ETransform.Component.byId(ctx.caller_id);
    transform.position[1] += 2;
    if (transform.position[1] < 200) {
        ctx.result = api.ActionResult.Running;
    } else {
        ctx.id_1 = 2;
        ctx.result = api.ActionResult.Success;
    }
}

fn go_left(_: *game.BehaviorNode, ctx: *api.CallContext) void {
    if (ctx.id_1 > 2) {
        ctx.result = api.ActionResult.Success;
        return;
    }

    var transform = graphics.ETransform.Component.byId(ctx.caller_id);
    transform.position[0] -= 2;
    if (transform.position[0] > 0) {
        ctx.result = api.ActionResult.Running;
    } else {
        ctx.id_1 = 3;
        ctx.result = api.ActionResult.Success;
    }
}

fn go_up(_: *game.BehaviorNode, ctx: *api.CallContext) void {
    var transform = graphics.ETransform.Component.byId(ctx.caller_id);
    transform.position[1] -= 2;
    if (transform.position[1] > 0) {
        ctx.result = api.ActionResult.Running;
    } else {
        ctx.id_1 = 0;
        ctx.result = api.ActionResult.Success;
    }
}
