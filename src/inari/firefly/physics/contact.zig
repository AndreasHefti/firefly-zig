const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const firefly = inari.firefly;
const api = firefly.api;

const AspectGroup = utils.AspectGroup;

const BitMask = utils.BitMask;
const CircleI = utils.CircleI;
const RectI = utils.RectI;
const CInt = utils.CInt;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;

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
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// audio API
//////////////////////////////////////////////////////////////

// Contact Type Aspects
pub const ContactTypeAspectGroup = AspectGroup(struct {
    pub const name = "ContactType";
});
pub const ContactTypeAspect = *const ContactTypeAspectGroup.Aspect;
pub const ContactTypeKind = ContactTypeAspectGroup.Kind;
pub const BasicContactTypes = struct {
    var UNDEFINED: ContactTypeAspect = undefined;
};

// Contact Material Aspects
pub const ContactMaterialAspectGroup = AspectGroup(struct {
    pub const name = "ContactMaterial";
});
pub const ContactMaterialAspect = *const ContactMaterialAspectGroup.Aspect;
pub const ContactMaterialKind = ContactMaterialAspectGroup.Kind;
pub const BasicContactMaterials = struct {
    var UNDEFINED: ContactMaterialAspect = undefined;
};

pub const Contact = struct {
    entity_id: Index = UNDEF_INDEX,
    world_circle: ?CircleI = null,
    world_bounds: ?RectI = null,
    intersection_bounds: RectI = RectI{ 0, 0, 0, 0 },
    intersection_mask: BitMask = undefined,
    contact_type: ContactTypeAspect = undefined,
    material_type: ContactMaterialAspect = undefined,

    pub fn intersects(self: *Contact, x: usize, y: usize) bool {
        return utils.containsRectI(self.intersection_bounds, x, y);
    }

    pub fn hasContact(self: *Contact, x: usize, y: usize) bool {
        if (utils.containsRectI(self.intersection_bounds, x, y)) {
            if (!self.intersection_mask.isEmpty()) {
                return self.intersection_mask.isSet(x - self.intersection_mask[0], y - self.intersection_mask[1]);
            }
            return true;
        }
        return false;
    }
};
