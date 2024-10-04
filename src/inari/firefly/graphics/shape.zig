const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const graphics = firefly.graphics;

const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const Float = firefly.utils.Float;
const Color = firefly.utils.Color;
const BlendMode = firefly.api.BlendMode;
const ShapeType = firefly.api.ShapeType;

//////////////////////////////////////////////////////////////
//// shape init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    api.Entity.registerComponent(EShape, "EShape");
    api.System.register(DefaultShapeRenderer);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// EShape Shape Entity Component
//////////////////////////////////////////////////////////////

pub const EShape = struct {
    pub const Component = api.EntityComponentMixin(EShape);

    id: Index = UNDEF_INDEX,

    shape_type: ShapeType,
    // TODO allocation handling is now not optimal
    vertices: []Float,
    fill: bool = true,
    thickness: ?Float = null,
    color: Color,
    blend_mode: ?BlendMode = null,
    color1: ?Color = null,
    color2: ?Color = null,
    color3: ?Color = null,

    pub fn destruct(self: *EShape) void {
        self.shape_type = ShapeType.POINT;
        firefly.api.ALLOC.free(self.vertices);
        self.vertices = undefined;
        self.fill = true;
        self.color = undefined;
        self.blend_mode = null;
        self.color1 = null;
        self.color2 = null;
        self.color3 = null;
    }
};

//////////////////////////////////////////////////////////////
//// Default Shape Renderer
//////////////////////////////////////////////////////////////

pub const DefaultShapeRenderer = struct {
    pub const System = api.SystemMixin(DefaultShapeRenderer);
    pub const EntityRenderer = graphics.EntityRendererMixin(DefaultShapeRenderer);

    pub const accept = .{ graphics.ETransform, EShape };

    pub fn renderEntities(entities: *firefly.utils.BitSet, _: graphics.ViewRenderEvent) void {
        var i = entities.nextSetBit(0);
        while (i) |id| {
            // render the shape
            const es = EShape.Component.byId(id);
            const trans = graphics.ETransform.Component.byId(id);
            firefly.api.rendering.renderShape(
                es.shape_type,
                es.vertices,
                es.fill,
                es.thickness,
                trans.position,
                es.color,
                es.blend_mode,
                trans.pivot,
                trans.scale,
                trans.rotation,
                es.color1,
                es.color2,
                es.color3,
            );

            i = entities.nextSetBit(id + 1);
        }
    }
};
