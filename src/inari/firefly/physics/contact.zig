const std = @import("std");
const firefly = @import("../firefly.zig");

const System = firefly.api.System;
const TileGrid = firefly.graphics.TileGrid;
const ETile = firefly.graphics.ETile;
const ViewLayerMapping = firefly.graphics.ViewLayerMapping;
const EView = firefly.graphics.EView;
const MovementEvent = firefly.physics.MovementEvent;
const Component = firefly.api.Component;
const Entity = firefly.api.Entity;
const EComponent = firefly.api.EComponent;
const EntityCondition = firefly.api.EntityCondition;
const EComponentAspectGroup = firefly.api.EComponentAspectGroup;
const ETransform = firefly.graphics.ETransform;
const AspectGroup = firefly.utils.AspectGroup;
const DynArray = firefly.utils.DynArray;
const DynIndexArray = firefly.utils.DynIndexArray;
const BitSet = firefly.utils.BitSet;
const BitMask = firefly.utils.BitMask;
const CircleF = firefly.utils.CircleF;
const RectF = firefly.utils.RectF;
const Vector2i = firefly.utils.Vector2i;
const Vector2f = firefly.utils.Vector2f;
const CInt = firefly.utils.CInt;
const Index = firefly.utils.Index;
const String = firefly.utils.String;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// contact init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    BasicContactTypes.UNDEFINED = ContactTypeAspectGroup.getAspect("UNDEFINED");
    BasicContactMaterials.UNDEFINED = ContactMaterialAspectGroup.getAspect("UNDEFINED");
    Contact.init();
    Component.registerComponent(ContactConstraint);
    EComponent.registerEntityComponent(EContact);
    EComponent.registerEntityComponent(EContactScan);
    System(ContactSystem).createSystem(
        firefly.Engine.CoreSystems.ContactSystem.name,
        "Processes contact scans for all moved entities per frame",
        false,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    System(ContactSystem).disposeSystem();
    Contact.deinit();
}

//////////////////////////////////////////////////////////////
//// contact API
//////////////////////////////////////////////////////////////

// Contact Type Aspects
pub const ContactTypeAspectGroup = AspectGroup(struct {
    pub const name = "ContactType";
});
pub const ContactTypeAspect = *const ContactTypeAspectGroup.Aspect;
pub const ContactTypeKind = ContactTypeAspectGroup.Kind;
pub const BasicContactTypes = struct {
    pub var UNDEFINED: ContactTypeAspect = undefined;
};

// Contact Material Aspects
pub const ContactMaterialAspectGroup = AspectGroup(struct {
    pub const name = "ContactMaterial";
});
pub const ContactMaterialAspect = *const ContactMaterialAspectGroup.Aspect;
pub const ContactMaterialKind = ContactMaterialAspectGroup.Kind;
pub const BasicContactMaterials = struct {
    pub var UNDEFINED: ContactMaterialAspect = undefined;
};

pub const ContactBounds = struct {
    rect: RectF,
    circle: ?CircleF = null,

    pub fn intersects(self: *ContactBounds, offset: Vector2i, other: *ContactBounds, other_offset: Vector2i) bool {
        return intersectContactBounds(self, other, offset, other_offset);
    }

    pub fn clear(self: *ContactBounds) void {
        self.rect[0] = 0;
        self.rect[1] = 0;
        self.rect[2] = 0;
        self.rect[3] = 0;
        self.circle = null;
    }

    pub fn format(
        self: ContactBounds,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("[ rect: {any}, circle: {?any} ]", self);
    }
};

fn intersectContactBounds(
    bounds_1: *ContactBounds,
    bounds_2: *ContactBounds,
    offset_1: Vector2f,
    offset_2: Vector2f,
) bool {
    const offset = Vector2f{
        offset_1[0] - offset_2[0],
        offset_1[1] - offset_2[1],
    };
    if (bounds_1.circle) |circle1| {
        if (bounds_2.circle) |circle2| {
            return firefly.utils.intersectsCFOffset(circle1, circle2, offset);
        } else {
            return firefly.utils.intersectsCRFOffset(circle1, bounds_2.rect, offset);
        }
    } else {
        if (bounds_2.circle) |circle2| {
            return firefly.utils.intersectsCRFOffset(circle2, bounds_1.rect, offset);
        } else {
            return firefly.utils.intersectsRectFOffset(bounds_1.rect, bounds_2.rect, offset);
        }
    }
}

pub const Contact = struct {
    var initialized = false;
    var pool: DynArray(Contact) = undefined;
    var size: usize = 0;
    const grow: usize = 100;

    entity_id: Index = UNDEF_INDEX,
    type: ?ContactTypeAspect = null,
    material: ?ContactMaterialAspect = null,
    mask: BitMask,

    pub fn clear(self: *Contact) void {
        if (!Contact.initialized)
            return;

        self.entity_id = UNDEF_INDEX;
        self.type = null;
        self.material = null;
        self.mask.clear();
    }

    pub fn destruct(self: *Contact) void {
        if (!Contact.initialized)
            return;

        self.entity_id = UNDEF_INDEX;
        self.type = null;
        self.material = null;
        self.mask.clear();
        self.mask.deinit();
        self.mask = undefined;
    }

    fn init() void {
        defer Contact.initialized = true;
        if (Contact.initialized)
            return;

        pool = DynArray(Contact).new(firefly.api.COMPONENT_ALLOC);
    }

    fn deinit() void {
        defer Contact.initialized = false;
        if (!Contact.initialized)
            return;

        for (0..size) |i| {
            pool.register.get(i).destruct();
        }

        pool.clear();
        pool.deinit();
        pool = undefined;
        size = 0;
    }

    pub fn getEmpty() Index {
        const next = pool.slots.nextClearBit(0);
        if (next >= size)
            expand();

        // mark as in use
        pool.slots.set(next);
        return next;
    }

    pub fn get(index: Index) ?*Contact {
        if (index > size)
            return null;

        return pool.get(index);
    }

    pub fn dispose(index: Index) void {
        if (!Contact.initialized)
            return;

        if (pool.get(index)) |c| {
            c.clear();
            // mark as unused
            pool.slots.setValue(index, false);
        }
    }

    fn expand() void {
        if (!Contact.initialized)
            return;

        for (size..size + grow) |i| {
            _ = pool.set(
                .{
                    .mask = BitMask.new(firefly.api.COMPONENT_ALLOC, 0, 0),
                },
                i,
            );
            // mark as unused
            pool.slots.setValue(i, false);
        }
        size = size + grow;
    }

    pub fn format(
        self: Contact,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Contact[ entity_id:{d} type:{?any}, material:{?any}]\n{any}", self);
    }
};

//////////////////////////////////////////////////////////////
//// Contact Constraint Component
//////////////////////////////////////////////////////////////

pub const ContactConstraint = struct {
    pub usingnamespace Component.Trait(ContactConstraint, .{ .name = "ContactConstraint" });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    // The contact bounds of this contact scan relative to the entity origin (ETransform origin)
    bounds: ContactBounds,
    /// Indicates a specific layer id on which this ContactConstraint work.
    /// If this is null, it means the same layer as the root entity is located on
    layer_id: ?Index = null,
    /// Contact type restriction filter. If null all contact types match
    type_filter: ?ContactTypeKind = null,
    /// Material type restriction filter. If null all materials match
    material_filter: ?ContactMaterialKind = null,
    /// Indicates if the engine shall make and store a full scan
    /// with individual Contacts data for each detected contact
    full_scan: bool = false,
    /// The concrete contact scan result that will be updated on every loop cycle related to this constraint
    scan: ContactScan = undefined,

    pub fn format(
        self: ContactConstraint,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("ContactConstraint({d}|{?s})[ bounds: {any} layer: {?d} type_filter: {?any} material_filter: {?any} full: {any} ]\n {any}", self);
    }

    pub fn construct(self: *ContactConstraint) void {
        if (self.full_scan) {
            self.scan = ContactScan.newFull(self.bounds);
        } else {
            self.scan = ContactScan.newSimple(self.bounds);
        }
    }

    pub fn destruct(self: *ContactConstraint) void {
        self.type_filter = null;
        self.scan.destruct();
    }

    pub fn match(self: *ContactConstraint, c_type: ?ContactTypeAspect, c_material: ?ContactMaterialAspect) bool {
        if (c_type) |t| {
            if (self.type_filter) |tf|
                if (!tf.hasAspect(t)) return false;
        }
        if (c_material) |m| {
            if (self.material_filter) |mf|
                if (!mf.hasAspect(m)) return false;
        }

        return true;
    }

    pub fn scanEntity(
        self: *ContactConstraint,
        self_entity: Index,
        other_entity: Index,
        other_offset: ?Vector2f,
    ) bool {
        if (EContact.byId(other_entity)) |e_contact| {
            if (!self.match(e_contact.c_type, e_contact.c_material))
                return false;

            const t1 = ETransform.byId(self_entity).?;
            const t2 = ETransform.byId(other_entity).?;
            const t2_pos = if (other_offset) |off| t2.position + off else t2.position;

            if (intersectContactBounds(&self.scan.bounds, &e_contact.bounds, t1.position, t2_pos)) {

                // now we have an intersection if this is simple scan just add the entity id to the scan result
                self.scan.entities.add(other_entity);
                if (self.full_scan) {
                    // as we need a full scan we need to create the Contact stamp and add it to the scan
                    // create contact and make a BitMask stamp relative to the scanned entity
                    const contact_id = Contact.getEmpty();
                    var contact = Contact.get(contact_id).?;
                    contact.mask.reset(
                        firefly.utils.f32_usize(self.bounds.rect[2]),
                        firefly.utils.f32_usize(self.bounds.rect[3]),
                    );
                    // offset for contact mask relative to others world position
                    const offset: Vector2f = .{
                        t2_pos[0] + e_contact.bounds.rect[0] - (t1.position[0] + self.scan.bounds.rect[0]),
                        t2_pos[1] + e_contact.bounds.rect[1] - (t1.position[1] + self.scan.bounds.rect[1]),
                    };

                    contact.entity_id = other_entity;
                    contact.type = e_contact.c_type;
                    contact.material = e_contact.c_material;
                    // stamp, either with the other entities mask or bound rect or circle
                    // if other has a bit-mask we need to apply the bit-mask, otherwise the bounded region
                    if (e_contact.mask) |other_mask| {
                        contact.mask.setIntersectionF(other_mask, offset, firefly.utils.bitOpOR);
                    } else {
                        if (e_contact.bounds.circle) |circle| {
                            contact.mask.setCircleF(circle, true);
                        } else {
                            contact.mask.setRectFOffset(e_contact.bounds.rect, offset, true);
                        }
                    }

                    // then add the contact to the scan. The scan shall then create an or stamp with the overall map
                    self.scan.addContact(contact_id);
                }
                return true;
            }
        }
        return false;
    }
};

pub const ContactScan = struct {
    // The contact bounds of this contact scan relative to the entity origin (ETransform origin)
    bounds: ContactBounds,
    // List of entity ids that has a contact with this contact scan
    entities: DynIndexArray,
    // Collection of contact type aspects to filter on (null = any type)
    types: ContactTypeKind,
    // Collection of material aspects to filter on (null = any material)
    materials: ContactMaterialKind,
    // List of Contact ids has a contact with this contact scan (only available on full contact scan)
    contacts: ?DynIndexArray = null,
    // The overall accumulated contact mask of all contacts of this scan (only available on full contact scan)
    // The mask has the same dimension like bounds but has the origin (0, 0)
    mask: ?BitMask = null,

    pub fn format(
        self: ContactScan,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("ContactScan[ bounds: {any} entities: {any} types: {any} materials: {any} contacts: {?any}]\n {?any}", self);
    }

    fn newSimple(bounds: ContactBounds) ContactScan {
        return .{
            .bounds = bounds,
            .types = ContactTypeAspectGroup.newKind(),
            .materials = ContactMaterialAspectGroup.newKind(),
            .entities = DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 10),
        };
    }

    fn newFull(bounds: ContactBounds) ContactScan {
        return .{
            .bounds = bounds,
            .types = ContactTypeAspectGroup.newKind(),
            .materials = ContactMaterialAspectGroup.newKind(),
            .entities = DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 10),
            .contacts = DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 10),
            .mask = BitMask.new(
                firefly.api.COMPONENT_ALLOC,
                @intFromFloat(bounds.rect[2]),
                @intFromFloat(bounds.rect[3]),
            ),
        };
    }

    pub fn clear(self: *ContactScan) void {
        self.entities.clear();
        self.types.clear();
        self.materials.clear();
        if (self.contacts) |*c| {
            for (c.items) |index|
                Contact.dispose(index);
            c.clear();
        }
        if (self.mask) |*m|
            m.clear();
    }

    fn destruct(self: *ContactScan) void {
        self.entities.deinit();
        self.entities = undefined;
        if (self.contacts) |*c| {
            for (c.items) |index|
                Contact.dispose(index);
            c.deinit();
        }
        self.contacts = null;
        if (self.mask) |*m|
            m.deinit();
        self.mask = null;
    }

    pub fn hasAnyContact(self: *ContactScan) bool {
        return self.entities.size_pointer > 0;
    }

    pub fn hasContactOfType(self: *ContactScan, c_type: ContactTypeAspect) bool {
        return self.types.hasAspect(c_type);
    }

    pub fn hasContactOfMaterial(self: *ContactScan, c_material: ContactMaterialAspect) bool {
        return self.materials.hasAspect(c_material);
    }

    pub fn firstContactOfType(self: *ContactScan, c_type: ContactTypeAspect) ?*Contact {
        if (self.contacts) |contacts| {
            for (contacts.items) |index| {
                if (Contact.get(index)) |c| {
                    if (c.type) |t| {
                        if (t.id == c_type.id)
                            return c;
                    }
                }
            }
        }
        return null;
    }

    pub fn firstContactOfMaterial(self: *ContactScan, c_material: ContactMaterialAspect) ?*Contact {
        if (self.contacts) |contacts| {
            for (contacts.items) |index| {
                if (Contact.get(index)) |c| {
                    if (c.material) |m| {
                        if (m.id == c_material.id)
                            return c;
                    }
                }
            }
        }
        return null;
    }

    pub fn hasContactAt(self: *ContactScan, x: CInt, y: CInt) bool {
        if (self.mask) |m|
            return m.isSet(x, y);

        return if (self.bounds.circle) |*c|
            firefly.utils.containsCircI(c, x, y)
        else
            firefly.utils.containsRectI(self.bounds.rect, x, y);
    }

    fn addContact(self: *ContactScan, contact_id: Index) void {
        if (Contact.get(contact_id)) |contact| {
            self.mask.?.setIntersection(contact.mask, null, firefly.utils.bitOpOR);
            self.contacts.?.add(contact_id);
        }
    }
};

//////////////////////////////////////////////////////////////
//// Collision Resolving
//////////////////////////////////////////////////////////////

pub const CollisionResolver = *const fn (Index) void;
pub const DebugCollisionResolver: CollisionResolver = debugCollisionResolver;

fn debugCollisionResolver(entity_id: Index) void {
    const entity = Entity.byId(entity_id);
    const transform = ETransform.byId(entity_id).?;
    const scans = EContactScan.byId(entity_id).?;

    std.debug.print("******************************************\n", .{});
    std.debug.print("Resolve collision on entity: {any}\n\n", .{entity});
    std.debug.print("Transform: {any}\n\n", .{transform});
    var next = scans.constraints.nextSetBit(0);
    while (next) |i| {
        const constraint = ContactConstraint.byId(i);
        std.debug.print("Contact Constraint: \n{any}\n\n", .{constraint});
        next = scans.constraints.nextSetBit(i + 1);
    }
    std.debug.print("******************************************\n", .{});
}

//////////////////////////////////////////////////////////////
//// EContact and EContactScan Entity Component
//////////////////////////////////////////////////////////////

pub const EContact = struct {
    pub usingnamespace EComponent.Trait(EContact, "EContact");

    id: Index = UNDEF_INDEX,

    bounds: ContactBounds,
    c_type: ?ContactTypeAspect = null,
    c_material: ?ContactMaterialAspect = null,
    mask: ?BitMask = null,
};

pub const EContactScan = struct {
    pub usingnamespace EComponent.Trait(EContactScan, "EContactScan");

    id: Index = UNDEF_INDEX,

    collision_resolver: ?CollisionResolver = null,
    constraints: BitSet = undefined,

    pub fn construct(self: *EContactScan) void {
        self.constraints = BitSet.new(firefly.api.ENTITY_ALLOC);
    }

    pub fn destruct(self: *EContactScan) void {
        self.constraints.deinit();
    }

    pub fn withConstraint(self: *EContactScan, constraint: ContactConstraint) *EContactScan {
        self.constraints.set(ContactConstraint.new(constraint).id);
        return self;
    }

    pub fn hasAnyContact(self: *EContactScan) bool {
        var next = self.constraints.nextSetBit(0);
        while (next) |i| {
            if (ContactConstraint.byId(i).scan.hasAnyContact())
                return true;
            next = self.constraints.nextSetBit(i + 1);
        }
        return false;
    }
};

//////////////////////////////////////////////////////////////
//// ContactMap
//////////////////////////////////////////////////////////////

pub const IContactMap = struct {
    view_id: ?Index = null,
    layer_id: ?Index = null,

    entityRegistration: *const fn (Index, register: bool) void = undefined,
    update: *const fn () void = undefined,
    getPotentialContactIds: *const fn (region: RectF) ?[]Index = undefined,
    deinit: *const fn () void = undefined,

    fn init(initImpl: *const fn (*IContactMap) void) IContactMap {
        var self = IContactMap{};
        _ = initImpl(&self);
        return self;
    }
};

pub inline fn addDummyContactMap(view_id: ?Index, layer_id: ?Index) void {
    const contact_map = IContactMap.init(DummyContactMap(view_id, layer_id).initImpl);
    _ = ContactSystem.contact_maps.add(contact_map);
}

pub fn DummyContactMap(view_id: ?Index, layer_id: ?Index) type {
    return struct {
        const Self = @This();
        var initialized = false;

        var entity_ids: DynIndexArray = undefined;

        fn initImpl(interface: *IContactMap) void {
            defer Self.initialized = true;
            if (Self.initialized)
                return;

            entity_ids = DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 50);

            interface.view_id = view_id;
            interface.layer_id = layer_id;
            interface.deinit = Self.deinit;
            interface.entityRegistration = Self.entityRegistration;
            interface.update = Self.update;
            interface.getPotentialContactIds = Self.getPotentialContactIds;
        }

        fn deinit() void {
            entity_ids.deinit();
        }

        fn entityRegistration(entity_id: Index, register: bool) void {
            if (register) entity_ids.add(entity_id) else entity_ids.removeFirst(entity_id);
        }

        fn update() void {
            // does nothing since DummyContactMap is just an ordinary list
        }

        fn getPotentialContactIds(_: RectF) ?[]Index {
            return entity_ids.items;
        }
    };
}

//////////////////////////////////////////////////////////////
//// Contact System
//////////////////////////////////////////////////////////////

const ContactSystem = struct {
    pub var entity_condition: EntityCondition = undefined;

    var contact_maps: DynArray(IContactMap) = undefined;

    pub fn systemInit() void {
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{EContact}),
            .dismiss_kind = EComponentAspectGroup.newKindOf(.{ETile}),
        };
        contact_maps = DynArray(IContactMap).newWithRegisterSize(firefly.api.COMPONENT_ALLOC, 5);
        firefly.physics.subscribe(processMoved);
    }

    pub fn systemDeinit() void {
        firefly.physics.unsubscribe(processMoved);
        entity_condition = undefined;
        var next = contact_maps.slots.nextSetBit(0);
        while (next) |i| {
            if (contact_maps.get(i)) |map|
                map.deinit();
            next = contact_maps.slots.nextSetBit(i + 1);
        }
        contact_maps.deinit();
        contact_maps = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        var next = contact_maps.slots.nextSetBit(0);
        while (next) |i| {
            if (contact_maps.get(i)) |map|
                map.entityRegistration(id, register);
            next = contact_maps.slots.nextSetBit(i + 1);
        }
    }

    fn processMoved(event: MovementEvent) void {
        var next = event.moved.nextSetBit(0);
        while (next) |i| {
            if (EContactScan.byId(i)) |e_scan|
                applyScan(e_scan);
            next = event.moved.nextSetBit(i + 1);
        }
    }

    fn applyScan(e_scan: *EContactScan) void {
        var view_id: ?Index = null;
        var layer_id: ?Index = null;
        if (EView.byId(e_scan.id)) |view| {
            view_id = view.view_id;
            layer_id = view.layer_id;
        }

        // apply scan for all defined constraints
        var has_any_contact = false;
        var next_constraint = e_scan.constraints.nextSetBit(0);
        while (next_constraint) |i| {
            var constraint = ContactConstraint.byId(i);
            const t1 = ETransform.byId(e_scan.id).?;
            const world_contact_bounds = RectF{
                t1.position[0] + constraint.scan.bounds.rect[0],
                t1.position[1] + constraint.scan.bounds.rect[1],
                constraint.scan.bounds.rect[2],
                constraint.scan.bounds.rect[3],
            };

            // clear old scan data
            constraint.scan.clear();
            // apply scan on registered entity mappers
            has_any_contact = has_any_contact or scanOnMappings(
                e_scan,
                constraint,
                world_contact_bounds,
                view_id,
                layer_id,
            );
            // apply scan on active tile grids
            has_any_contact = has_any_contact or scanOnTileGrids(
                e_scan,
                constraint,
                world_contact_bounds,
                view_id,
                layer_id,
            );

            next_constraint = e_scan.constraints.nextSetBit(i + 1);
        }

        if (has_any_contact) {
            if (e_scan.collision_resolver) |resolver|
                resolver(e_scan.id);
        }
    }

    fn scanOnMappings(
        e_scan: *EContactScan,
        constraint: *ContactConstraint,
        world_contact_bounds: RectF,
        view_id: ?Index,
        layer_id: ?Index,
    ) bool {
        var has_any_contact = false;
        var next = contact_maps.slots.nextSetBit(0);
        while (next) |i| {
            if (contact_maps.get(i)) |map| {
                if (ViewLayerMapping.match(map.view_id, view_id, map.layer_id, layer_id)) {
                    if (map.getPotentialContactIds(world_contact_bounds)) |entity_ids| {
                        for (entity_ids) |entity_id|
                            has_any_contact = has_any_contact or constraint.scanEntity(
                                e_scan.id,
                                entity_id,
                                null,
                            );
                    }
                }
            }
            next = contact_maps.slots.nextSetBit(i + 1);
        }

        return has_any_contact;
    }

    fn scanOnTileGrids(
        e_scan: *EContactScan,
        constraint: *ContactConstraint,
        world_contact_bounds: RectF,
        view_id: ?Index,
        layer_id: ?Index,
    ) bool {
        var has_any_contact = false;
        var next = TileGrid.nextActiveId(0);
        while (next) |i| {
            const tile_grid = TileGrid.byId(i);
            if (ViewLayerMapping.match(tile_grid.view_id, view_id, tile_grid.layer_id, layer_id)) {
                if (tile_grid.getIteratorWorldClipF(world_contact_bounds)) |iterator| {
                    var it = iterator;
                    while (it.next()) |entity_id| {
                        has_any_contact = has_any_contact or constraint.scanEntity(
                            e_scan.id,
                            entity_id,
                            it.rel_position + tile_grid.world_position,
                        );
                    }
                }
            }

            next = TileGrid.nextActiveId(i + 1);
        }

        return has_any_contact;
    }
};
