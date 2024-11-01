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

    api.Entity.registerComponent(EMovement, "EMovement");
    api.System.register(MovementSystem);

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

pub const IntegrationType = enum {
    SimpleStep,
    FPSStep,
    Euler,
    Verlet,
};

pub const VelocityConstraint = *const fn (data: anytype) void;
pub const MoveIntegrator = *const fn (
    data: anytype,
    constraint: ?VelocityConstraint,
    delta_time_seconds: Float,
) bool;
pub const MoveConstraint = *const fn (data: anytype) void;

//////////////////////////////////////////////////////////////
//// EMovement Entity Component
//////////////////////////////////////////////////////////////

pub const EMovement = struct {
    pub const Component = api.EntityComponentMixin(EMovement);

    id: Index = UNDEF_INDEX,
    kind: physics.MovementKind = undefined,
    integrator: IntegrationType = IntegrationType.SimpleStep,
    //constraint: ?*const fn (data: *EMovement) void = null,
    update_scheduler: ?*api.UpdateScheduler = null,

    active: bool = true,

    /// the gravity vector for this object. Default is earth gravity
    gravity_vector: Vector2f = Vector2f{ 0, firefly.physics.EARTH_GRAVITY },
    /// mass factor vector
    mass: Float = 50,
    /// additional external force
    force: Vector2f = Vector2f{ 0, 0 },
    /// acceleration is been calculated for integration data: (force + gravity) * mass_factor
    acceleration: Vector2f = Vector2f{ 0, 0 },
    velocity: Vector2f = Vector2f{ 0, 0 },
    old_position: Vector2f = Vector2f{ 0, 0 },
    _mass_vec: Vector2f = undefined,

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
        self._mass_vec = @splat(self.mass);
        self.old_position = graphics.ETransform.Component.byId(self.id).position;
    }

    pub fn destruct(self: *EMovement) void {
        self.id = UNDEF_INDEX;
        self.kind = undefined;
        self.integrator = IntegrationType.SimpleStep;
        //       self.constraint = null;

        self.active = true;
        self.mass = 50;
        self._mass_vec = undefined;
        self.force = Vector2f{ 0, 0 };
        self.acceleration = Vector2f{ 0, 0 };
        self.velocity = Vector2f{ 0, 0 };
        self.old_position = Vector2f{ 0, 0 };
        self.gravity_vector = Vector2f{ 0, firefly.physics.EARTH_GRAVITY };

        self.on_ground = false;

        self.max_velocity_north = null;
        self.max_velocity_east = null;
        self.max_velocity_south = null;
        self.max_velocity_west = null;

        self.adjust_max = true;
        self.adjust_ground = true;
        self.adjust_block = false;
    }

    pub fn integrate(self: *EMovement, delta_time_seconds: Float) bool {
        // calc acceleration: (force + gravity) * mass
        self.acceleration = (self.force + self.gravity_vector) * self._mass_vec;
        const dt = if (self.update_scheduler != null)
            delta_time_seconds * (60 / @min(60, self.update_scheduler.?.resolution))
        else
            delta_time_seconds;

        return switch (self.integrator) {
            IntegrationType.SimpleStep => SimpleStepIntegrator(self, adjustVelocity, dt),
            IntegrationType.FPSStep => FPSStepIntegrator(self, adjustVelocity, dt),
            IntegrationType.Euler => EulerIntegrator(self, adjustVelocity, dt),
            IntegrationType.Verlet => VerletIntegrator(self, adjustVelocity, dt),
        };
    }

    pub inline fn flag(self: *EMovement, aspect: physics.MovementAspect, _flag: bool) void {
        self.kind.activateAspect(aspect, _flag);
    }
};

//////////////////////////////////////////////////////////////
//// Move Integrations
//////////////////////////////////////////////////////////////

const step_vec_60FPS: Vector2f = @splat(1.0 / 60.0);
var step_vec_fps: Vector2f = @splat(1.0 / 60.0);

/// Frame delta time independent moving point integration
pub fn SimpleStepIntegrator(mov: anytype, constraint: ?VelocityConstraint, _: Float) bool {
    mov.velocity += mov.acceleration * step_vec_60FPS;
    if (constraint) |c|
        c(mov);

    if (mov.velocity[0] != 0 or mov.velocity[1] != 0) {
        var trans = graphics.ETransform.Component.byId(mov.id);
        mov.old_position = trans.position;
        trans.position += mov.velocity * step_vec_60FPS;
        return true;
    }
    return false;
}

pub fn FPSStepIntegrator(mov: anytype, constraint: ?VelocityConstraint, _: Float) bool {
    mov.velocity += mov.acceleration * step_vec_fps;
    if (constraint) |c|
        c(mov);

    if (mov.velocity[0] != 0 or mov.velocity[1] != 0) {
        var trans = graphics.ETransform.Component.byId(mov.id);
        mov.old_position = trans.position;
        trans.position += mov.velocity * step_vec_fps;
        return true;
    }
    return false;
}

/// Frame delta time dependent moving point integration based on Euler's equation of motion
pub fn EulerIntegrator(mov: anytype, constraint: ?VelocityConstraint, delta_time_seconds: Float) bool {
    const dtv: Vector2f = @splat(delta_time_seconds);
    mov.velocity += mov.acceleration * dtv;
    if (constraint) |c|
        c(mov);

    if (mov.velocity[0] != 0 or mov.velocity[1] != 0) {
        var trans = graphics.ETransform.Component.byId(mov.id);
        mov.old_position = trans.position;
        trans.position += mov.velocity * dtv;
        return true;
    }
    return false;
}

/// Frame delta time dependent moving point integration based on Verlet's integration method
const vec2: Vector2f = @splat(2);
pub fn VerletIntegrator(mov: anytype, constraint: ?VelocityConstraint, delta_time_seconds: Float) bool {
    if (delta_time_seconds > 0.1)
        return false;

    const dtv: Vector2f = @splat(@min(delta_time_seconds, 1));
    mov.velocity += mov.acceleration * dtv;
    if (constraint) |c|
        c(mov);

    if (mov.velocity[0] != 0 or mov.velocity[1] != 0) {
        var trans = graphics.ETransform.Component.byId(mov.id);
        const old_pos = trans.position;
        trans.position = (vec2 * trans.position - mov.old_position) + mov.acceleration * dtv * dtv;
        mov.old_position = old_pos;
        return true;
    }
    return false;
}

pub fn adjustVelocity(movement: anytype) void {
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
//// Movement System
//////////////////////////////////////////////////////////////
pub const MovementSystem = struct {
    pub const System = api.SystemMixin(MovementSystem);
    pub const EntityUpdate = api.EntityUpdateSystemMixin(MovementSystem);

    pub const accept = .{EMovement};

    var moved: utils.BitSet = undefined;
    var event_dispatch: utils.EventDispatch(MovementEvent) = undefined;
    var event: MovementEvent = MovementEvent{};
    var clear_kind: physics.MovementKind = undefined;

    pub fn systemInit() void {
        moved = utils.BitSet.new(firefly.api.COMPONENT_ALLOC);
        event.moved = &moved;
        event_dispatch = utils.EventDispatch(MovementEvent).new(firefly.api.COMPONENT_ALLOC);
        clear_kind = physics.MovementKind.of(.{
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
        });
    }

    pub fn systemDeinit() void {
        moved.deinit();
        moved = undefined;
        event.moved = undefined;
        event_dispatch.deinit();
        event_dispatch = undefined;
    }

    pub fn updateEntities(components: *utils.BitSet) void {
        // update fps related vector for integration needs
        const fps = api.window.getFPS();
        if (fps > 0 and fps < 100)
            step_vec_fps = @splat(1.0 / fps);

        // update all EMovement components
        const dt: Float = @min(@as(Float, @floatFromInt(api.Timer.d_time)) / 1000, 0.5);
        moved.clear();
        var next = components.nextSetBit(0);
        while (next) |i| {
            next = components.nextSetBit(i + 1);
            const m = EMovement.Component.byId(i);
            if (m.active) {
                if (m.clear_per_frame_flags)
                    m.kind.removeAspects(clear_kind);

                moved.setValue(i, m.integrate(dt));
            }
        }
        if (moved.count() > 0)
            event_dispatch.notify(event);
    }
};
