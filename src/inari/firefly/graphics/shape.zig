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

    api.EComponent.registerEntityComponent(EShape);
    // init renderer
    api.System(DefaultShapeRenderer).createSystem(
        firefly.Engine.DefaultRenderer.SHAPE,
        "Default renderer for shape based entities",
        true,
    );
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
    pub usingnamespace api.EComponent.Trait(@This(), "EShape");

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

const DefaultShapeRenderer = struct {
    pub var entity_condition: api.EntityTypeCondition = undefined;
    var shape_refs: graphics.ViewLayerMapping = undefined;

    pub fn systemInit() void {
        shape_refs = graphics.ViewLayerMapping.new();
        entity_condition = api.EntityTypeCondition{
            .accept_kind = api.EComponentAspectGroup.newKindOf(.{ graphics.ETransform, EShape }),
        };
    }

    pub fn systemDeinit() void {
        entity_condition = undefined;
        shape_refs.deinit();
        shape_refs = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (register)
            shape_refs.addWithEView(graphics.EView.byId(id), id)
        else
            shape_refs.removeWithEView(graphics.EView.byId(id), id);
    }

    pub fn renderView(e: graphics.ViewRenderEvent) void {
        if (shape_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the shape
                const es = EShape.byId(id).?;
                const trans = graphics.ETransform.byId(id).?;
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

                i = all.nextSetBit(id + 1);
            }
        }
    }
};
