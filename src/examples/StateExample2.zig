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
    firefly.Engine.CoreSystems.EntityStateSystem.activate();
    firefly.Engine.start(600, 400, 60, "State Example", init);
}

var min_x: Float = 0;
var min_y: Float = 0;
var max_x: Float = 550;
var max_y: Float = 350;
var rndx = std.rand.DefaultPrng.init(32);
const random = rndx.random();

fn init() void {
    //firefly.api.window.toggleFullscreen();

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
    _ = api.Condition.new(.{ .name = "right down", .f = rightDown });
    _ = api.Condition.new(.{ .name = "right up", .f = rightUp });
    _ = api.Condition.new(.{ .name = "left down", .f = leftDown });
    _ = api.Condition.new(.{ .name = "left up", .f = leftUp });

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

    //std.debug.print("start: {?any}\n", .{EState.byId(entity_id)});
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
fn rightDown(_: Index, entity_id: Index, current_sid: Index) bool {
    const trans = ETransform.byId(entity_id) orelse return false;
    if ((trans.position[0] < min_x and current_sid == 3) or (trans.position[1] < min_y and current_sid == 2)) {
        if (current_sid == 3) changeX(entity_id) else changeY(entity_id);
        return true;
    }
    return false;
}

// 2
fn rightUp(_: Index, e_id: Index, c_id: Index) bool {
    const trans = ETransform.byId(e_id) orelse return false;
    if ((trans.position[0] < min_x and c_id == 4) or (trans.position[1] > max_y and c_id == 1)) {
        if (c_id == 4) changeX(e_id) else changeY(e_id);
        return true;
    }
    return false;
}

// 3
fn leftDown(_: Index, e_id: Index, c_id: Index) bool {
    const trans = ETransform.byId(e_id) orelse return false;
    //std.debug.print("c_id: {any}\n", .{(trans.position[0] > max_x and c_id == 1)});
    if ((trans.position[0] > max_x and c_id == 1) or (trans.position[1] < min_y and c_id == 4)) {
        if (c_id == 1) changeX(e_id) else changeY(e_id);
        return true;
    }
    return false;
}

// 4
fn leftUp(_: Index, e_id: Index, c_id: Index) bool {
    const trans = ETransform.byId(e_id) orelse return false;
    if ((trans.position[0] > max_x and c_id == 2) or (trans.position[1] > max_y and c_id == 3)) {
        if (c_id == 2) changeX(e_id) else changeY(e_id);
        return true;
    }
    return false;
}
