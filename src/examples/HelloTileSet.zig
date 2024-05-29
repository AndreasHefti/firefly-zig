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
const TileContactMaterialType = firefly.game.TileContactMaterialType;
const TileTemplate = firefly.game.TileTemplate;
const TileMapping = firefly.game.TileMapping;
const View = firefly.graphics.View;
const Index = firefly.utils.Index;
const EShape = firefly.graphics.EShape;
const TileAnimationFrame = firefly.game.TileAnimationFrame;
const IndexFrameList = firefly.physics.IndexFrameList;
const EAnimation = firefly.physics.EAnimation;
const IndexFrameIntegration = firefly.physics.IndexFrameIntegration;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Hello Tile Set", init);
}

fn init() void {
    const viewId = View.new(.{
        .name = "TestView",
        .position = .{ 0, 0 },
        .projection = .{
            //.clear_color = .{ 0, 0, 0, 255 },
            //.position = .{ 0, 0 },
            .width = 600,
            .height = 400,
        },
    }).id;

    View.activateById(viewId, true);

    Texture.new(.{
        .name = "Atlas",
        .resource = "resources/atlas1616.png",
        .is_mipmap = false,
    }).load();

    var tile_set = TileSet.new(.{
        .name = "TileSet",
        .texture_name = "Atlas",
    })
        .withTileTemplate(tileTemplate("full", 0, 0, false, false, false))
        .withTileTemplate(tileTemplate("slope_1_1", 1, 0, false, false, true))
        .withTileTemplate(tileTemplate("slope_1_2", 1, 0, true, false, true))
        .withTileTemplate(tileTemplate("slope_1_3", 1, 0, true, true, true))
        .withTileTemplate(tileTemplate("slope_1_4", 1, 0, false, true, true))
        .withTileTemplate(tileTemplate("slope_2_1", 2, 0, false, false, true))
        .withTileTemplate(tileTemplate("slope_2_2", 2, 0, true, false, true))
        .withTileTemplate(tileTemplate("slope_2_3", 2, 0, true, true, true))
        .withTileTemplate(tileTemplate("slope_2_4", 2, 0, false, true, true))
        .withTileTemplate(tileTemplate("slope_3_1", 3, 0, false, false, true))
        .withTileTemplate(tileTemplate("slope_3_2", 3, 0, true, false, true))
        .withTileTemplate(tileTemplate("slope_3_3", 3, 0, true, true, true))
        .withTileTemplate(tileTemplate("slope_3_4", 3, 0, false, true, true))
        .withTileTemplate(tileTemplate("slope_4_1", 4, 0, false, false, true))
        .withTileTemplate(tileTemplate("slope_4_2", 4, 0, true, false, true))
        .withTileTemplate(tileTemplate("slope_4_3", 4, 0, true, true, true))
        .withTileTemplate(tileTemplate("slope_4_4", 4, 0, false, true, true))
        .withTileTemplate(tileTemplate("slope_5_1", 5, 0, false, false, true))
        .withTileTemplate(tileTemplate("slope_5_2", 5, 0, true, false, true))
        .withTileTemplate(tileTemplate("slope_5_3", 5, 0, true, true, true))
        .withTileTemplate(tileTemplate("slope_5_4", 5, 0, false, true, true))
        .withTileTemplate(tileTemplate("slope_6_1", 6, 0, false, false, true))
        .withTileTemplate(tileTemplate("slope_6_2", 6, 0, true, false, true))
        .withTileTemplate(tileTemplate("slope_6_3", 6, 0, true, true, true))
        .withTileTemplate(tileTemplate("slope_6_4", 6, 0, false, true, true))
        .withTileTemplate(tileTemplate("slope_7_1", 7, 0, false, false, true))
        .withTileTemplate(tileTemplate("slope_7_2", 7, 0, true, false, true))
        .withTileTemplate(tileTemplate("slope_7_3", 7, 0, true, true, true))
        .withTileTemplate(tileTemplate("slope_7_4", 7, 0, false, true, true))
    //
        .withTileTemplate(tileTemplate("_slope_0_1", 0, 1, false, false, true))
        .withTileTemplate(tileTemplate("_slope_1_1", 1, 1, false, false, true))
    //
        .withTileTemplate(tileTemplate("_slope_2_1", 2, 1, false, false, true))
        .withTileTemplate(tileTemplate("_slope_2_2", 2, 1, false, true, true))
    //
        .withTileTemplate(tileTemplate("_slope_3_1", 3, 1, false, false, true))
        .withTileTemplate(tileTemplate("_slope_3_2", 3, 1, true, false, true))
    //
        .withTileTemplate(tileTemplate("_slope_4_1", 4, 1, false, false, true))
        .withTileTemplate(tileTemplate("_slope_4_2", 4, 1, false, true, true))
    //
        .withTileTemplate(tileTemplate("_slope_5_1", 5, 1, false, false, true))
        .withTileTemplate(tileTemplate("_slope_5_2", 5, 1, true, false, true))
    //
        .withTileTemplate(tileTemplate("_slope_6_1", 6, 1, false, false, true))
        .withTileTemplate(tileTemplate("_slope_6_2", 6, 1, true, false, true))
        .withTileTemplate(tileTemplate("_slope_6_3", 6, 1, true, true, true))
        .withTileTemplate(tileTemplate("_slope_6_4", 6, 1, false, true, true))
    //
        .withTileTemplate(tileTemplate("animation", 1, 0, false, false, false)
        .withAnimationFrame(TileAnimationFrame{ .duration = 1000, .sprite_data = .{ .texture_bounds = .{ 16, 0, 16, 16 } } })
        .withAnimationFrame(TileAnimationFrame{ .duration = 1000, .sprite_data = .{ .texture_bounds = .{ 16, 0, 16, 16 }, .flip_x = true } })
        .withAnimationFrame(TileAnimationFrame{ .duration = 1000, .sprite_data = .{ .texture_bounds = .{ 16, 0, 16, 16 }, .flip_x = true, .flip_y = true } })
        .withAnimationFrame(TileAnimationFrame{ .duration = 1000, .sprite_data = .{ .texture_bounds = .{ 16, 0, 16, 16 }, .flip_y = true } }))
        .activate();

    var next = tile_set.tile_templates.slots.nextSetBit(0);
    var x: usize = 50;
    var y: usize = 50;
    while (next) |i| {
        if (tile_set.tile_templates.get(i)) |tile_template| {
            createTileProspect(
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

fn createTileProspect(
    tile_set: *TileSet,
    tile_template: *TileTemplate,
    x: Float,
    y: Float,
    view_id: Index,
) void {
    var entity = Entity.new(.{ .name = tile_template.name })
        .withComponent(ETransform{ .position = .{ x, y } })
        .withComponent(EView{ .view_id = view_id })
        .withComponent(ESprite{ .template_id = tile_template._sprite_template_id.? });

    if (tile_set.createContactMaskFromImage(tile_template)) |mask| {
        var vert: std.ArrayList(Float) = std.ArrayList(Float).init(firefly.api.ALLOC);
        defer vert.deinit();

        for (0..mask.height) |_y| {
            for (0..mask.width) |_x| {
                if (mask.isBitSetAt(_x, _y)) {
                    vert.append(firefly.utils.usize_f32(_x + 16)) catch unreachable;
                    vert.append(firefly.utils.usize_f32(_y + 16)) catch unreachable;
                }
            }
        }

        _ = entity.withComponent(EShape{
            .shape_type = firefly.api.ShapeType.POINT,
            .vertices = firefly.api.ALLOC.dupe(Float, vert.items) catch unreachable,
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

        _ = entity.withComponent(EAnimation{})
            .withAnimation(
            .{ .duration = list._duration, .looping = true, .active_on_init = true },
            IndexFrameIntegration{
                .timeline = list,
                .property_ref = ESprite.Property.FrameId,
            },
        );
    }

    _ = entity.activate();
}

fn tileTemplate(name: String, x: usize, y: usize, flip_x: bool, flip_y: bool, mask: bool) TileTemplate {
    return .{
        .name = name,
        .sprite_data = .{
            .texture_bounds = .{
                utils.usize_f32(x * 16),
                utils.usize_f32(y * 16),
                16,
                16,
            },
            .flip_x = flip_x,
            .flip_y = flip_y,
        },
        .contact_material_type = TileContactMaterialType.TERRAIN,
        .contact_mask_name = if (mask) name else null,
    };
}
