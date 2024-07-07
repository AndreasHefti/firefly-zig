const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const physics = firefly.physics;
const graphics = firefly.graphics;
const game = firefly.game;

const Vector2i = utils.Vector2i;
const RectI = utils.RectI;
const Float = utils.Float;
const CInt = utils.CInt;
const BitMask = utils.BitMask;
const Index = firefly.utils.Index;
const String = firefly.utils.String;
const MovFlags = physics.MovFlags;

//////////////////////////////////////////////////////////////
//// game world init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    PlatformerCollisionResolver.init();
    api.ComponentControlType(SimplePlatformerHorizontalMoveControl).init();
    api.ComponentControlType(SimplePlatformerJumpControl).init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    api.ComponentControlType(SimplePlatformerJumpControl).deinit();
    api.ComponentControlType(SimplePlatformerHorizontalMoveControl).deinit();
    PlatformerCollisionResolver.deinit();
}

//////////////////////////////////////////////////////////////
//// Platformer Collision Resolver
//////////////////////////////////////////////////////////////

const Sensor = struct {
    pos1: Vector2i,
    pos2: Vector2i,
    pos3: Vector2i,
    s1: BitMask,
    s2: BitMask,
    s3: BitMask,
    max: CInt = 0,

    fn deinit(self: *Sensor) void {
        self.s1.deinit();
        self.s2.deinit();
        self.s3.deinit();
    }

    fn scan(self: *Sensor, contact: *physics.ContactScan) void {
        self.s1.clear();
        self.s2.clear();
        self.s3.clear();
        self.max = 0;
        self.s1.setIntersection(contact.mask.?, -self.pos1, utils.bitOpOR);
        self.s2.setIntersection(contact.mask.?, -self.pos2, utils.bitOpOR);
        self.s3.setIntersection(contact.mask.?, -self.pos3, utils.bitOpOR);
        self.max = utils.usize_cint(@max(self.s1.count(), @max(self.s2.count(), self.s3.count())));
    }
};

pub const PlatformerCollisionResolver = struct {
    view_id: ?Index,
    layer_id: ?Index,
    contact_bounds: RectI,
    ground_addition: CInt = 5,
    scan_length: usize = 5,

    _entity_id: Index = undefined,
    _view_id: ?Index = null,
    _transform: *graphics.ETransform = undefined,
    _movement: *physics.EMovement = undefined,

    _north: Sensor = undefined,
    _south: Sensor = undefined,
    _west: Sensor = undefined,
    _east: Sensor = undefined,
    _ground_offset: Vector2i = undefined,
    _ground_scan: BitMask = undefined,
    _terrain_constraint_ref: *physics.ContactConstraint = undefined,

    var instances: utils.DynArray(PlatformerCollisionResolver) = undefined;

    fn init() void {
        instances = utils.DynArray(PlatformerCollisionResolver).newWithRegisterSize(api.COMPONENT_ALLOC, 5);
    }

    fn deinit() void {
        var next = instances.slots.nextSetBit(0);
        while (next) |i| {
            if (instances.get(i)) |inst| {
                inst._north.deinit();
                inst._north = undefined;
                inst._south.deinit();
                inst._south = undefined;
                inst._west.deinit();
                inst._west = undefined;
                inst._east.deinit();
                inst._east = undefined;
                inst._ground_scan.deinit();
                inst._ground_scan = undefined;
            }
            next = instances.slots.nextSetBit(i + 1);
        }

        instances.deinit();
        instances = undefined;
    }

    fn initInstance(entity_id: Index, instance_id: Index) void {
        var inst = instances.get(instance_id).?;
        inst._entity_id = entity_id;
        inst._transform = graphics.ETransform.byId(entity_id).?;
        inst._movement = physics.EMovement.byId(entity_id).?;

        if (graphics.EView.byId(entity_id)) |v|
            inst._view_id = v.view_id;

        var contact_scan: *physics.EContactScan = physics.EContactScan.byId(entity_id).?;
        _ = contact_scan.withConstraint(.{
            .name = "PlatformerCollisionResolver",
            .layer_id = inst.layer_id,
            .bounds = .{ .rect = .{
                utils.cint_float(inst.contact_bounds[0]),
                utils.cint_float(inst.contact_bounds[1]),
                utils.cint_float(inst.contact_bounds[2]),
                utils.cint_float(inst.contact_bounds[3] + inst.ground_addition),
            } },
            .material_filter = physics.ContactMaterialKind.of(.{game.BaseMaterialType.TERRAIN}),
            .full_scan = true,
        });

        inst._terrain_constraint_ref = physics.ContactConstraint.byName("PlatformerCollisionResolver").?;
        const x_half: CInt = @divFloor(inst.contact_bounds[2], 2);
        const x_full: CInt = inst.contact_bounds[2] - 3;
        const y_half: CInt = @divFloor(inst.contact_bounds[3], 2);
        const y_full: CInt = inst.contact_bounds[3] - 3;

        inst._north = Sensor{
            .pos1 = .{ 2, 0 },
            .pos2 = .{ x_half, 0 },
            .pos3 = .{ x_full, 0 },
            .s1 = BitMask.new(api.ALLOC, 1, inst.scan_length),
            .s2 = BitMask.new(api.ALLOC, 1, inst.scan_length),
            .s3 = BitMask.new(api.ALLOC, 1, inst.scan_length),
        };
        inst._south = Sensor{
            .pos1 = .{ 2, y_full },
            .pos2 = .{ x_half, y_full },
            .pos3 = .{ x_full, y_full },
            .s1 = BitMask.new(api.ALLOC, 1, inst.scan_length + utils.cint_usize(inst.ground_addition)),
            .s2 = BitMask.new(api.ALLOC, 1, inst.scan_length + utils.cint_usize(inst.ground_addition)),
            .s3 = BitMask.new(api.ALLOC, 1, inst.scan_length + utils.cint_usize(inst.ground_addition)),
        };
        inst._west = Sensor{
            .pos1 = .{ 0, 2 },
            .pos2 = .{ 0, y_half },
            .pos3 = .{ 0, y_full },
            .s1 = BitMask.new(api.ALLOC, inst.scan_length, 1),
            .s2 = BitMask.new(api.ALLOC, inst.scan_length, 1),
            .s3 = BitMask.new(api.ALLOC, inst.scan_length, 1),
        };
        inst._east = Sensor{
            .pos1 = .{ x_full, 2 },
            .pos2 = .{ x_full, y_half },
            .pos3 = .{ x_full, y_full },
            .s1 = BitMask.new(api.ALLOC, inst.scan_length, 1),
            .s2 = BitMask.new(api.ALLOC, inst.scan_length, 1),
            .s3 = BitMask.new(api.ALLOC, inst.scan_length, 1),
        };
        inst._ground_offset = .{ 2, inst.contact_bounds[3] };
        inst._ground_scan = BitMask.new(
            api.ALLOC,
            utils.cint_usize(inst.contact_bounds[2] - 3),
            1,
        );
    }

    pub fn new(template: PlatformerCollisionResolver) physics.CollisionResolver {
        return physics.CollisionResolver{
            ._instance_id = instances.add(template),
            ._resolve = resolve,
            ._init = initInstance,
        };
    }

    fn resolve(entity_id: Index, instance_id: ?Index) void {
        const data = instances.get(instance_id.?) orelse return;

        if (data._terrain_constraint_ref.scan.hasAnyContact()) {
            var move = physics.EMovement.byId(entity_id) orelse return;
            const pref_ground = move.on_ground;
            move.on_ground = false;
            resolveTerrainContact(data, pref_ground);
        }
    }

    fn resolveTerrainContact(
        self: *PlatformerCollisionResolver,
        pref_ground: bool,
    ) void {
        //const transform = graphics.ETransform.byId(entity_id) orelse return;
        takeFullLedgeScans(self);

        resolveVertically(self);
        resolveHorizontally(self);

        //std.debug.print("contact: {any}\n", .{terr_scan.scan.mask});
        //std.debug.print("ground: {any}\n", .{self._ground_scan});
        // std.debug.print("_south1: {any}\n", .{self._south.s1});
        // std.debug.print("_south3: {any}\n", .{self._south.s3});

        self._movement.flag(MovFlags.GROUND_TOUCHED, !pref_ground and self._movement.on_ground);
        self._movement.flag(MovFlags.LOST_GROUND, pref_ground and !self._movement.on_ground);
    }

    fn resolveVertically(self: *PlatformerCollisionResolver) void {
        var refresh = false;
        var set_on_ground = false;
        self._movement.flagAll(.{
            MovFlags.ON_SLOPE_DOWN,
            MovFlags.ON_SLOPE_UP,
            MovFlags.BLOCK_NORTH,
        }, false);

        const b1 = utils.usize_cint(self._south.s1.count());
        const b3 = utils.usize_cint(self._south.s3.count());
        //std.debug.print("b1: {d} b3: {d}\n ", .{ b1, b3 });

        const on_slope = b1 != 0 and b3 != 0 and b1 != b3 and
            self._ground_scan.count() < self._ground_scan.width;

        //std.debug.print("onSlope: {any}\n", .{on_slope});

        if (on_slope and self._movement.velocity[1] >= 0) {
            //std.debug.print("adjust slope \n", .{});
            if (b1 > b3) {
                const gap = b1 - self.ground_addition;
                if (gap >= -1) {
                    self._transform.moveCInt(0, -gap);
                    self._transform.position[1] = @ceil(self._transform.position[1]);
                    self._movement.velocity[1] = 0;
                    refresh = true;
                    set_on_ground = true;
                    const slope_o: bool = b1 - b3 > 0;
                    self._movement.flag(MovFlags.ON_SLOPE_DOWN, slope_o);
                    self._movement.flag(MovFlags.ON_SLOPE_UP, !slope_o);
                }
            } else {
                //std.debug.print("slope _south-_west {d}\n", .{b3 - self.ground_addition});
                const gap = b3 - self.ground_addition;
                if (gap >= -1) {
                    self._transform.moveCInt(0, -gap);
                    std.debug.print("move y {d} y: {d}\n", .{ -gap, self._transform.position[1] });
                    self._transform.position[1] = @ceil(self._transform.position[1]);
                    self._movement.velocity[1] = 0;
                    refresh = true;
                    set_on_ground = true;
                    const slope_o = (b1 - b3 > 0);
                    self._movement.flag(MovFlags.ON_SLOPE_DOWN, slope_o);
                    self._movement.flag(MovFlags.ON_SLOPE_UP, !slope_o);
                }
            }
        } else if (self._south.max > self.ground_addition and self._movement.velocity[1] >= 0) {
            //std.debug.print("adjust ground: {d} : {d} \n", .{ self._south.max - self.ground_addition, move.velocity[1] });
            self._transform.moveCInt(0, -(self._south.max - self.ground_addition));
            self._transform.position[1] = @ceil(self._transform.position[1]);
            self._movement.velocity[1] = 0;
            refresh = true;
            set_on_ground = true;
        }

        if (self._north.max > 0) {
            //std.debug.print("adjust top {d} \n", .{self._north.max});
            self._transform.moveCInt(0, self._north.max);
            self._transform.position[1] = @floor(self._transform.position[1]);
            if (self._movement.velocity[1] < 0)
                self._movement.velocity[1] = 0;
            refresh = true;
            self._movement.flag(MovFlags.BLOCK_NORTH, true);
        }

        if (refresh) {
            updateContacts(self);
            takeFullLedgeScans(self);
        }

        std.debug.print("set_on_ground: {any} : {d} \n", .{ set_on_ground, self._ground_scan.count() });
        self._movement.on_ground = set_on_ground or (self._movement.velocity[1] >= 0 and self._ground_scan.count() > 0);
        if (self._movement.on_ground)
            self._transform.position[1] = @ceil(self._transform.position[1]);
    }

    fn resolveHorizontally(self: *PlatformerCollisionResolver) void {
        var refresh = false;
        self._movement.flagAll(.{
            MovFlags.SLIP_LEFT,
            MovFlags.SLIP_RIGHT,
            MovFlags.BLOCK_EAST,
            MovFlags.BLOCK_WEST,
        }, false);

        if (self._west.max > 0) {
            std.debug.print("adjust left: {any}\n", .{self._west.max});
            self._transform.moveCInt(self._west.max, 0);
            self._transform.position[0] = @floor(self._transform.position[0]);
            self._movement.flag(MovFlags.SLIP_RIGHT, self._movement.velocity[0] > -1);
            self._movement.flag(MovFlags.BLOCK_WEST, self._movement.velocity[0] <= 0);
            self._movement.velocity[0] = 0;
            refresh = true;
        }

        if (self._east.max > 0) {
            std.debug.print("adjust right: {any}\n", .{-self._east.max});
            self._transform.moveCInt(-self._east.max, 0);
            self._transform.position[0] = @ceil(self._transform.position[0]);
            self._movement.flag(MovFlags.SLIP_RIGHT, self._movement.velocity[0] < -1);
            self._movement.flag(MovFlags.BLOCK_WEST, self._movement.velocity[0] >= 0);
            self._movement.velocity[0] = 0;
            refresh = true;
        }

        if (refresh) {
            updateContacts(self);
            takeFullLedgeScans(self);
        }
    }

    fn updateContacts(self: *PlatformerCollisionResolver) void {
        var contacts: *physics.EContactScan = physics.EContactScan.byId(self._entity_id) orelse return;
        if (!contacts.hasAnyContact())
            return;

        _ = physics.ContactSystem.applyScanForConstraint(
            self._entity_id,
            self._view_id,
            self._terrain_constraint_ref,
        );
    }

    fn takeFullLedgeScans(self: *PlatformerCollisionResolver) void {
        self._north.scan(&self._terrain_constraint_ref.scan);
        self._south.scan(&self._terrain_constraint_ref.scan);
        self._west.scan(&self._terrain_constraint_ref.scan);
        self._east.scan(&self._terrain_constraint_ref.scan);

        self._ground_scan.clear();
        self._ground_scan.setIntersection(
            self._terrain_constraint_ref.scan.mask.?,
            -self._ground_offset,
            utils.bitOpOR,
        );
    }
};

//////////////////////////////////////////////////////////////
//// Simple Platformer Player Move Control
//////////////////////////////////////////////////////////////

pub const SimplePlatformerHorizontalMoveControl = struct {
    pub usingnamespace api.ControlTypeTrait(SimplePlatformerHorizontalMoveControl, api.Entity);

    run_velocity_step: Float = 5,
    stop_velocity_step: Float = 10,
    move_on_air: bool = true,

    button_left: api.InputButtonType = api.InputButtonType.LEFT,
    button_right: api.InputButtonType = api.InputButtonType.RIGHT,

    pub fn update(entity_id: Index, self_id: ?Index) void {
        const self = @This().byId(self_id) orelse return;
        var move = physics.EMovement.byId(entity_id) orelse return;

        if (!self.move_on_air and !move.on_ground)
            return;

        if (api.input.checkButtonPressed(self.button_left)) {
            const max = move.max_velocity_west orelse 10000;
            if (move.velocity[0] <= -max)
                return;

            move.velocity[0] = if (move.velocity[0] > 0)
                @max(0, move.velocity[0] - self.stop_velocity_step)
            else
                @max(-max, move.velocity[0] - self.run_velocity_step);
        } else if (api.input.checkButtonPressed(self.button_right)) {
            const max = move.max_velocity_east orelse 10000;
            if (move.velocity[0] >= max)
                return;

            move.velocity[0] = if (move.velocity[0] < 0)
                @min(0, move.velocity[0] + self.stop_velocity_step)
            else
                @min(max, move.velocity[0] + self.run_velocity_step);
        } else if (move.velocity[0] != 0) {
            move.velocity[0] = if (move.velocity[0] > 0)
                @max(0, move.velocity[0] - self.stop_velocity_step)
            else
                @min(0, move.velocity[0] + self.stop_velocity_step);
        }
    }
};

pub const SimplePlatformerJumpControl = struct {
    pub usingnamespace api.ControlTypeTrait(SimplePlatformerJumpControl, api.Entity);

    jump_button: api.InputButtonType = api.InputButtonType.FIRE_1,
    jump_impulse: Float = 1000,
    double_jump: bool = false,
    jump_action_tolerance: u8 = 5,

    _jump_action: u8 = 0,
    _double_jump_on: bool = true,

    pub fn update(entity_id: Index, self_id: ?Index) void {
        const self = @This().byId(self_id) orelse return;
        var move = physics.EMovement.byId(entity_id) orelse return;

        if (move.on_ground)
            move.flagAll(.{ MovFlags.JUMP, MovFlags.DOUBLE_JUMP }, false);

        if (api.input.checkButtonTyped(self.jump_button)) {
            if (move.on_ground) {
                move.on_ground = false;
                move.velocity[1] = -self.jump_impulse;
                self._double_jump_on = false;
                self._jump_action = 0;
                move.flag(MovFlags.JUMP, true);
            } else if (self.double_jump and !self._double_jump_on) {
                move.velocity[1] = -self.jump_impulse;
                self._double_jump_on = true;
                self._jump_action = 0;
                move.flag(MovFlags.JUMP, false);
                move.flag(MovFlags.DOUBLE_JUMP, true);
            } else {
                self._jump_action = 1;
            }
        } else if (move.on_ground and self._jump_action > 0 and self._jump_action < self.jump_action_tolerance) {
            move.on_ground = false;
            move.velocity[1] = -self.jump_impulse;
            self._double_jump_on = false;
            self._jump_action = 0;
        } else if (self._jump_action > 0 and self._jump_action <= self.jump_action_tolerance) {
            self._jump_action += 1;
        }
    }
};
