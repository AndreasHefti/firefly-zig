const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;

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
    api.System(MovementSystem).createSystem(
        firefly.Engine.CoreSystems.MovementSystem.name,
        "Processes the movement for all Entities with EMovement component",
        true,
    );

    MovFlags.ON_SLOPE_UP = MovementAspectGroup.getAspect("ON_SLOPE_UP");
    MovFlags.ON_SLOPE_DOWN = MovementAspectGroup.getAspect("ON_SLOPE_DOWN");
    MovFlags.GROUND_TOUCHED = MovementAspectGroup.getAspect("GROUND_TOUCHED");
    MovFlags.LOST_GROUND = MovementAspectGroup.getAspect("LOST_GROUND");
    MovFlags.SLIP_RIGHT = MovementAspectGroup.getAspect("SLIP_RIGHT");
    MovFlags.SLIP_LEFT = MovementAspectGroup.getAspect("SLIP_RIGHT");
    MovFlags.JUMP = MovementAspectGroup.getAspect("JUMP");
    MovFlags.DOUBLE_JUMP = MovementAspectGroup.getAspect("DOUBLE_JUMP");
    MovFlags.CLIMB_UP = MovementAspectGroup.getAspect("CLIMB_UP");
    MovFlags.CLIMB_DOWN = MovementAspectGroup.getAspect("CLIMB_DOWN");
    MovFlags.BLOCK_WEST = MovementAspectGroup.getAspect("BLOCK_WEST");
    MovFlags.BLOCK_EAST = MovementAspectGroup.getAspect("BLOCK_EAST");
    MovFlags.BLOCK_NORTH = MovementAspectGroup.getAspect("BLOCK_NORTH");
    MovFlags.BLOCK_SOUTH = MovementAspectGroup.getAspect("BLOCK_SOUTH");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    api.System(MovementSystem).disposeSystem();
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

pub const MovementAspectGroup = utils.AspectGroup(struct {
    pub const name = "Movement";
});
pub const MovementAspect = MovementAspectGroup.Aspect;
pub const MovementKind = MovementAspectGroup.Kind;

pub const MovFlags = struct {
    pub var ON_SLOPE_UP: MovementAspect = undefined;
    pub var ON_SLOPE_DOWN: MovementAspect = undefined;
    pub var GROUND_TOUCHED: MovementAspect = undefined;
    pub var LOST_GROUND: MovementAspect = undefined;
    pub var SLIP_RIGHT: MovementAspect = undefined;
    pub var SLIP_LEFT: MovementAspect = undefined;
    pub var JUMP: MovementAspect = undefined;
    pub var DOUBLE_JUMP: MovementAspect = undefined;
    pub var CLIMB_UP: MovementAspect = undefined;
    pub var CLIMB_DOWN: MovementAspect = undefined;
    pub var BLOCK_WEST: MovementAspect = undefined;
    pub var BLOCK_EAST: MovementAspect = undefined;
    pub var BLOCK_NORTH: MovementAspect = undefined;
    pub var BLOCK_SOUTH: MovementAspect = undefined;
};

pub const MoveIntegrator = *const fn (movement: *EMovement, delta_time_seconds: Float) bool;

//////////////////////////////////////////////////////////////
//// EMovement Entity Component
//////////////////////////////////////////////////////////////

pub const EMovement = struct {
    pub usingnamespace api.EComponent.Trait(@This(), "EMovement");

    id: Index = UNDEF_INDEX,
    kind: MovementKind = undefined,
    integrator: MoveIntegrator = SimpleStepIntegrator,
    update_scheduler: ?api.UpdateScheduler = null,

    active: bool = true,
    mass: Float = 80,
    mass_factor: Float = 1,
    force: Vector2f = Vector2f{ 0, 0 },
    acceleration: Vector2f = Vector2f{ 0, 0 },
    velocity: Vector2f = Vector2f{ 0, 0 },
    gravity: Vector2f = Vector2f{ 0, firefly.physics.Gravity },

    on_ground: bool = false,

    max_velocity_north: Float = 10000000,
    max_velocity_south: Float = 200,
    max_velocity_east: Float = 80,
    max_velocity_west: Float = 80,

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

        self.adjust_max = true;
        self.adjust_ground = true;
        self.adjust_block = false;
    }

    pub fn flagAll(self: *EMovement, aspects: anytype, _flag: bool) void {
        inline for (aspects) |a|
            flag(self, a, _flag);
    }

    pub fn flag(self: *EMovement, aspect: MovementAspect, _flag: bool) void {
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
    //std.debug.print("velocity: {d}\n", .{movement.velocity});

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

    if (movement.adjust_ground and movement.on_ground)
        movement.velocity[1] = 0;

    if (movement.adjust_max) {
        if (movement.max_velocity_south > 0)
            movement.velocity[1] = @min(movement.velocity[1], movement.max_velocity_south);
        if (movement.max_velocity_east > 0)
            movement.velocity[0] = @min(movement.velocity[0], movement.max_velocity_east);
        if (movement.max_velocity_north > 0)
            movement.velocity[1] = @max(movement.velocity[1], -movement.max_velocity_north);
        if (movement.max_velocity_west > 0)
            movement.velocity[0] = @max(movement.velocity[0], -movement.max_velocity_west);
    }

    //std.debug.print(" --> velocity: {d}\n", .{movement.velocity});
}

//////////////////////////////////////////////////////////////
//// Move System
//////////////////////////////////////////////////////////////

const MovementSystem = struct {
    pub var entity_condition: api.EntityTypeCondition = undefined;

    var movements: utils.BitSet = undefined;
    var moved: utils.BitSet = undefined;
    var event_dispatch: utils.EventDispatch(MovementEvent) = undefined;
    var event: MovementEvent = MovementEvent{};

    pub fn systemInit() void {
        entity_condition = api.EntityTypeCondition{
            .accept_kind = api.EComponentAspectGroup.newKindOf(.{EMovement}),
        };
        movements = utils.BitSet.new(firefly.api.COMPONENT_ALLOC);
        moved = utils.BitSet.new(firefly.api.COMPONENT_ALLOC);
        event.moved = &moved;
        event_dispatch = utils.EventDispatch(MovementEvent).new(firefly.api.COMPONENT_ALLOC);
    }

    pub fn systemDeinit() void {
        movements.deinit();
        movements = undefined;
        moved.deinit();
        moved = undefined;
        event.moved = undefined;
        event_dispatch.deinit();
        event_dispatch = undefined;
        entity_condition = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (register)
            movements.set(id)
        else
            movements.unset(id);
    }

    pub fn update(_: api.UpdateEvent) void {
        const dt: Float = @min(@as(Float, @floatFromInt(api.Timer.d_time)) / 1000, 0.5);
        moved.clear();
        var next = movements.nextSetBit(0);
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
            next = movements.nextSetBit(i + 1);
        }
        if (moved.count() > 0)
            event_dispatch.notify(event);
    }
};
