const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const physics = firefly.physics;
const graphics = firefly.graphics;

const Vector2i = utils.Vector2i;
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
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    PlatformerCollisionResolver.deinit();
}

//////////////////////////////////////////////////////////////
//// Platformer Collision Resolver
//////////////////////////////////////////////////////////////

pub const PlatformerCollisionResolver = struct {
    const Data = struct {
        ground_offset: Vector2i,
        scan_length: usize,
        bottom_scan_length: usize, // = ground_offset[0] + scan_length
        terrain_constraint_name: String,

        north: Sensor = undefined,
        south: Sensor = undefined,
        west: Sensor = undefined,
        east: Sensor = undefined,
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
            return newWith(.{ 5, 2 }, 5, terrain_constraint_name);
        }

        fn newWith(ground_offset: Vector2i, scan_length: usize, terrain_constraint_name: String) Data {
            return Data{
                .ground_offset = ground_offset,
                .scan_length = scan_length,
                .bottom_scan_length = utils.cint_usize(ground_offset[0]) + scan_length,
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
            self.s1.setIntersection(contact.mask.?, self.pos1, utils.bitOpOR);
            self.s2.setIntersection(contact.mask.?, self.pos2, utils.bitOpOR);
            self.s3.setIntersection(contact.mask.?, self.pos3, utils.bitOpOR);
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
        const y_half: CInt = utils.f32_cint(constraint.scan.bounds.rect[3] / 2);
        const y_full: CInt = utils.f32_cint(constraint.scan.bounds.rect[3] - 3);

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
            .s1 = BitMask.new(api.ALLOC, 1, data.scan_length),
            .s2 = BitMask.new(api.ALLOC, 1, data.scan_length),
            .s3 = BitMask.new(api.ALLOC, 1, data.scan_length),
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
        data.ground_scan = BitMask.new(api.ALLOC, data.scan_length, 1);
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
            var movement = physics.EMovement.byId(entity_id) orelse return;
            const pref_ground = movement.on_ground;
            movement.on_ground = false;
            resolveTerrainContact(data, terr_scan, entity_id, movement, pref_ground);
        }
    }

    inline fn resolveTerrainContact(
        self: *Data,
        terr_scan: *physics.ContactConstraint,
        entity_id: Index,
        movement: *physics.EMovement,
        pref_ground: bool,
    ) void {
        const transform = graphics.ETransform.byId(entity_id) orelse return;
        takeFullLedgeScans(self, &terr_scan.scan);
        resolveVertically(self, terr_scan, entity_id, transform, movement);
        resolveHorizontally(self, terr_scan, entity_id, transform, movement);

        movement.flag(MovFlags.GROUND_TOUCHED, !pref_ground and movement.on_ground);
        movement.flag(MovFlags.LOST_GROUND, pref_ground and !movement.on_ground);
    }

    fn resolveVertically(
        self: *Data,
        terr_scan: *physics.ContactConstraint,
        entity_id: Index,
        transform: *graphics.ETransform,
        movement: *physics.EMovement,
    ) void {
        var refresh = false;
        var set_on_ground = false;
        movement.flagAll(.{
            MovFlags.ON_SLOPE_DOWN,
            MovFlags.ON_SLOPE_UP,
            MovFlags.BLOCK_NORTH,
        }, false);

        const b1 = utils.usize_cint(self.south.s1.count());
        const b3 = utils.usize_cint(self.south.s3.count());

        const on_slope = b1 != 0 and b3 != 0 and b1 != b3 and
            self.ground_scan.count() < self.ground_scan.width;

        //println("onSlope $onSlope")

        if (on_slope and movement.velocity[1] >= 0) {
            //println("adjust slope")
            if (b1 > b3) {
                const gap = b1 - self.ground_offset[0];
                if (gap >= -1) {
                    transform.moveCInt(0, -gap);
                    transform.position[1] = @ceil(transform.position[1]);
                    movement.velocity[1] = 0;
                    refresh = true;
                    set_on_ground = true;
                    const slope_o: bool = b1 - b3 > 0;
                    movement.flag(MovFlags.ON_SLOPE_DOWN, slope_o);
                    movement.flag(MovFlags.ON_SLOPE_UP, !slope_o);
                }
            } else {
                //println("slope south-west")
                const gap = b3 - self.ground_offset[0];
                if (gap >= -1) {
                    transform.moveCInt(0, -gap);
                    transform.position[1] = @ceil(transform.position[1]);
                    movement.velocity[1] = 0;
                    refresh = true;
                    set_on_ground = true;
                    const slope_o = (b1 - b3 > 0);
                    movement.flag(MovFlags.ON_SLOPE_DOWN, slope_o);
                    movement.flag(MovFlags.ON_SLOPE_UP, !slope_o);
                }
            }
        } else if (self.south.max > self.ground_offset[0] and movement.velocity[1] >= 0) {
            //println("adjust ground: ${bmax - gapSouth} : ${movement.velocity.v1 }")
            transform.moveCInt(0, -(self.south.max - self.ground_offset[0]));
            transform.position[1] = @ceil(transform.position[1]);
            movement.velocity[1] = 0;
            refresh = true;
            set_on_ground = true;
        }

        if (self.north.max > 0) {
            //println("adjust top: $tmax")
            transform.moveCInt(0, self.north.max);
            transform.position[1] = @floor(transform.position[1]);
            if (movement.velocity[1] < 0)
                movement.velocity[1] = 0;
            refresh = true;
            movement.flag(MovFlags.BLOCK_NORTH, true);
        }

        if (refresh) {
            updateContacts(entity_id);
            takeFullLedgeScans(self, &terr_scan.scan);
        }

        //println("contactSensorGround.cardinality ${contactSensorGround.cardinality}")
        movement.on_ground = set_on_ground or (movement.velocity[1] >= 0 and self.ground_scan.count() > 0);
        if (movement.on_ground)
            transform.position[1] = @ceil(transform.position[1]);

        //println("onGround ${movement.onGround}")
    }

    fn resolveHorizontally(
        self: *Data,
        terr_scan: *physics.ContactConstraint,
        entity_id: Index,
        transform: *graphics.ETransform,
        movement: *physics.EMovement,
    ) void {
        var refresh = false;
        movement.flagAll(.{
            MovFlags.SLIP_LEFT,
            MovFlags.SLIP_RIGHT,
            MovFlags.BLOCK_EAST,
            MovFlags.BLOCK_WEST,
        }, false);

        if (self.west.max > 0) {
            //println("adjust left: $lmax ${movement.velocity.v0 }")
            transform.moveCInt(self.west.max, 0);
            transform.position[0] = @floor(transform.position[0]);
            movement.flag(MovFlags.SLIP_RIGHT, movement.velocity[0] > -1);
            movement.flag(MovFlags.BLOCK_WEST, movement.velocity[0] <= 0);
            movement.velocity[0] = 0;
            refresh = true;
        }

        if (self.east.max > 0) {
            //println("adjust right: $rmax ${movement.velocity.v0 }")
            transform.moveCInt(-self.west.max, 0);
            transform.position[0] = @ceil(transform.position[0]);
            movement.flag(MovFlags.SLIP_RIGHT, movement.velocity[0] < -1);
            movement.flag(MovFlags.BLOCK_WEST, movement.velocity[0] >= 0);
            movement.velocity[0] = 0;
            refresh = true;
        }

        if (refresh) {
            updateContacts(entity_id);
            takeFullLedgeScans(self, &terr_scan.scan);
        }
    }

    fn updateContacts(entity_id: Index) void {
        var contacts: *physics.EContactScan = physics.EContactScan.byId(entity_id) orelse return;
        if (!contacts.hasAnyContact())
            return;

        physics.ContactSystem.applyScan(contacts);
    }

    fn takeFullLedgeScans(data: *Data, contact: *physics.ContactScan) void {
        data.north.scan(contact);
        data.south.scan(contact);
        data.west.scan(contact);
        data.east.scan(contact);

        data.ground_scan.clear();
        data.ground_scan.setIntersection(contact.mask.?, data.ground_offset, utils.bitOpOR);
    }
};
