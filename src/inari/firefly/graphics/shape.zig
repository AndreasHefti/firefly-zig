const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const graphics = inari.firefly.graphics;

const System = api.System;
const EComponent = api.EComponent;
const EntityCondition = api.EntityCondition;
const EComponentAspectGroup = api.EComponentAspectGroup;
const ComponentEvent = api.ComponentEvent;
const ActionType = api.Component.ActionType;
const EMultiplier = api.EMultiplier;
const EView = graphics.EView;
const ViewRenderEvent = graphics.ViewRenderEvent;
const ViewLayerMapping = graphics.ViewLayerMapping;
const ETransform = graphics.ETransform;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const Float = utils.Float;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const ShapeType = api.ShapeType;

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
        graphics.DefaultRenderer.SHAPE,
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
        api.ALLOC.free(self.vertices);
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
                var es = EShape.byId(id).?;
                var trans = ETransform.byId(id).?;
                var multi = if (EMultiplier.byId(id)) |m| m.positions else null;
                api.rendering.renderShape(
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
                    multi,
                );

                i = all.nextSetBit(id + 1);
            }
        }
    }
};
