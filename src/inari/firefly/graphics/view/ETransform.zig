const std = @import("std");
const Allocator = std.mem.Allocator;

const graphics = @import("../graphics.zig");
const api = graphics.api;

const Entity = api.Entity;
const View = graphics.View;
const Layer = graphics.Layer;
const TransformData = api.TransformData;
const Aspect = api.utils.aspect.Aspect;
const String = api.utils.String;
const Vec2f = api.utils.geom.Vector2f;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;
const ETransform = @This();

// component type fields
pub const NULL_VALUE = ETransform{};
pub const COMPONENT_NAME = "ETransform";
pub const pool = Entity.EntityComponentPool(ETransform);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var get: *const fn (Index) *ETransform = undefined;
pub var byId: *const fn (Index) *const ETransform = undefined;

id: Index = UNDEF_INDEX,
transform: TransformData = TransformData{},
view_id: Index = UNDEF_INDEX,
layer_id: Index = UNDEF_INDEX,

pub fn setViewByName(self: *ETransform, view_name: String) void {
    self.view_id = View.byName(view_name).id;
}

pub fn setLayerByName(self: *ETransform, layer_name: String) void {
    self.layer_id = Layer.byName(layer_name).id;
}
