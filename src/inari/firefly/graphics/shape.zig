const std = @import("std");
const firefly = @import("../firefly.zig");

const System = firefly.api.System;
const EComponent = firefly.api.EComponent;
const EntityCondition = firefly.api.EntityCondition;
const EComponentAspectGroup = firefly.api.EComponentAspectGroup;
const ComponentEvent = firefly.api.ComponentEvent;
const EventType = firefly.api.Component.ActionType;
const EMultiplier = firefly.api.EMultiplier;
const EView = firefly.graphics.EView;
const ViewRenderEvent = firefly.graphics.ViewRenderEvent;
const ViewLayerMapping = firefly.graphics.ViewLayerMapping;
const ETransform = firefly.graphics.ETransform;
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

    EComponent.registerEntityComponent(EShape);
    // init renderer
    System(DefaultShapeRenderer).createSystem(
        firefly.Engine.DefaultRenderer.SHAPE,
        "Default renderer for shape based entities",
        true,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit renderer
    System(DefaultShapeRenderer).disposeSystem();
}

//////////////////////////////////////////////////////////////
//// EShape Shape Entity Component
//////////////////////////////////////////////////////////////

pub const EShape = struct {
    pub usingnamespace EComponent.Trait(@This(), "EShape");

    id: Index = UNDEF_INDEX,

    shape_type: ShapeType,
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
    pub var entity_condition: EntityCondition = undefined;
    var shape_refs: ViewLayerMapping = undefined;

    pub fn systemInit() void {
        shape_refs = ViewLayerMapping.new();
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{ ETransform, EShape }),
        };
    }

    pub fn systemDeinit() void {
        entity_condition = undefined;
        shape_refs.deinit();
        shape_refs = undefined;
    }

    pub fn entityRegistration(id: Index, register: bool) void {
        if (register)
            shape_refs.addWithEView(EView.byId(id), id)
        else
            shape_refs.removeWithEView(EView.byId(id), id);
    }

    pub fn renderView(e: ViewRenderEvent) void {
        if (shape_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |id| {
                // render the shape
                const es = EShape.byId(id).?;
                const trans = ETransform.byId(id).?;
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
