const std = @import("std");
const firefly = @import("../firefly.zig");

const NamePool = firefly.api.NamePool;
const Task = firefly.api.Task;
const Composite = firefly.api.Composite;
const GameTaskAttributes = firefly.game.GameTaskAttributes;
const ContactMaterialAspectGroup = firefly.physics.ContactMaterialAspectGroup;
const SpriteData = firefly.game.SpriteData;
const TileAnimationFrame = firefly.game.TileAnimationFrame;
const TileTemplate = firefly.game.TileTemplate;
const TileSet = firefly.game.TileSet;
const Attributes = firefly.api.Attributes;
const String = firefly.utils.String;
const Index = firefly.utils.Index;
const RectF = firefly.utils.RectF;
const Float = firefly.utils.Float;
const parseBoolean = firefly.utils.parseBoolean;
const parsePosF = firefly.utils.parsePosF;
const parseName = firefly.utils.parseName;
const parseFloat = firefly.utils.parseFloat;
const parseUsize = firefly.utils.parseUsize;

//////////////////////////////////////////////////////////////
//// game room init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    // create JSON tasks
    _ = Task.new(.{
        .name = JSONTasks.LOAD_TILE_SET_TASK,
        .function = loadTileSetTask,
    });
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // dispose JSON tasks
    Task.disposeByName(JSONTasks.LOAD_TILE_SET_TASK);
}

//////////////////////////////////////////////////////////////
//// game json binding
//////////////////////////////////////////////////////////////

pub const JSONTasks = struct {
    pub const LOAD_TILE_SET_TASK = "LOAD_TILE_SET_JSON_TASK";
};

// Tile sets and load tasks
pub const JSONTile = struct {
    name: String,
    props: String, // "pos_x,pos_y|flip_x?|flip_y?|?contact_material_type|contact_mask?|?groups[g1,g3,...]"
    animation: ?String = null, // "duration,pos_x,pos_y,flip_x?,flip_y?|duration,pos_x,pos_y,flip_x?,flip_y?|..."
};

pub const JSONTileSet = struct {
    type: String,
    name: String,
    atlas_texture_name: String,
    tile_width: Float,
    tile_height: Float,
    tiles: []const JSONTile,
};

fn loadTileSetTask(_: ?Index, attributes: ?*Attributes) void {
    if (attributes) |attrs| {
        if (attrs.get(GameTaskAttributes.LOAD_FILE_NAME)) |file| {
            const res = firefly.api.loadFromFile(file);
            attrs.set(GameTaskAttributes.JSON_RESOURCE, res);
            defer firefly.api.ALLOC.free(res);
        }

        if (attrs.get(GameTaskAttributes.JSON_RESOURCE)) |json| {
            const parsed = std.json.parseFromSlice(
                JSONTileSet,
                firefly.api.ALLOC,
                json,
                .{ .ignore_unknown_fields = true },
            ) catch unreachable;
            defer parsed.deinit();

            const jsonTileSet: JSONTileSet = parsed.value;

            // create TileSet from jsonTileSet
            var tile_set = TileSet.new(.{
                .name = NamePool.alloc(jsonTileSet.name),
                .texture_name = NamePool.alloc(jsonTileSet.atlas_texture_name).?,
            });

            // create all tile templates for tile set
            for (0..jsonTileSet.tiles.len) |i| {
                var it = std.mem.split(u8, jsonTileSet.tiles[i].props, "|");

                if (parsePosF(it.next())) |tex_pos| {
                    var tile_template: TileTemplate = .{
                        .name = NamePool.alloc(jsonTileSet.tiles[i].name),
                        .sprite_data = .{
                            .texture_bounds = RectF{
                                tex_pos[0] * jsonTileSet.tile_width,
                                tex_pos[1] * jsonTileSet.tile_height,
                                jsonTileSet.tile_width,
                                jsonTileSet.tile_height,
                            },
                            .flip_x = parseBoolean(it.next()),
                            .flip_y = parseBoolean(it.next()),
                        },
                        .contact_material_type = ContactMaterialAspectGroup.getAspectIfExists(it.next().?),
                        .contact_mask_name = NamePool.alloc(if (parseBoolean(it.next())) jsonTileSet.tiles[i].name else null),
                        .groups = NamePool.alloc(parseName(it.next().?)),
                    };

                    if (jsonTileSet.tiles[i].animation) |a| {
                        var it_a1 = std.mem.split(u8, a, "|");
                        while (it_a1.next()) |frame| {
                            var it_a2 = std.mem.split(u8, frame, ",");
                            tile_template = tile_template.withAnimationFrame(.{
                                .duration = parseUsize(it_a2.next().?),
                                .sprite_data = .{
                                    .texture_bounds = RectF{
                                        parseFloat(it_a2.next()) * jsonTileSet.tile_width,
                                        parseFloat(it_a2.next()) * jsonTileSet.tile_height,
                                        jsonTileSet.tile_width,
                                        jsonTileSet.tile_height,
                                    },
                                    .flip_x = parseBoolean(it_a2.next()),
                                    .flip_y = parseBoolean(it_a2.next()),
                                },
                            });
                        }
                    }
                    _ = tile_set.withTileTemplate(tile_template);
                }
            }

            // add tile set as owned reference if requested
            if (attrs.get(GameTaskAttributes.OWNER_COMPOSITE)) |owner_name| {
                if (Composite.byName(owner_name)) |comp|
                    comp.addCReference(TileSet.referenceById(tile_set.id, true));
            }
        }
    }
}
