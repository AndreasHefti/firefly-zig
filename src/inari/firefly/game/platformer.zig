const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const physics = firefly.physics;
const graphics = firefly.graphics;

const Vector2i = utils.Vector2i;
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

pub const PlatformerCollisionResolver = struct {
    const Data = struct {
        ground_addition: CInt,
        scan_length: usize,
        terrain_constraint_name: String,

        north: Sensor = undefined,
        south: Sensor = undefined,
        west: Sensor = undefined,
        east: Sensor = undefined,
        ground_offset: Vector2i = undefined,
        ground_scan: BitMask = undefined,
        terrain_constraint_ref: Index = undefined,

        fn deinit(self: *Data) void {
            self.north.deinit();
            self.north = undefined;
            self.south.deinit();
            self.south = undefined;
            self.west.deinit();
            self.west = undefined;
            self.east.deinit();
            self.east = undefined;
            self.ground_scan.deinit();
            self.ground_scan = undefined;
        }

        fn new(terrain_constraint_name: String) Data {
            return newWith(5, 5, terrain_constraint_name);
        }

        fn newWith(ground_addition: usize, scan_length: usize, terrain_constraint_name: String) Data {
            return Data{
                .ground_addition = utils.usize_cint(ground_addition),
                .scan_length = scan_length,
                .terrain_constraint_name = terrain_constraint_name,
            };
        }
    };

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

    var instances: utils.DynArray(Data) = undefined;

    fn init() void {
        instances = utils.DynArray(Data).newWithRegisterSize(api.COMPONENT_ALLOC, 5);
    }

    fn deinit() void {
        var next = instances.slots.nextSetBit(0);
        while (next) |i| {
            if (instances.get(i)) |inst| inst.deinit();
            next = instances.slots.nextSetBit(i + 1);
        }

        instances.deinit();
        instances = undefined;
    }

    fn initData(_: Index, instance_id: Index) void {
        var data = instances.get(instance_id).?;
        const constraint = physics.ContactConstraint.byName(data.terrain_constraint_name).?;
        const x_half: CInt = utils.f32_cint(constraint.scan.bounds.rect[2] / 2);
        const x_full: CInt = utils.f32_cint(constraint.scan.bounds.rect[2] - 3);
        const y_half: CInt = utils.f32_cint(constraint.scan.bounds.rect[3] / 2) - data.ground_addition;
        const y_full: CInt = utils.f32_cint(constraint.scan.bounds.rect[3] - 3) - data.ground_addition;

        data.north = Sensor{
            .pos1 = .{ 2, 0 },
            .pos2 = .{ x_half, 0 },
            .pos3 = .{ x_full, 0 },
            .s1 = BitMask.new(api.ALLOC, 1, data.scan_length),
            .s2 = BitMask.new(api.ALLOC, 1, data.scan_length),
            .s3 = BitMask.new(api.ALLOC, 1, data.scan_length),
        };
        data.south = Sensor{
            .pos1 = .{ 2, y_full },
            .pos2 = .{ x_half, y_full },
            .pos3 = .{ x_full, y_full },
            .s1 = BitMask.new(api.ALLOC, 1, data.scan_length + utils.cint_usize(data.ground_addition)),
            .s2 = BitMask.new(api.ALLOC, 1, data.scan_length + utils.cint_usize(data.ground_addition)),
            .s3 = BitMask.new(api.ALLOC, 1, data.scan_length + utils.cint_usize(data.ground_addition)),
        };
        data.west = Sensor{
            .pos1 = .{ 0, 2 },
            .pos2 = .{ 0, y_half },
            .pos3 = .{ 0, y_full },
            .s1 = BitMask.new(api.ALLOC, data.scan_length, 1),
            .s2 = BitMask.new(api.ALLOC, data.scan_length, 1),
            .s3 = BitMask.new(api.ALLOC, data.scan_length, 1),
        };
        data.east = Sensor{
            .pos1 = .{ x_full, 2 },
            .pos2 = .{ x_full, y_half },
            .pos3 = .{ x_full, y_full },
            .s1 = BitMask.new(api.ALLOC, data.scan_length, 1),
            .s2 = BitMask.new(api.ALLOC, data.scan_length, 1),
            .s3 = BitMask.new(api.ALLOC, data.scan_length, 1),
        };
        data.ground_offset = .{ 2, utils.f32_cint(@ceil(constraint.scan.bounds.rect[3])) - data.ground_addition };
        data.ground_scan = BitMask.new(
            api.ALLOC,
            utils.f32_usize(@floor(constraint.scan.bounds.rect[2])) - 3,
            1,
        );
        data.terrain_constraint_ref = constraint.id;
    }

    pub fn new(terrain_constraint_name: String) physics.CollisionResolver {
        return physics.CollisionResolver{
            ._instance_id = instances.add(Data.new(terrain_constraint_name)),
            ._resolve = resolve,
            ._init = initData,
        };
    }

    fn resolve(entity_id: Index, instance_id: ?Index) void {
        const data = instances.get(instance_id.?) orelse return;
        var terr_scan: *physics.ContactConstraint = physics.ContactConstraint.byId(data.terrain_constraint_ref);

        if (terr_scan.scan.hasAnyContact()) {
            var move = physics.EMovement.byId(entity_id) orelse return;
            const pref_ground = move.on_ground;
            move.on_ground = false;
            resolveTerrainContact(data, terr_scan, entity_id, move, pref_ground);
        }
    }

    fn resolveTerrainContact(
        self: *Data,
        terr_scan: *physics.ContactConstraint,
        entity_id: Index,
        move: *physics.EMovement,
        pref_ground: bool,
    ) void {
        const transform = graphics.ETransform.byId(entity_id) orelse return;
        takeFullLedgeScans(self, &terr_scan.scan);

        resolveVertically(self, terr_scan, entity_id, transform, move);
        resolveHorizontally(self, terr_scan, entity_id, transform, move);

        //std.debug.print("contact: {any}\n", .{terr_scan.scan.mask});
        //std.debug.print("ground: {any}\n", .{self.ground_scan});
        // std.debug.print("south1: {any}\n", .{self.south.s1});
        // std.debug.print("south3: {any}\n", .{self.south.s3});

        move.flag(MovFlags.GROUND_TOUCHED, !pref_ground and move.on_ground);
        move.flag(MovFlags.LOST_GROUND, pref_ground and !move.on_ground);
    }

    fn resolveVertically(
        self: *Data,
        terr_scan: *physics.ContactConstraint,
        entity_id: Index,
        transform: *graphics.ETransform,
        move: *physics.EMovement,
    ) void {
        var refresh = false;
        var set_on_ground = false;
        move.flagAll(.{
            MovFlags.ON_SLOPE_DOWN,
            MovFlags.ON_SLOPE_UP,
            MovFlags.BLOCK_NORTH,
        }, false);

        const b1 = utils.usize_cint(self.south.s1.count());
        const b3 = utils.usize_cint(self.south.s3.count());
        //std.debug.print("b1: {d} b3: {d}\n ", .{ b1, b3 });

        const on_slope = b1 != 0 and b3 != 0 and b1 != b3 and
            self.ground_scan.count() < self.ground_scan.width;

        //std.debug.print("onSlope: {any}\n", .{on_slope});

        if (on_slope and move.velocity[1] >= 0) {
            //std.debug.print("adjust slope \n", .{});
            if (b1 > b3) {
                const gap = b1 - self.ground_addition;
                if (gap >= -1) {
                    transform.moveCInt(0, -gap);
                    transform.position[1] = @ceil(transform.position[1]);
                    move.velocity[1] = 0;
                    refresh = true;
                    set_on_ground = true;
                    const slope_o: bool = b1 - b3 > 0;
                    move.flag(MovFlags.ON_SLOPE_DOWN, slope_o);
                    move.flag(MovFlags.ON_SLOPE_UP, !slope_o);
                }
            } else {
                //std.debug.print("slope south-west {d}\n", .{b3 - self.ground_addition});
                const gap = b3 - self.ground_addition;
                if (gap >= -1) {
                    transform.moveCInt(0, -gap);
                    std.debug.print("move y {d} y: {d}\n", .{ -gap, transform.position[1] });
                    transform.position[1] = @ceil(transform.position[1]);
                    move.velocity[1] = 0;
                    refresh = true;
                    set_on_ground = true;
                    const slope_o = (b1 - b3 > 0);
                    move.flag(MovFlags.ON_SLOPE_DOWN, slope_o);
                    move.flag(MovFlags.ON_SLOPE_UP, !slope_o);
                }
            }
        } else if (self.south.max > self.ground_addition and move.velocity[1] >= 0) {
            //std.debug.print("adjust ground: {d} : {d} \n", .{ self.south.max - self.ground_addition, move.velocity[1] });
            transform.moveCInt(0, -(self.south.max - self.ground_addition));
            transform.position[1] = @ceil(transform.position[1]);
            move.velocity[1] = 0;
            refresh = true;
            set_on_ground = true;
        }

        if (self.north.max > 0) {
            //std.debug.print("adjust top {d} \n", .{self.north.max});
            transform.moveCInt(0, self.north.max);
            transform.position[1] = @floor(transform.position[1]);
            if (move.velocity[1] < 0)
                move.velocity[1] = 0;
            refresh = true;
            move.flag(MovFlags.BLOCK_NORTH, true);
        }

        if (refresh) {
            updateContacts(entity_id, terr_scan);
            takeFullLedgeScans(self, &terr_scan.scan);
        }

        std.debug.print("set_on_ground: {any} : {d} \n", .{ set_on_ground, self.ground_scan.count() });
        move.on_ground = set_on_ground or (move.velocity[1] >= 0 and self.ground_scan.count() > 0);
        if (move.on_ground)
            transform.position[1] = @ceil(transform.position[1]);
    }

    fn resolveHorizontally(
        self: *Data,
        terr_scan: *physics.ContactConstraint,
        entity_id: Index,
        transform: *graphics.ETransform,
        move: *physics.EMovement,
    ) void {
        var refresh = false;
        move.flagAll(.{
            MovFlags.SLIP_LEFT,
            MovFlags.SLIP_RIGHT,
            MovFlags.BLOCK_EAST,
            MovFlags.BLOCK_WEST,
        }, false);

        if (self.west.max > 0) {
            std.debug.print("adjust left: {any}\n", .{self.west.max});
            transform.moveCInt(self.west.max, 0);
            transform.position[0] = @floor(transform.position[0]);
            move.flag(MovFlags.SLIP_RIGHT, move.velocity[0] > -1);
            move.flag(MovFlags.BLOCK_WEST, move.velocity[0] <= 0);
            move.velocity[0] = 0;
            refresh = true;
        }

        if (self.east.max > 0) {
            std.debug.print("adjust right: {any}\n", .{-self.east.max});
            transform.moveCInt(-self.east.max, 0);
            transform.position[0] = @ceil(transform.position[0]);
            move.flag(MovFlags.SLIP_RIGHT, move.velocity[0] < -1);
            move.flag(MovFlags.BLOCK_WEST, move.velocity[0] >= 0);
            move.velocity[0] = 0;
            refresh = true;
        }

        if (refresh) {
            updateContacts(entity_id, terr_scan);
            takeFullLedgeScans(self, &terr_scan.scan);
        }
    }

    fn updateContacts(entity_id: Index, terr_scan: *physics.ContactConstraint) void {
        var contacts: *physics.EContactScan = physics.EContactScan.byId(entity_id) orelse return;
        if (!contacts.hasAnyContact())
            return;

        _ = physics.ContactSystem.applyScanForConstraint(entity_id, terr_scan);
    }

    fn takeFullLedgeScans(data: *Data, contact: *physics.ContactScan) void {
        data.north.scan(contact);
        data.south.scan(contact);
        data.west.scan(contact);
        data.east.scan(contact);

        data.ground_scan.clear();
        data.ground_scan.setIntersection(contact.mask.?, -data.ground_offset, utils.bitOpOR);
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
            if (move.velocity[0] <= -move.max_velocity_west)
                return;

            move.velocity[0] = if (move.velocity[0] > 0)
                @max(0, move.velocity[0] - self.stop_velocity_step)
            else
                @max(-move.max_velocity_west, move.velocity[0] - self.run_velocity_step);
        } else if (api.input.checkButtonPressed(self.button_right)) {
            if (move.velocity[0] >= move.max_velocity_west)
                return;

            move.velocity[0] = if (move.velocity[0] < 0)
                @min(0, move.velocity[0] + self.stop_velocity_step)
            else
                @min(move.max_velocity_west, move.velocity[0] + self.run_velocity_step);
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