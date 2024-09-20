const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const physics = firefly.physics;

const Index = firefly.utils.Index;
const Float = firefly.utils.Float;
const Vector2f = firefly.utils.Vector2f;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// movement init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    api.EComponent.registerEntityComponent(EMovement);
    MovementSystem.init();

    MovFlags.ON_SLOPE_UP = physics.MovementAspectGroup.getAspect("ON_SLOPE_UP");
    MovFlags.ON_SLOPE_DOWN = physics.MovementAspectGroup.getAspect("ON_SLOPE_DOWN");
    MovFlags.GROUND_TOUCHED = physics.MovementAspectGroup.getAspect("GROUND_TOUCHED");
    MovFlags.LOST_GROUND = physics.MovementAspectGroup.getAspect("LOST_GROUND");
    MovFlags.SLIP_RIGHT = physics.MovementAspectGroup.getAspect("SLIP_RIGHT");
    MovFlags.SLIP_LEFT = physics.MovementAspectGroup.getAspect("SLIP_RIGHT");
    MovFlags.JUMP = physics.MovementAspectGroup.getAspect("JUMP");
    MovFlags.DOUBLE_JUMP = physics.MovementAspectGroup.getAspect("DOUBLE_JUMP");
    MovFlags.CLIMB_UP = physics.MovementAspectGroup.getAspect("CLIMB_UP");
    MovFlags.CLIMB_DOWN = physics.MovementAspectGroup.getAspect("CLIMB_DOWN");
    MovFlags.BLOCK_WEST = physics.MovementAspectGroup.getAspect("BLOCK_WEST");
    MovFlags.BLOCK_EAST = physics.MovementAspectGroup.getAspect("BLOCK_EAST");
    MovFlags.BLOCK_NORTH = physics.MovementAspectGroup.getAspect("BLOCK_NORTH");
    MovFlags.BLOCK_SOUTH = physics.MovementAspectGroup.getAspect("BLOCK_SOUTH");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// movement API
//////////////////////////////////////////////////////////////

//pub const Direction = enum { NONE, ANY, NORTH, SOUTH, EAST, WEST };

pub const MovementEvent = struct {
    moved: *utils.BitSet = undefined,
};
pub const MovementListener = *const fn (MovementEvent) void;

pub fn subscribe(listener: MovementListener) void {
    if (!initialized)
        return;

    MovementSystem.event_dispatch.register(listener);
}

pub fn unsubscribe(listener: MovementListener) void {
    if (!initialized)
        return;

    MovementSystem.event_dispatch.unregister(listener);
}

pub const MovFlags = struct {
    pub var ON_SLOPE_UP: physics.MovementAspect = undefined;
    pub var ON_SLOPE_DOWN: physics.MovementAspect = undefined;
    pub var GROUND_TOUCHED: physics.MovementAspect = undefined;
    pub var LOST_GROUND: physics.MovementAspect = undefined;
    pub var SLIP_RIGHT: physics.MovementAspect = undefined;
    pub var SLIP_LEFT: physics.MovementAspect = undefined;
    pub var JUMP: physics.MovementAspect = undefined;
    pub var DOUBLE_JUMP: physics.MovementAspect = undefined;
    pub var CLIMB_UP: physics.MovementAspect = undefined;
    pub var CLIMB_DOWN: physics.MovementAspect = undefined;
    pub var BLOCK_WEST: physics.MovementAspect = undefined;
    pub var BLOCK_EAST: physics.MovementAspect = undefined;
    pub var BLOCK_NORTH: physics.MovementAspect = undefined;
    pub var BLOCK_SOUTH: physics.MovementAspect = undefined;
};

pub const MoveIntegrator = *const fn (movement: *EMovement, delta_time_seconds: Float) bool;

//////////////////////////////////////////////////////////////
//// EMovement Entity Component
//////////////////////////////////////////////////////////////

pub const EMovement = struct {
    pub usingnamespace api.EComponent.Trait(@This(), "EMovement");

    id: Index = UNDEF_INDEX,
    kind: physics.MovementKind = undefined,
    integrator: MoveIntegrator = SimpleStepIntegrator,
    update_scheduler: ?api.UpdateScheduler = null,

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
    clear_per_frame_flags: bool = true,

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

    pub fn flagAll(self: *EMovement, aspects: anytype, _flag: bool) void {
        inline for (aspects) |a|
            flag(self, a, _flag);
    }

    pub fn flag(self: *EMovement, aspect: physics.MovementAspect, _flag: bool) void {
        self.kind.activateAspect(aspect, _flag);
    }
};

//////////////////////////////////////////////////////////////
//// Move Integrations
//////////////////////////////////////////////////////////////

pub fn SimpleStepIntegrator(movement: *EMovement, delta_time_seconds: Float) bool {
    const accMass: Float = 1 / movement.mass * movement.mass_factor;

    movement.velocity[0] += delta_time_seconds * movement.gravity[0] / accMass;
    movement.velocity[1] += delta_time_seconds * movement.gravity[1] / accMass;
    adjustVelocity(movement);

    if (movement.velocity[0] != 0 or movement.velocity[1] != 0) {
        if (graphics.ETransform.byId(movement.id)) |transform| {
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
    const accMass: Float = 1 / movement.mass * movement.mass_factor;

    movement.velocity[0] += delta_time_seconds * (movement.acceleration[0] + ((movement.gravity[0] + movement.force[0]) / accMass)) / 2;
    movement.velocity[1] += delta_time_seconds * (movement.acceleration[1] + ((movement.gravity[1] + movement.force[1]) / accMass)) / 2;
    adjustVelocity(movement);

    if (movement.velocity[0] != 0 or movement.velocity[1] != 0) {
        if (graphics.ETransform.byId(movement.id)) |transform| {
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
    const accMass: Float = 1 / movement.mass * movement.mass_factor;

    movement.acceleration[0] = (movement.gravity[0] + movement.force[0]) / accMass;
    movement.acceleration[1] = (movement.gravity[1] + movement.force[1]) / accMass;
    movement.velocity[0] += delta_time_seconds * movement.acceleration[0];
    movement.velocity[1] += delta_time_seconds * movement.acceleration[1];
    adjustVelocity(movement);

    if (movement.velocity[0] != 0 or movement.velocity[1] != 0) {
        if (graphics.ETransform.byId(movement.id)) |transform| {
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
        if (movement.kind.hasAspect(MovFlags.BLOCK_NORTH) and movement.velocity[1] < 0)
            movement.velocity[1] = 0;
        if (movement.kind.hasAspect(MovFlags.BLOCK_EAST) and movement.velocity[0] > 0)
            movement.velocity[0] = 0;
        if (movement.kind.hasAspect(MovFlags.BLOCK_SOUTH) and movement.velocity[1] > 0)
            movement.velocity[1] = 0;
        if (movement.kind.hasAspect(MovFlags.BLOCK_WEST) and movement.velocity[0] < 0)
            movement.velocity[0] = 0;
    }

    if (movement.clear_per_frame_flags) {
        movement.flagAll(.{
            MovFlags.SLIP_LEFT,
            MovFlags.SLIP_RIGHT,
            MovFlags.BLOCK_EAST,
            MovFlags.BLOCK_WEST,
            MovFlags.BLOCK_NORTH,
            MovFlags.BLOCK_SOUTH,
            MovFlags.ON_SLOPE_UP,
            MovFlags.ON_SLOPE_DOWN,
            MovFlags.GROUND_TOUCHED,
            MovFlags.LOST_GROUND,
        }, false);
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

pub const MovementSystem = struct {
    pub usingnamespace api.SystemTrait(MovementSystem);
    pub usingnamespace api.EntityUpdateTrait(MovementSystem);

    pub const accept = .{EMovement};

    var moved: utils.BitSet = undefined;
    var event_dispatch: utils.EventDispatch(MovementEvent) = undefined;
    var event: MovementEvent = MovementEvent{};

    pub fn systemInit() void {
        moved = utils.BitSet.new(firefly.api.COMPONENT_ALLOC);
        event.moved = &moved;
        event_dispatch = utils.EventDispatch(MovementEvent).new(firefly.api.COMPONENT_ALLOC);
    }

    pub fn systemDeinit() void {
        moved.deinit();
        moved = undefined;
        event.moved = undefined;
        event_dispatch.deinit();
        event_dispatch = undefined;
    }

    pub fn updateEntities(components: *utils.BitSet) void {
        const dt: Float = @min(@as(Float, @floatFromInt(api.Timer.d_time)) / 1000, 0.5);
        moved.clear();
        var next = components.nextSetBit(0);
        while (next) |i| {
            if (EMovement.byId(i)) |m| {
                if (m.active) {
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
            }
            next = components.nextSetBit(i + 1);
        }
        if (moved.count() > 0)
            event_dispatch.notify(event);
    }
};
