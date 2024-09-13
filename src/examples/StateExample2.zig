const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EMovement = firefly.physics.EMovement;
const EState = firefly.api.EState;
const Allocator = std.mem.Allocator;
const Vector2f = utils.Vector2f;
const State = firefly.api.State;
const EntityStateEngine = firefly.api.EntityStateEngine;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const Float = utils.Float;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    // Since the StateEngineSystem is not activated by default, we need to active it first
    firefly.Engine.start(600, 400, 60, "State Example", init);
}

var min_x: Float = 0;
var min_y: Float = 0;
var max_x: Float = 550;
var max_y: Float = 350;
var rndx = std.rand.DefaultPrng.init(32);
const random = rndx.random();

fn init() void {
    firefly.api.System.activateByName("ContactSystem", false);

    Texture.new(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    const sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    }).id;

    // This is just to test registering conditions works as expected (can also be assigned directly below)
    _ = api.Condition.new(.{ .name = "right down", .check = rightDown });
    _ = api.Condition.new(.{ .name = "right up", .check = rightUp });
    _ = api.Condition.new(.{ .name = "left down", .check = leftDown });
    _ = api.Condition.new(.{ .name = "left up", .check = leftUp });

    const state_engine = EntityStateEngine.new(.{ .name = "MoveX" })
        .withState(.{ .id = 1, .name = "right down", .condition = api.Condition.functionByName("right down") })
        .withState(.{ .id = 2, .name = "right up", .condition = api.Condition.functionByName("right up") })
        .withState(.{ .id = 3, .name = "left down", .condition = api.Condition.functionByName("left down") })
        .withState(.{ .id = 4, .name = "left up", .condition = api.Condition.functionByName("left up") })
        .activate();

    for (0..10000) |_| {
        createEntity(state_engine, sprite_id);
    }
}

fn createEntity(state_engine: *EntityStateEngine, sprite_id: Index) void {
    const vx = random.float(Float) * 200 + 1;
    const vy = random.float(Float) * 200 + 1;
    const entity_id = Entity.new(.{})
        .withComponent(ETransform{ .position = .{ 0, 0 } })
        .withComponent(ESprite{ .template_id = sprite_id })
        .withComponent(EMovement{
        .velocity = .{ vx, vy },
        .mass = 0,
        .adjust_max = false,
        .adjust_ground = false,
    })
        .withComponent(EState{ .state_engine_ref = state_engine.id })
        .activate().id;

    // just the initial state
    EState.byId(entity_id).?.current_state =
        if (vx > 0 and vy > 0) state_engine.states.get(0).? else if (vx > 0 and vy < 0) state_engine.states.get(1).? else if (vx < 0 and vy > 0) state_engine.states.get(2).? else state_engine.states.get(3).?;
}

inline fn changeX(entity_id: Index) void {
    var m = EMovement.byId(entity_id).?;
    m.velocity[0] *= -1;
}

inline fn changeY(entity_id: Index) void {
    var m = EMovement.byId(entity_id).?;
    m.velocity[1] *= -1;
}

// 1
fn rightDown(ctx: *api.CallContext) bool {
    const trans = ETransform.byId(ctx.id_1) orelse return false;
    if ((trans.position[0] < min_x and ctx.id_2 == 3) or (trans.position[1] < min_y and ctx.id_2 == 2)) {
        if (ctx.id_2 == 3) changeX(ctx.id_1) else changeY(ctx.id_1);
        return true;
    }
    return false;
}

// 2
fn rightUp(ctx: *api.CallContext) bool {
    const trans = ETransform.byId(ctx.id_1) orelse return false;
    if ((trans.position[0] < min_x and ctx.id_2 == 4) or (trans.position[1] > max_y and ctx.id_2 == 1)) {
        if (ctx.id_2 == 4) changeX(ctx.id_1) else changeY(ctx.id_1);
        return true;
    }
    return false;
}

// 3
fn leftDown(ctx: *api.CallContext) bool {
    const trans = ETransform.byId(ctx.id_1) orelse return false;
    if ((trans.position[0] > max_x and ctx.id_2 == 1) or (trans.position[1] < min_y and ctx.id_2 == 4)) {
        if (ctx.id_2 == 1) changeX(ctx.id_1) else changeY(ctx.id_1);
        return true;
    }
    return false;
}

// 4
fn leftUp(ctx: *api.CallContext) bool {
    const trans = ETransform.byId(ctx.id_1) orelse return false;
    if ((trans.position[0] > max_x and ctx.id_2 == 2) or (trans.position[1] > max_y and ctx.id_2 == 3)) {
        if (ctx.id_2 == 2) changeX(ctx.id_1) else changeY(ctx.id_1);
        return true;
    }
    return false;
}
