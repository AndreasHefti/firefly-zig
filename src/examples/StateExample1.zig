const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const Sprite = firefly.graphics.Sprite;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EMovement = firefly.physics.EMovement;
const Allocator = std.mem.Allocator;
const Vector2f = utils.Vector2f;
const State = firefly.control.State;
const StateEngine = firefly.control.StateEngine;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "State Example", init);
}

var entity_id: Index = UNDEF_INDEX;

fn init() void {
    // Since the StateEngineSystem is not activated by default, we need to active it first
    firefly.api.activateSystem("StateEngineSystem", true);

    Texture.new(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    const sprite_id = Sprite.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    entity_id = Entity.new(.{ .name = "TestEntity" })
        .withComponent(ETransform{ .position = .{ 100, 100 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{ .velocity = .{ 2, 0 } })
        .activate()
        .id;

    _ = StateEngine.new(.{ .name = "TestStateEngine", .update_scheduler = firefly.api.Timer.getScheduler(20) })
        .withState(.{ .name = "go right", .condition = goRightCondition, .init = goRightInit })
        .withState(.{ .name = "go left", .condition = goLeftCondition, .init = goLeftInit })
        .activate();
}

fn goRightCondition(_: Index, current: ?*State) bool {
    if (current == null)
        return true; // init state
    if (ETransform.byId(entity_id)) |trans|
        return trans.position[0] < 100;
    return false;
}

fn goLeftCondition(_: Index, _: ?*State) bool {
    if (ETransform.byId(entity_id)) |trans|
        return trans.position[0] > 300;
    return false;
}

fn goRightInit(_: Index) void {
    if (EMovement.byId(entity_id)) |em|
        em.velocity[0] = 200;
}

fn goLeftInit(_: Index) void {
    if (EMovement.byId(entity_id)) |em|
        em.velocity[0] = -200;
}
