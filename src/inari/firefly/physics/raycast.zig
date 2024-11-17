const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const physics = firefly.physics;

// const Vector2i = firefly.utils.Vector2i;
// const Vector2f = firefly.utils.Vector2f;
// const CInt = firefly.utils.CInt;
// const Index = firefly.utils.Index;
// const String = firefly.utils.String;
// const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// Ray-Cast init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    // register entity components
    //api.Entity.registerComponent(ECollisionSegments, "ECollisionSegments");
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Ray-Cast API
//////////////////////////////////////////////////////////////

// pub const ECollisionSegments = struct {
//     pub const Component = api.EntityComponentMixin(ECollisionSegments);

//     id: Index = UNDEF_INDEX,

//     segments: []Vector2f = &.{},
//     edges: []Vector2f = &.{},
//     apply_from_contact: bool = true,

//     pub fn construct(self: *ECollisionSegments) void {
//         self.constraints = utils.BitSet.new(firefly.api.ENTITY_ALLOC);
//     }

//     pub fn destruct(self: *ECollisionSegments) void {
//         self.collision_resolver = null;
//         self.constraints.deinit();
//         self.constraints = undefined;
//     }
// };
