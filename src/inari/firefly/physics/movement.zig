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

pub const MovePoint = struct {
    v: *Vector2f,
    a: *Vector2f,
    p: *Vector2f,
    p_old: *Vector2f,
};

pub const MoveIntegrator = struct {
    velocity_integration: *const fn (p: MovePoint, delta_time_seconds: Float) void,
    position_integration: *const fn (p: MovePoint, delta_time_seconds: Float) void,
};

//////////////////////////////////////////////////////////////
//// EMovement Entity Component
//////////////////////////////////////////////////////////////

pub const EMovementConstraint = *const fn (id: Index) void;
pub const EMovement = struct {
    pub const Component = api.EntityComponentMixin(EMovement);

    id: Index = UNDEF_INDEX,
    kind: physics.MovementKind = undefined,
    integrator: MoveIntegrator = SimpleStepIntegrator,
    constraint: ?EMovementConstraint = DefaultVelocityConstraint,
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

    on_ground: bool = false,

    max_velocity_north: ?Float = null,
    max_velocity_east: ?Float = null,
    max_velocity_south: ?Float = null,
    max_velocity_west: ?Float = null,

    adjust_max: bool = true,
    adjust_ground: bool = true,
    adjust_block: bool = false,
    clear_per_frame_flags: bool = true,

    _mass_vec: Vector2f = undefined,
    _m_point: MovePoint = undefined,

    pub fn activation(self: *EMovement, active: bool) void {
        self.active = active;
        if (active) {
            self._mass_vec = @splat(self.mass);
            const p_ref = &graphics.ETransform.Component.byId(self.id).position;
            //std.debug.print("trans pos: {d}\n", .{p_ref});
            self._m_point = MovePoint{
                .a = &self.acceleration,
                .v = &self.velocity,
                .p = p_ref,
                .p_old = &self.old_position,
            };

            self.old_position = p_ref.*;
        }
    }

    pub fn destruct(self: *EMovement) void {
        self.id = UNDEF_INDEX;
        self.kind = undefined;
        self.integrator = SimpleStepIntegrator;

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

    pub inline fn flag(self: *EMovement, aspect: physics.MovementAspect, _flag: bool) void {
        self.kind.activateAspect(aspect, _flag);
    }
};

//////////////////////////////////////////////////////////////
//// Move Integrations
//////////////////////////////////////////////////////////////

/// Frame delta time independent moving point integration
pub const SimpleStepIntegrator: MoveIntegrator = .{
    .velocity_integration = ss_v_int,
    .position_integration = ss_p_int,
};

pub const step_vec: Vector2f = @splat(1.0 / 60.0);
fn ss_v_int(p: MovePoint, _: Float) void {
    p.v.* += p.a.* * step_vec;
}
fn ss_p_int(p: MovePoint, _: Float) void {
    p.p_old.* = p.p.*;
    p.p.* += p.v.* * step_vec;
}

/// Frame delta time independent moving point integration
pub const FPSStepIntegrator: MoveIntegrator = .{
    .velocity_integration = fps_v_int,
    .position_integration = fps_p_int,
};

var step_vec_fps: Vector2f = @splat(1.0 / 60.0);
fn fps_v_int(p: MovePoint, _: Float) void {
    p.v.* += p.a.* * step_vec_fps;
}
fn fps_p_int(p: MovePoint, _: Float) void {
    p.p_old.* = p.p.*;
    p.p.* += p.v.* * step_vec_fps;
}

/// Frame delta time dependent moving point integration based on Euler's equation of motion
pub const EulerIntegrator: MoveIntegrator = .{
    .velocity_integration = euler_v_int,
    .position_integration = euler_p_int,
};

fn euler_v_int(p: MovePoint, delta_time_seconds: Float) void {
    p.v.* += p.a.* * @as(Vector2f, @splat(delta_time_seconds));
}

fn euler_p_int(p: MovePoint, delta_time_seconds: Float) void {
    p.p_old.* = p.p.*;
    p.p.* += p.v.* * @as(Vector2f, @splat(delta_time_seconds));
}

/// Frame delta time dependent moving point integration based on Verlet's integration method
const vec2: Vector2f = @splat(2);
pub const VerletIntegrator: MoveIntegrator = .{
    .velocity_integration = euler_v_int,
    .position_integration = verlet_p_int,
};

fn verlet_p_int(p: MovePoint, delta_time_seconds: Float) void {
    const old = p.p.*;
    p.p.* = (vec2 * p.p.* - p.p_old.*) + p.a.* * @as(Vector2f, @splat(delta_time_seconds * delta_time_seconds));
    p.p_old.* = old;
}

//////////////////////////////////////////////////////////////
//// Default Move Velocity Constraint
//////////////////////////////////////////////////////////////

pub fn DefaultVelocityConstraint(entity_id: Index) void {
    var movement = EMovement.Component.byId(entity_id);

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
        const delta_time_seconds: Float = @min(@as(Float, @floatFromInt(api.Timer.d_time)) / 1000, 0.5);
        moved.clear();
        var next = components.nextSetBit(0);
        while (next) |i| {
            next = components.nextSetBit(i + 1);
            const m = EMovement.Component.byId(i);
            if (m.active) {

                // clear move flags per frame if requested
                if (m.clear_per_frame_flags)
                    m.kind.removeAspects(clear_kind);

                // calc acceleration: (force + gravity) * mass
                m.acceleration = (m.force + m.gravity_vector) * m._mass_vec;

                // delta time
                const dt = if (m.update_scheduler != null)
                    delta_time_seconds * (60 / @min(60, m.update_scheduler.?.resolution))
                else
                    delta_time_seconds;

                // do velocity integration
                m.integrator.velocity_integration(m._m_point, dt);

                // apply velocity constraint if available
                if (m.constraint) |c|
                    //@call(std.builtin.CallModifier.always_inline, c, .{i});
                    c(i);

                // integrate position
                m.integrator.position_integration(m._m_point, dt);
                moved.setValue(i, m.velocity[0] != 0 or m.velocity[1] != 0);
            }
        }
        if (moved.count() > 0)
            event_dispatch.notify(event);
    }
};
