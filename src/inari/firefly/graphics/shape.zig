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
const ViewRenderEvent = graphics.ViewRenderEvent;
const ViewLayerMapping = graphics.ViewLayerMapping;
const ETransform = graphics.ETransform;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const Float = utils.Float;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const ShapeType = api.ShapeType;
const PosF = utils.PosF;
const Vector2f = utils.Vector2f;

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
        "DefaultShapeRenderer",
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
    pub const view_render_order: usize = 1;
    var entity_condition: EntityCondition = undefined;
    var sprite_refs: ViewLayerMapping = undefined;

    pub fn systemInit() void {
        sprite_refs = ViewLayerMapping.new();
        entity_condition = EntityCondition{
            .accept_kind = EComponentAspectGroup.newKindOf(.{ ETransform, EShape }),
        };
    }

    pub fn systemDeinit() void {
        entity_condition = undefined;
        sprite_refs.deinit();
        sprite_refs = undefined;
    }

    pub fn notifyEntityChange(e: ComponentEvent) void {
        if (e.c_id == null or !entity_condition.check(e.c_id.?))
            return;

        var transform = ETransform.byId(e.c_id.?).?;
        switch (e.event_type) {
            ActionType.ACTIVATED => sprite_refs.add(transform.view_id, transform.layer_id, e.c_id.?),
            ActionType.DEACTIVATING => sprite_refs.remove(transform.view_id, transform.layer_id, e.c_id.?),
            else => {},
        }
    }

    pub fn renderView(e: ViewRenderEvent) void {
        if (sprite_refs.get(e.view_id, e.layer_id)) |all| {
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
