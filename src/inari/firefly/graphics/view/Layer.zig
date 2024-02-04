const std = @import("std");
const Allocator = std.mem.Allocator;

const api = @import("../../api/api.zig"); // TODO module
const graphics = @import("../graphics.zig");

const Component = api.Component;
const Aspect = api.utils.aspect.Aspect;
const String = api.utils.String;
const Vec2f = api.utils.geom.Vector2f;
const View = graphics.View;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;
const Layer = @This();

// component type fields
pub const NULL_VALUE = Layer{};
pub const COMPONENT_NAME = "Layer";
pub const pool = Component.ComponentPool(Layer);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (Layer) *Layer = undefined;
pub var exists: *const fn (Index) bool = undefined;
pub var existsName: *const fn (String) bool = undefined;
pub var get: *const fn (Index) *Layer = undefined;
pub var byId: *const fn (Index) *const Layer = undefined;
pub var byName: *const fn (String) *const Layer = undefined;
pub var activateById: *const fn (Index, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (Index) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields
id: Index = UNDEF_INDEX,
name: String = NO_NAME,
position: Vec2f = Vec2f{},
layer: u8 = 0,
view_id: Index,
shader_binding: api.BindingIndex = api.NO_BINDING,

pub fn setViewByName(self: *Layer, view_name: String) void {
    self.view_id = View.byName(view_name).id;
}

pub fn withShader(self: *Layer, id: Index) void {
    const shader_asset: *api.Asset = api.Asset.byId(id);
    self.shader_binding = graphics.ShaderAsset.getResource(shader_asset.resource_id).binding;
}

pub fn withShaderByName(self: *Layer, name: String) void {
    const shader_asset: *api.Asset = api.Asset.byIdName(name);
    self.shader_binding = graphics.ShaderAsset.getResource(shader_asset.resource_id).binding;
}
