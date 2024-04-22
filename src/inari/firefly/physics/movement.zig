const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const api = firefly.api;

const Timer = api.Timer;
const UpdateScheduler = api.UpdateScheduler;
const System = api.System;
const EComponent = api.EComponent;
const EventDispatch = utils.EventDispatch;
const ETransform = firefly.graphics.ETransform;
const EntityCondition = api.EntityCondition;
const UpdateEvent = firefly.api.UpdateEvent;
const AspectGroup = utils.AspectGroup;
const BitSet = utils.BitSet;
const Index = utils.Index;
const Float = utils.Float;
const Vector2f = utils.Vector2f;
const UNDEF_INDEX = utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// movement init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    EComponent.registerEntityComponent(EMovement);
    System(MovementSystem).createSystem(
        firefly.Engine.CoreSystems.MovementSystem,
        "Processes the movement for all Entities with EMovement component",
        true,
    );

    BasicMovement.ON_SLOPE_UP = MovementAspectGroup.getAspect("ON_SLOPE_UP");
    BasicMovement.ON_SLOPE_DOWN = MovementAspectGroup.getAspect("ON_SLOPE_DOWN");
    BasicMovement.GROUND_TOUCHED = MovementAspectGroup.getAspect("GROUND_TOUCHED");
    BasicMovement.GROUND_LOOSE = MovementAspectGroup.getAspect("GROUND_LOOSE");
    BasicMovement.SLIP_RIGHT = MovementAspectGroup.getAspect("SLIP_RIGHT");
    BasicMovement.SLIP_LEFT = MovementAspectGroup.getAspect("SLIP_RIGHT");
    BasicMovement.JUMP = MovementAspectGroup.getAspect("JUMP");
    BasicMovement.DOUBLE_JUMP = MovementAspectGroup.getAspect("DOUBLE_JUMP");
    BasicMovement.CLIMB_UP = MovementAspectGroup.getAspect("CLIMB_UP");
    BasicMovement.CLIMB_DOWN = MovementAspectGroup.getAspect("CLIMB_DOWN");
    BasicMovement.BLOCK_WEST = MovementAspectGroup.getAspect("BLOCK_WEST");
    BasicMovement.BLOCK_EAST = MovementAspectGroup.getAspect("BLOCK_EAST");
    BasicMovement.BLOCK_NORTH = MovementAspectGroup.getAspect("BLOCK_NORTH");
    BasicMovement.BLOCK_SOUTH = MovementAspectGroup.getAspect("BLOCK_SOUTH");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    System(MovementSystem).disposeSystem();
}

pub const MovementEvent = struct {
    moved: *BitSet = undefined,
};
pub const MovementListener = *const fn (MovementEvent) void;

pub const MovementAspectGroup = AspectGroup(struct {
    pub const name = "Movement";
});
pub const MovementAspect = *const MovementAspectGroup.Aspect;
pub const MovementKind = MovementAspectGroup.Kind;
pub const BasicMovement = struct {
    var ON_SLOPE_UP: MovementAspect = undefined;
    var ON_SLOPE_DOWN: MovementAspect = undefined;
    var GROUND_TOUCHED: MovementAspect = undefined;
    var GROUND_LOOSE: MovementAspect = undefined;
    var SLIP_RIGHT: MovementAspect = undefined;
    var SLIP_LEFT: MovementAspect = undefined;
    var JUMP: MovementAspect = undefined;
    var DOUBLE_JUMP: MovementAspect = undefined;
    var CLIMB_UP: MovementAspect = undefined;
    var CLIMB_DOWN: MovementAspect = undefined;
    var BLOCK_WEST: MovementAspect = undefined;
    var BLOCK_EAST: MovementAspect = undefined;
    var BLOCK_NORTH: MovementAspect = undefined;
    var BLOCK_SOUTH: MovementAspect = undefined;
};

pub const MoveIntegrator = *const fn (movement: *EMovement, delta_time_seconds: Float) bool;

//////////////////////////////////////////////////////////////
//// EMovement Entity Component
//////////////////////////////////////////////////////////////

pub const EMovement = struct {
    pub usingnamespace EComponent.Trait(@This(), "EMovement");

    id: Index = UNDEF_INDEX,
    kind: MovementKind = undefined,
    integrator: MoveIntegrator = SimpleStepIntegrator,
    update_scheduler: ?UpdateScheduler = null,

    active: bool = true,
    mass: Float = 0,
    mass_factor: Float = 1,
    force: Vector2f = Vector2f{ 0, 0 },
    acceleration: Vector2f = Vector2f{ 0, 0 },
    velocity: Vector2f = Vector2f{ 0, 0 },
    gravity: Vector2f = Vector2f{ 0, firefly.physics.Gravity },

    on_ground: bool = false,

    max_velocity_north: ?Float = null,
    max_velocity_east: ?Float = null,
    max_velocity_south: ?Float = null,
    max_velocity_west: ?Float = null,

    adjust_max: bool = true,
    adjust_ground: bool = true,
    adjust_block: bool = false,

    pub fn activation(self: *EMovement, active: bool) void {
        self.active = active;
    }

    pub fn destruct(self: *EMovement) void {
        self.id = UNDEF_INDEX;
        self.kind = undefined;
        self.integrator = SimpleStepIntegrator;

        self.active = true;
        self.mass = 0;
        self.mass_factor = 1;
        self.force = Vector2f{ 0, 0 };
        self.acceleration = Vector2f{ 0, 0 };
        self.velocity = Vector2f{ 0, 0 };
        self.gravity = Vector2f{ 0, firefly.physics.Gravity };

        self.on_ground = false;

        self.max_velocity_north = null;
        self.max_velocity_east = null;
        self.max_velocity_south = null;
        self.max_velocity_west = null;

        self.adjust_max = true;
        self.adjust_ground = true;
        self.adjust_block = false;
    }
};

//////////////////////////////////////////////////////////////
//// Move Integrations
//////////////////////////////////////////////////////////////

pub fn SimpleStepIntegrator(movement: *EMovement, delta_time_seconds: Float) bool {
    var accMass: Float = 1 / movement.mass * movement.mass_factor;

    movement.velocity[0] += delta_time_seconds * movement.gravity[0] / accMass;
    movement.velocity[1] += delta_time_seconds * movement.gravity[1] / accMass;
    adjustVelocity(movement);

    if (movement.velocity[0] != 0 or movement.velocity[1] != 0) {
        if (ETransform.byId(movement.id)) |transform| {
            transform.move(
                movement.velocity[0] * delta_time_seconds,
                movement.velocity[1] * delta_time_seconds,
            );
        }
        return true;
    }
    return false;
}

pub fn VerletIntegrator(movement: *EMovement, delta_time_seconds: Float) bool {
    var accMass: Float = 1 / movement.mass * movement.mass_factor;

    movement.velocity[0] += delta_time_seconds * (movement.acceleration[0] + ((movement.gravity[0] + movement.force[0]) / accMass)) / 2;
    movement.velocity[1] += delta_time_seconds * (movement.acceleration[1] + ((movement.gravity[1] + movement.force[1]) / accMass)) / 2;
    adjustVelocity(movement);

    if (movement.velocity[0] != 0 or movement.velocity[1] != 0) {
        if (ETransform.byId(movement.id)) |transform| {
            transform.move(
                delta_time_seconds * (movement.velocity[0] + delta_time_seconds * movement.acceleration[0] / 2),
                delta_time_seconds * (movement.velocity[1] + delta_time_seconds * movement.acceleration[1] / 2),
            );
        }
        return true;
    }
    return false;
}

pub fn EulerIntegrator(movement: *EMovement, delta_time_seconds: Float) bool {
    var accMass: Float = 1 / movement.mass * movement.mass_factor;

    movement.acceleration[0] = (movement.gravity[0] + movement.force[0]) / accMass;
    movement.acceleration[1] = (movement.gravity[1] + movement.force[1]) / accMass;
    movement.velocity[0] += delta_time_seconds * movement.acceleration[0];
    movement.velocity[1] += delta_time_seconds * movement.acceleration[1];
    adjustVelocity(movement);

    if (movement.velocity[0] != 0 or movement.velocity[1] != 0) {
        if (ETransform.byId(movement.id)) |transform| {
            transform.move(
                movement.velocity[0] * delta_time_seconds,
                movement.velocity[1] * delta_time_seconds,
            );
        }
        return true;
    }
    return false;
}

pub fn adjustVelocity(movement: *EMovement) void {
    if (movement.adjust_block) {
        if (movement.kind.hasAspect(BasicMovement.BLOCK_NORTH) and movement.velocity[1] < 0)
            movement.velocity[1] = 0;
        if (movement.kind.hasAspect(BasicMovement.BLOCK_EAST) and movement.velocity[0] > 0)
            movement.velocity[0] = 0;
        if (movement.kind.hasAspect(BasicMovement.BLOCK_SOUTH) and movement.velocity[1] > 0)
            movement.velocity[1] = 0;
        if (movement.kind.hasAspect(BasicMovement.BLOCK_WEST) and movement.velocity[0] < 0)
            movement.velocity[0] = 0;
    }

    if (movement.adjust_ground and movement.on_ground)
        movement.velocity[1] = 0;

    if (movement.adjust_max) {
        if (movement.max_velocity_south) |max|
            movement.velocity[1] = @min(movement.velocity[1], max);
        if (movement.max_velocity_east) |max|
            movement.velocity[0] = @min(movement.velocity[0], max);
        if (movement.max_velocity_north) |max|
            movement.velocity[1] = @max(movement.velocity[1], -max);
        if (movement.max_velocity_west) |max|
            movement.velocity[0] = @max(movement.velocity[0], -max);
    }
}

//////////////////////////////////////////////////////////////
//// Move System
//////////////////////////////////////////////////////////////

const MovementSystem = struct {
    pub var entity_condition: EntityCondition = undefined;

    var movements: BitSet = undefined;
    var moved: BitSet = undefined;
    var event_dispatch: EventDispatch(MovementEvent) = undefined;
    var event: MovementEvent = MovementEvent{};

    pub fn systemInit() void {
        movements = BitSet.new(api.ALLOC) catch unreachable;
        moved = BitSet.new(api.ALLOC) catch unreachable;
        event.moved = &moved;
        event_dispatch = EventDispatch(MovementEvent).new(api.ALLOC);
    }

    pub fn systemDeinit() void {
        movements.deinit();
        movements = undefined;
        moved.deinit();
        moved = undefined;
        event.moved = undefined;
        event_dispatch.deinit();
        event_dispatch = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (register)
            movements.set(id)
        else
            movements.unset(id);
    }

    pub fn update(_: UpdateEvent) void {
        var dt: Float = @min(@as(Float, @floatFromInt(Timer.time_elapsed)) / 1000, 0.5);
        moved.clear();
        var next = movements.nextSetBit(0);
        while (next) |i| {
            if (EMovement.byId(i)) |m| {
                if (m.update_scheduler) |scheduler| {
                    if (scheduler.needs_update) {
                        if (m.integrator(m, dt * (60 / @min(60, scheduler.resolution))))
                            moved.set(i);
                    }
                } else {
                    if (m.integrator(m, dt))
                        moved.set(i);
                }
            }
            next = movements.nextSetBit(i + 1);
        }
        if (moved.count() > 0)
            event_dispatch.notify(event);
    }
};
