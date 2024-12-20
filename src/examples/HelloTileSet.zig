const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const EView = firefly.graphics.EView;
const ESprite = firefly.graphics.ESprite;
const Allocator = std.mem.Allocator;
const ETile = firefly.graphics.ETile;
const SpriteData = firefly.game.SpriteData;
const TileSet = firefly.game.TileSet;
const BlendMode = firefly.api.BlendMode;
const PosF = utils.PosF;
const CInt = utils.CInt;
const Float = utils.Float;
const String = utils.String;
const TileTemplate = firefly.game.TileTemplate;
const TileMapping = firefly.game.TileMapping;
const View = firefly.graphics.View;
const Index = firefly.utils.Index;
const EShape = firefly.graphics.EShape;
const TileAnimationFrame = firefly.game.TileAnimationFrame;
const IndexFrameList = firefly.physics.IndexFrameList;
const IndexFrameIntegrator = firefly.physics.IndexFrameIntegrator;

const JSON_TILE_SET: String =
    \\  {
    \\      "type": "TileSet",
    \\      "name": "TestTileSet",
    \\      "texture": {
    \\          "name": "Atlas",
    \\          "file": "resources/atlas1616.png"
    \\      },
    \\      "tile_width": 16,
    \\      "tile_height": 16,
    \\      "tiles": [
    \\          { "name": "full", "props": "0,0|0|0|TERRAIN|0|-" },
    \\          { "name": "slope_1_1", "props": "1,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_1_2", "props": "1,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_1_3", "props": "1,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_1_4", "props": "1,0|0|1|TERRAIN|1|-" },
    \\          { "name": "slope_2_1", "props": "2,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_2_2", "props": "2,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_2_3", "props": "2,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_2_4", "props": "2,0|0|1|TERRAIN|1|-" },
    \\          { "name": "slope_3_1", "props": "3,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_3_2", "props": "3,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_3_3", "props": "3,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_3_4", "props": "3,0|0|1|TERRAIN|1|-" },
    \\          { "name": "slope_4_1", "props": "4,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_4_2", "props": "4,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_4_3", "props": "4,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_4_4", "props": "4,0|0|1|TERRAIN|1|-" },
    \\          { "name": "slope_5_1", "props": "5,0|0|0|TERRAIN|1|-" },
    \\          { "name": "slope_5_2", "props": "5,0|1|0|TERRAIN|1|-" },
    \\          { "name": "slope_5_3", "props": "5,0|1|1|TERRAIN|1|-" },
    \\          { "name": "slope_5_4", "props": "5,0|0|1|TERRAIN|1|-" },
    \\          { "name": "rect_half_1", "props": "6,0|0|0|TERRAIN|1|-" },
    \\          { "name": "rect_half_2", "props": "6,0|0|1|TERRAIN|1|-" },
    \\          { "name": "rect_half_3", "props": "7,0|0|0|TERRAIN|1|-" },
    \\          { "name": "rect_half_4", "props": "7,0|1|0|TERRAIN|1|-" },
    \\
    \\          { "name": "circle", "props": "0,1|0|0|TERRAIN|1|-" },
    \\          { "name": "route", "props": "1,1|0|0|TERRAIN|1|-" },
    \\
    \\          { "name": "spike_up", "props": "2,1|0|0|TERRAIN|1|-" },
    \\          { "name": "spike_down", "props": "2,1|0|1|TERRAIN|1|-" },
    \\          { "name": "spike_right", "props": "3,1|0|0|TERRAIN|1|-" },
    \\          { "name": "spike_left", "props": "3,1|1|0|TERRAIN|1|-" },
    \\
    \\          { "name": "spiky_up", "props": "4,1|0|0|TERRAIN|1|-" },
    \\          { "name": "spiky_down", "props": "4,1|0|1|TERRAIN|1|-" },
    \\          { "name": "spiky_right", "props": "5,1|0|0|TERRAIN|1|-" },
    \\          { "name": "spiky_left", "props": "5,1|1|0|TERRAIN|1|-" },
    \\
    \\          { "name": "rect_mini_1", "props": "6,1|0|0|TERRAIN|1|-" },
    \\          { "name": "rect_mini_2", "props": "6,1|1|0|TERRAIN|1|-" },
    \\          { "name": "rect_mini_3", "props": "6,1|1|1|TERRAIN|1|-" },
    \\          { "name": "rect_mini_4", "props": "6,1|0|1|TERRAIN|1|-" },
    \\
    \\          { "name": "tileTemplate", "props": "1,0|0|0|-|0|-", "animation": "1000,1,0,0,0|1000,1,0,1,0|1000,1,0,1,1|1000,1,0,0,1" }
    \\      ]
    \\  }
;

/// This loads a tile set from given JSON data and makes an Entity for each defined
/// tile in the set with contact and animation if defined and draws all to the screen.
/// If there is a contact mask, the mask is displayed together with the tile in red shape.
pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Tile Set", init);
}

fn init() void {

    // we need to initialize the JSON integration tasks fist
    firefly.game.initJSONIntegration();

    const viewId = View.Component.newActive(.{
        .name = "TestView",
        .position = .{ 0, 0 },
        .projection = .{
            .width = 600,
            .height = 400,
        },
    });

    firefly.api.Task.runTaskByNameWith(
        firefly.game.Tasks.JSON_LOAD_TILE_SET,
        firefly.api.CallContext.new(
            null,
            .{
                .{ firefly.game.TaskAttributes.JSON_RESOURCE, JSON_TILE_SET },
            },
        ),
    );
    var tile_set: *TileSet = TileSet.Naming.byName("TestTileSet").?;
    TileSet.Activation.activate(tile_set.id);

    var next = tile_set.tile_templates.slots.nextSetBit(0);
    var x: usize = 50;
    var y: usize = 50;
    while (next) |i| {
        if (tile_set.tile_templates.get(i)) |tile_template| {
            createTile(
                tile_set,
                tile_template,
                firefly.utils.usize_f32(x),
                firefly.utils.usize_f32(y),
                viewId,
            );
            x += 50;
            if (x > 500) {
                x = 50;
                y += 50;
            }
        }
        next = tile_set.tile_templates.slots.nextSetBit(i + 1);
    }
}

pub fn createTile(
    tile_set: *TileSet,
    tile_template: *TileTemplate,
    x: Float,
    y: Float,
    view_id: Index,
) void {
    const eid = Entity.new(.{ .name = tile_template.name }, .{
        ETransform{ .position = .{ x, y } },
        EView{ .view_id = view_id },
        ESprite{ .template_id = tile_template._sprite_template_id.? },
    });

    if (tile_set.createContactMaskFromImage(tile_template)) |mask| {
        var vert: std.ArrayList(Float) = std.ArrayList(Float).init(firefly.api.POOL_ALLOC);

        for (0..mask.height) |_y| {
            for (0..mask.width) |_x| {
                if (mask.isBitSetAt(_x, _y)) {
                    vert.append(firefly.utils.usize_f32(_x + 16)) catch |err| firefly.api.handleUnknownError(err);
                    vert.append(firefly.utils.usize_f32(_y + 16)) catch |err| firefly.api.handleUnknownError(err);
                }
            }
        }

        EShape.Component.new(eid, .{
            .shape_type = firefly.api.ShapeType.POINT,
            .vertices = vert.items,
            .color = .{ 255, 0, 0, 255 },
        });
    } else if (tile_template.contact_material_type) |_| {
        EShape.Component.new(eid, .{
            .shape_type = firefly.api.ShapeType.RECTANGLE,
            .vertices = firefly.api.allocFloatArray(.{ 16, 16, 16, 16 }),
            .color = .{ 255, 0, 0, 255 },
        });
    }

    if (tile_template.animation) |*frames| {
        var list = IndexFrameList.new();
        var next = frames.slots.nextSetBit(0);
        while (next) |i| {
            if (frames.get(i)) |frame|
                _ = list.withFrame(frame._sprite_template_id.?, frame.duration);
            next = frames.slots.nextSetBit(i + 1);
        }

        firefly.physics.EAnimations.add(
            eid,
            .{ .duration = list._duration, .looping = true, .active_on_init = true },
            IndexFrameIntegrator{
                .timeline = list,
                .property_ref = ESprite.Property.FrameId,
            },
        );
    }

    Entity.Activation.activate(eid);
}
