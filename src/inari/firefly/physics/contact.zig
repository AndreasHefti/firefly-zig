const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;

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

    Contact.init();
    api.Component.registerComponent(ContactConstraint);
    api.EComponent.registerEntityComponent(EContact);
    api.EComponent.registerEntityComponent(EContactScan);
    api.System(ContactSystem).createSystem(
        firefly.Engine.CoreSystems.ContactSystem.name,
        "Processes contact scans for all moved entities per frame",
        false,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    api.System(ContactSystem).disposeSystem();
    Contact.deinit();
}

//////////////////////////////////////////////////////////////
//// contact API
//////////////////////////////////////////////////////////////

// Contact Type Aspects
pub const ContactTypeAspectGroup = utils.AspectGroup(struct {
    pub const name = "ContactType";
});
pub const ContactTypeAspect = ContactTypeAspectGroup.Aspect;
pub const ContactTypeKind = ContactTypeAspectGroup.Kind;

// Contact Material Aspects
pub const ContactMaterialAspectGroup = utils.AspectGroup(struct {
    pub const name = "ContactMaterial";
});
pub const ContactMaterialAspect = ContactMaterialAspectGroup.Aspect;
pub const ContactMaterialKind = ContactMaterialAspectGroup.Kind;

pub const ContactBounds = struct {
    rect: utils.RectF,
    circle: ?utils.CircleF = null,

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
    var pool: utils.DynArray(Contact) = undefined;
    var size: usize = 0;
    const grow: usize = 100;

    entity_id: Index = UNDEF_INDEX,
    type: ?ContactTypeAspect = null,
    material: ?ContactMaterialAspect = null,
    mask: utils.BitMask,

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

        pool = utils.DynArray(Contact).new(firefly.api.COMPONENT_ALLOC);
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
                    .mask = utils.BitMask.new(firefly.api.COMPONENT_ALLOC, 0, 0),
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
pub const ContactCallbackFunction = *const fn (entity_id: Index, contacts: *ContactScan) bool;
pub const ContactConstraint = struct {
    pub usingnamespace api.Component.Trait(ContactConstraint, .{ .name = "ContactConstraint" });

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
    // A contact callback, if defined, system calls the callback when this scan has any contact
    // right after scan is done. System will stop proceeding with the scan if callback returns false
    callback: ?ContactCallbackFunction = null,
    /// The concrete contact scan result that will be updated on every loop cycle related to this constraint
    scan: ContactScan = undefined,

    pub fn format(
        self: ContactConstraint,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("ContactConstraint({d}|{?s})[ bounds: {any} layer: {?d} type_filter: {?any} material_filter: {?any} full: {any}, callback: {any} ]\n {any}", self);
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

    pub inline fn clear(self: *ContactConstraint) void {
        self.scan.clear();
    }

    pub fn match(self: *ContactConstraint, c_type: ?ContactTypeAspect, c_material: ?ContactMaterialAspect) bool {
        if (self.type_filter) |tf| {
            if (c_type) |t|
                if (tf.hasAspect(t))
                    return true;
        }
        if (self.material_filter) |mf| {
            if (c_material) |m|
                if (mf.hasAspect(m))
                    return true;
        }

        return self.type_filter == null and self.material_filter == null and c_type == null and c_material == null;
    }

    pub fn scanEntity(
        self: *ContactConstraint,
        self_entity: Index,
        other_entity: Index,
        other_offset: ?Vector2f,
    ) bool {
        if (EContact.byId(other_entity)) |e_contact| {
            if (!self.match(e_contact.type, e_contact.material))
                return false;

            const t1 = graphics.ETransform.byId(self_entity).?;
            const t2 = graphics.ETransform.byId(other_entity).?;
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
                    contact.type = e_contact.type;
                    contact.material = e_contact.material;
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
    entities: utils.DynIndexArray,
    // Collection of contact type aspects to filter on (null = any type)
    types: ContactTypeKind,
    // Collection of material aspects to filter on (null = any material)
    materials: ContactMaterialKind,
    // List of Contact ids has a contact with this contact scan (only available on full contact scan)
    contacts: ?utils.DynIndexArray = null,
    // The overall accumulated contact mask of all contacts of this scan (only available on full contact scan)
    // The mask has the same dimension like bounds
    mask: ?utils.BitMask = null,

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
            .entities = utils.DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 3),
        };
    }

    fn newFull(bounds: ContactBounds) ContactScan {
        return .{
            .bounds = bounds,
            .types = ContactTypeAspectGroup.newKind(),
            .materials = ContactMaterialAspectGroup.newKind(),
            .entities = utils.DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 3),
            .contacts = utils.DynIndexArray.new(firefly.api.COMPONENT_ALLOC, 3),
            .mask = utils.BitMask.new(
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

pub const CollisionResolverFunction = *const fn (entity_id: Index, _instance_id: ?Index) void;
pub const CollisionResolverInit = *const fn (entity_id: Index, _instance_id: Index) void;
pub const CollisionResolver = struct {
    _resolve: CollisionResolverFunction,
    _instance_id: ?Index = null,
    _init: ?CollisionResolverInit = null,

    pub fn resolve(self: *CollisionResolver, entity_id: Index) void {
        self._resolve(entity_id, self._instance_id);
    }
};
pub const DebugCollisionResolver: CollisionResolver = .{
    ._resolve = debugCollisionResolver,
};

fn debugCollisionResolver(entity_id: Index, _: ?Index) void {
    const entity = api.Entity.byId(entity_id);
    const transform = graphics.ETransform.byId(entity_id).?;
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
    pub usingnamespace api.EComponent.Trait(EContact, "EContact");

    id: Index = UNDEF_INDEX,

    bounds: ContactBounds,
    type: ?ContactTypeAspect = null,
    material: ?ContactMaterialAspect = null,
    mask: ?utils.BitMask = null,
};

pub const EContactScan = struct {
    pub usingnamespace api.EComponent.Trait(EContactScan, "EContactScan");

    id: Index = UNDEF_INDEX,

    collision_resolver: ?CollisionResolver = null,
    constraints: utils.BitSet = undefined,

    pub fn construct(self: *EContactScan) void {
        self.constraints = utils.BitSet.new(firefly.api.ENTITY_ALLOC);
    }

    pub fn destruct(self: *EContactScan) void {
        self.collision_resolver = null;
        self.constraints.deinit();
        self.constraints = undefined;
    }

    pub fn activation(self: *EContactScan, active: bool) void {
        if (active)
            if (self.collision_resolver) |cr|
                if (cr._init) |c_init| c_init(self.id, cr._instance_id.?);
    }

    pub fn clear(self: *EContactScan) void {
        var next = self.constraints.nextSetBit(0);
        while (next) |i| {
            ContactConstraint.byId(i).clear();
            next = self.constraints.nextSetBit(i + 1);
        }
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

    pub fn firstContactOf(
        self: *EContactScan,
        c_type: ?ContactTypeAspect,
        material: ?ContactMaterialAspect,
    ) ?*ContactScan {
        var next = self.constraints.nextSetBit(0);
        while (next) |i| {
            next = self.constraints.nextSetBit(i + 1);

            const constraint = ContactConstraint.byId(i);
            if (c_type) |t| {
                if (constraint.scan.hasContactOfType(t))
                    return &constraint.scan;
            }
            if (material) |m| {
                if (constraint.scan.hasContactOfMaterial(m))
                    return &constraint.scan;
            }
            if (c_type == null and material == null and constraint.scan.hasAnyContact())
                return &constraint.scan;
        }
        return null;
    }
};

//////////////////////////////////////////////////////////////
//// ContactMap
//////////////////////////////////////////////////////////////

pub const IContactMap = struct {
    entityRegistration: *const fn (Index, register: bool) void = undefined,
    update: *const fn () void = undefined,
    getPotentialContactIds: *const fn (region: utils.RectF, view_id: ?Index, layer_id: ?Index) ?utils.BitSet = undefined,
    deinit: api.Deinit = undefined,

    fn init(initImpl: *const fn (*IContactMap) void) IContactMap {
        var self = IContactMap{};
        _ = initImpl(&self);
        return self;
    }
};

//////////////////////////////////////////////////////////////
//// Contact System
//////////////////////////////////////////////////////////////

pub const ContactSystem = struct {
    pub var entity_condition: api.EntityTypeCondition = undefined;

    var simple_mapping: utils.BitSet = undefined;
    var contact_map: ?IContactMap = null;

    pub fn systemInit() void {
        simple_mapping = utils.BitSet.new(api.ALLOC);
        entity_condition = api.EntityTypeCondition{
            .accept_kind = api.EComponentAspectGroup.newKindOf(.{EContact}),
            .dismiss_kind = api.EComponentAspectGroup.newKindOf(.{graphics.ETile}),
        };
        firefly.physics.subscribeMovement(processMoved);
    }

    pub fn systemDeinit() void {
        simple_mapping.deinit();
        simple_mapping = undefined;
        firefly.physics.unsubscribeMovement(processMoved);
        entity_condition = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (contact_map) |cm| {
            cm.entityRegistration(id, register);
        } else {
            simple_mapping.setValue(id, register);
        }
    }

    fn processMoved(event: firefly.physics.MovementEvent) void {
        var next = event.moved.nextSetBit(0);
        while (next) |i| {
            if (EContactScan.byId(i)) |e_scan|
                applyScan(e_scan);
            next = event.moved.nextSetBit(i + 1);
        }
    }

    pub fn applyScan(e_scan: *EContactScan) void {
        var view_id: ?Index = null;
        if (graphics.EView.byId(e_scan.id)) |view|
            view_id = view.view_id;

        // clear old scan data
        e_scan.clear();

        // apply scan for all defined constraints
        var has_any_contact = false;
        var next_constraint = e_scan.constraints.nextSetBit(0);
        while (next_constraint) |i| {
            const constraint = ContactConstraint.byId(i);
            const has_contact = applyScanForConstraint(e_scan.id, view_id, constraint);
            if (has_contact) {
                if (constraint.callback) |callback| {
                    if (callback(e_scan.id, &constraint.scan))
                        return;
                }
            }
            has_any_contact = has_contact or has_any_contact;
            next_constraint = e_scan.constraints.nextSetBit(i + 1);
        }

        std.debug.print("e_scan.hasAnyContact: {any} \n", .{e_scan.hasAnyContact()});

        if (has_any_contact) {
            if (e_scan.collision_resolver) |*resolver|
                resolver.resolve(e_scan.id);
        }
    }

    pub fn applyScanForConstraint(entity_id: Index, view_id: ?Index, constraint: *ContactConstraint) bool {
        var has_any_contact = false;

        constraint.clear();

        const t1 = graphics.ETransform.byId(entity_id).?;
        const world_contact_bounds = utils.RectF{
            t1.position[0] + constraint.scan.bounds.rect[0],
            t1.position[1] + constraint.scan.bounds.rect[1],
            constraint.scan.bounds.rect[2],
            constraint.scan.bounds.rect[3],
        };

        // apply scan on registered entity mappers
        has_any_contact = scanOnMappings(
            entity_id,
            constraint,
            world_contact_bounds,
            view_id,
            constraint.layer_id,
        ) or has_any_contact;
        // apply scan on active tile grids
        has_any_contact = scanOnTileGrids(
            entity_id,
            constraint,
            world_contact_bounds,
            view_id,
            constraint.layer_id,
        ) or has_any_contact;

        return has_any_contact;
    }

    fn scanOnMappings(
        scan_entity_id: Index,
        constraint: *ContactConstraint,
        world_contact_bounds: utils.RectF,
        view_id: ?Index,
        layer_id: ?Index,
    ) bool {
        var has_any_contact = false;
        const entities = if (contact_map != null)
            contact_map.?.getPotentialContactIds(
                world_contact_bounds,
                view_id,
                layer_id,
            ) orelse simple_mapping
        else
            simple_mapping;

        var next = entities.nextSetBit(0);
        while (next) |i| {
            next = entities.nextSetBit(i + 1);
            if (i == scan_entity_id) continue;
            has_any_contact = has_any_contact or constraint.scanEntity(
                scan_entity_id,
                i,
                null,
            );
        }

        return has_any_contact;
    }

    fn scanOnTileGrids(
        scan_entity_id: Index,
        constraint: *ContactConstraint,
        world_contact_bounds: utils.RectF,
        view_id: ?Index,
        layer_id: ?Index,
    ) bool {
        var has_any_contact = false;
        var next = graphics.TileGrid.nextActiveId(0);
        while (next) |i| {
            const tile_grid = graphics.TileGrid.byId(i);
            if (graphics.ViewLayerMapping.match(tile_grid.view_id, view_id, tile_grid.layer_id, layer_id)) {
                var it = tile_grid.getIteratorWorldClipF(world_contact_bounds) orelse {
                    next = graphics.TileGrid.nextActiveId(i + 1);
                    continue;
                };

                while (it.next()) |entity_id| {
                    const has_contact = constraint.scanEntity(
                        scan_entity_id,
                        entity_id,
                        it.rel_position + tile_grid.world_position,
                    );
                    has_any_contact = has_any_contact or has_contact;
                }
            }

            next = graphics.TileGrid.nextActiveId(i + 1);
        }

        return has_any_contact;
    }
};
