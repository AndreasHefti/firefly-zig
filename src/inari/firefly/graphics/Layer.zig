const std = @import("std");
const Allocator = std.mem.Allocator;

const api = @import("../api/api.zig"); // TODO module
const graphics = @import("graphics.zig");
const Component = api.Component;
const Kind = api.utils.aspect.Kind;
const Aspect = api.utils.aspect.Aspect;
const String = api.utils.String;
const Vec2f = api.utils.geom.Vector2f;
const View = graphics.View;

const UNDEF_INDEX = api.utils.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;
const Layer = @This();

// component type fields
pub const NULL_VALUE = Layer{};
pub const COMPONENT_NAME = "Layer";
pub const pool = Component.ComponentPool(Layer);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Layer) *Layer = undefined;
pub var byId: *const fn (usize) *Layer = undefined;
pub var byName: *const fn (String) ?*Layer = undefined;
pub var activateById: *const fn (usize, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (usize) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields
index: usize = UNDEF_INDEX,
name: String = NO_NAME,
position: Vec2f = Vec2f{},
layer: usize = 0,
view_ref: usize,
shader_binding: api.BindingIndex = api.NO_BINDING,

pub fn setViewByName(self: *Layer, view_name: String) void {
    self.view_ref = View.byName(view_name).index;
}
