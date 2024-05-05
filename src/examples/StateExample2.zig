const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EMovement = firefly.physics.EMovement;
const EState = firefly.control.EState;
const Allocator = std.mem.Allocator;
const Vector2f = utils.Vector2f;
const State = firefly.control.State;
const EntityStateEngine = firefly.control.EntityStateEngine;
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
    Texture.newAnd(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    }).load();

    const sprite_id = SpriteTemplate.new(.{
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    const state_engine = EntityStateEngine.newAnd(.{ .name = "MoveX" })
        .withState(.{ .id = 1, .name = "right down", .condition = rightDown })
        .withState(.{ .id = 2, .name = "right up", .condition = rightUp })
        .withState(.{ .id = 3, .name = "left down", .condition = leftDown })
        .withState(.{ .id = 4, .name = "left up", .condition = leftUp })
        .activate();

    for (0..10000) |_| {
        createEntity(state_engine, sprite_id);
    }
}

fn createEntity(state_engine: *EntityStateEngine, sprite_id: Index) void {
    const vx = random.float(Float) * 200 + 1;
    const vy = random.float(Float) * 200 + 1;
    const entity_id = Entity.newAnd(.{})
        .with(ETransform{ .position = .{ 0, 0 } })
        .with(ESprite{ .template_id = sprite_id })
        .with(EMovement{ .velocity = .{ vx, vy } })
        .with(EState{ .state_engine = state_engine })
        .activate().id;

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
fn rightDown(entity_id: Index, current: ?*State) bool {
    const c_id = current.?.id;
    const trans = ETransform.byId(entity_id).?;
    if ((trans.position[0] < min_x and c_id == 3) or (trans.position[1] < min_y and c_id == 2)) {
        if (c_id == 3) changeX(entity_id) else changeY(entity_id);
        return true;
    }
    return false;
}

// 2
fn rightUp(entity_id: Index, current: ?*State) bool {
    const c_id = current.?.id;
    const trans = ETransform.byId(entity_id).?;
    if ((trans.position[0] < min_x and c_id == 4) or (trans.position[1] > max_y and c_id == 1)) {
        if (c_id == 4) changeX(entity_id) else changeY(entity_id);
        return true;
    }
    return false;
}

// 3
fn leftDown(entity_id: Index, current: ?*State) bool {
    const trans = ETransform.byId(entity_id).?;
    const c_id = current.?.id;
    //std.debug.print("c_id: {any}\n", .{(trans.position[0] > max_x and c_id == 1)});
    if ((trans.position[0] > max_x and c_id == 1) or (trans.position[1] < min_y and c_id == 4)) {
        if (c_id == 1) changeX(entity_id) else changeY(entity_id);
        return true;
    }
    return false;
}

// 4
fn leftUp(entity_id: Index, current: ?*State) bool {
    const c_id = current.?.id;
    const trans = ETransform.byId(entity_id).?;
    if ((trans.position[0] > max_x and c_id == 2) or (trans.position[1] > max_y and c_id == 3)) {
        if (c_id == 2) changeX(entity_id) else changeY(entity_id);
        return true;
    }
    return false;
}
