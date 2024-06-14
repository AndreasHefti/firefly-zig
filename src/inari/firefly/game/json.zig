const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const game = firefly.game;
const physics = firefly.physics;

const String = firefly.utils.String;
const Index = firefly.utils.Index;
const Float = firefly.utils.Float;
const Color = firefly.utils.Color;
const BlendMode = firefly.api.BlendMode;

//////////////////////////////////////////////////////////////
//// game json binding
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    _ = api.Task.new(.{
        .name = JSONTasks.LOAD_TILE_SET,
        .function = loadTileSetFromJSON,
    });

    _ = api.Task.new(.{
        .name = JSONTasks.LOAD_TILE_MAPPING,
        .function = loadTileMappingFromJSON,
    });
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // dispose tasks
    api.Task.disposeByName(JSONTasks.LOAD_TILE_MAPPING);
    api.Task.disposeByName(JSONTasks.LOAD_TILE_SET);
}

/// Refers a component of context specific kind that can be loaded from file.
/// Usually a load task shall check if the referenced component with "name" already exists.
/// If so, and "update_task" is set too, update if given task.
/// If component is not loaded yet, load the component with given load_task or default task
pub const FileResource = struct {
    name: String,
    file: String,
    load_task: ?String = null,
};

pub const JSONTasks = struct {
    pub const LOAD_TILE_SET = "LOAD_TILE_SET";
    pub const LOAD_TILE_MAPPING = "LOAD_TILE_MAPPING";
};

//////////////////////////////////////////////////////////////
//// Default TileSet JSON Binding
//////////////////////////////////////////////////////////////
///  {
///      "name": "TileSet1",
///      "texture": {
///         "name": "Atlas1",
///         "file": "resources/logo.png"
///      },
///      "tile_width": 16,
///      "tile_height": 16,
///      "tiles": [
///          { "name": "full", "props": "0,0|0|0|TERRAIN|0|-" },
///          { "name": "slope_1_1", "props": "1,0|0|0|TERRAIN|1|-" },
///          { "name": "circle", "props": "0,1|0|0|TERRAIN|1|-" },
///          { "name": "route", "props": "1,1|0|0|TERRAIN|1|-" },
///          {
///             "name": "tileTemplate",
///             "props": "1,0|0|0|-|0|-",
///             "animation": "1000,1,0,0,0|1000,1,0,1,0|1000,1,0,1,1|1000,1,0,0,1"
///          }
///      ]
///  }
//////////////////////////////////////////////////////////////

pub const JSONTile = struct {
    name: String,
    props: String, // "pos_x,pos_y|flip_x?|flip_y?|?contact_material_type|contact_mask?|?groups[g1,g3,...]"
    animation: ?String = null, // "duration,pos_x,pos_y,flip_x?,flip_y?|duration,pos_x,pos_y,flip_x?,flip_y?|..."
};

pub const JSONTileSet = struct {
    name: String,
    texture: FileResource,
    tile_width: Float,
    tile_height: Float,
    tiles: []const JSONTile,
};

fn loadTileSetFromJSON(attributes: *api.CallAttributes) void {
    if (attributes.getProperty(game.TaskAttributes.FILE_RESOURCE)) |file| {
        const res = firefly.api.loadFromFile(file);
        defer firefly.api.ALLOC.free(res);
        attributes.setProperty(game.TaskAttributes.JSON_RESOURCE, res);
    }

    if (attributes.getProperty(game.TaskAttributes.JSON_RESOURCE)) |json| {
        const parsed = std.json.parseFromSlice(
            JSONTileSet,
            firefly.api.ALLOC,
            json,
            .{ .ignore_unknown_fields = true },
        ) catch unreachable;
        defer parsed.deinit();

        const jsonTileSet: JSONTileSet = parsed.value;

        std.debug.print("************ jsonTileSet.texture.name: {s}\n", .{jsonTileSet.texture.name});
        std.debug.print("************ jsonTileSet.texture.file: {s} length: {d}\n", .{ jsonTileSet.texture.file, jsonTileSet.texture.file.len });

        // check texture and load or create if needed
        if (!graphics.Texture.existsByName(jsonTileSet.texture.name)) {
            if (jsonTileSet.texture.load_task) |lt| {
                api.Task.runTaskByName(lt, null);
            } else {
                _ = graphics.Texture.new(.{
                    .name = api.NamePool.alloc(jsonTileSet.texture.name).?,
                    .resource = api.NamePool.alloc(jsonTileSet.texture.file).?,
                    .is_mipmap = false,
                }).load();
            }
        }
        // check Texture exists now
        if (!graphics.Texture.existsByName(jsonTileSet.texture.name)) {
            std.debug.print("Failed to find/load texture: {any}", .{jsonTileSet.texture});
            @panic("Failed to find/load texture");
        }

        // create TileSet from jsonTileSet
        var tile_set = game.TileSet.new(.{
            .name = api.NamePool.alloc(jsonTileSet.name),
            .texture_name = api.NamePool.alloc(jsonTileSet.texture.name).?,
            .tile_width = jsonTileSet.tile_width,
            .tile_height = jsonTileSet.tile_height,
        });

        // create all tile templates for tile set
        for (0..jsonTileSet.tiles.len) |i| {
            var it = std.mem.split(u8, jsonTileSet.tiles[i].props, "|");

            if (utils.parsePosF(it.next())) |tex_pos| {
                var tile_template: game.TileTemplate = .{
                    .name = api.NamePool.alloc(jsonTileSet.tiles[i].name),
                    .sprite_data = .{
                        .texture_pos = .{
                            tex_pos[0] * tile_set.tile_width,
                            tex_pos[1] * tile_set.tile_height,
                        },
                        .flip_x = utils.parseBoolean(it.next()),
                        .flip_y = utils.parseBoolean(it.next()),
                    },
                    .contact_material_type = physics.ContactMaterialAspectGroup.getAspectIfExists(it.next().?),
                    .contact_mask_name = api.NamePool.alloc(if (utils.parseBoolean(it.next())) jsonTileSet.tiles[i].name else null),
                    .groups = api.NamePool.alloc(utils.parseName(it.next().?)),
                };

                if (jsonTileSet.tiles[i].animation) |a| {
                    var it_a1 = std.mem.split(u8, a, "|");
                    while (it_a1.next()) |frame| {
                        var it_a2 = std.mem.split(u8, frame, ",");
                        tile_template = tile_template.withAnimationFrame(.{
                            .duration = utils.parseUsize(it_a2.next().?),
                            .sprite_data = .{
                                .texture_pos = .{
                                    utils.parseFloat(it_a2.next()) * tile_set.tile_width,
                                    utils.parseFloat(it_a2.next()) * tile_set.tile_height,
                                },
                                .flip_x = utils.parseBoolean(it_a2.next()),
                                .flip_y = utils.parseBoolean(it_a2.next()),
                            },
                        });
                    }
                }
                tile_set.addTileTemplate(tile_template);
            }
        }

        // add tile set as owned reference if requested
        if (attributes.getProperty(game.TaskAttributes.OWNER_COMPOSITE)) |owner_name| {
            if (api.Composite.byName(owner_name)) |comp|
                comp.addCReference(game.TileSet.referenceById(tile_set.id, true));
        }
    }
}

//////////////////////////////////////////////////////////////
//// Default TileSetMapping JSON Binding
//////////////////////////////////////////////////////////////
/// {
///     "name": "TileSetMapping1",
///     "view_name": "view1",
///     "tile_sets": [
///         { "name": "TileSet1", "file": "resources/tileset1.json", "load_task": "LOAD_TILE_SET" },
///         { "name": "TileSet2", "file": "resources/tileset2.json"},
///         { "name": "TileSet3", "file": "resources/tileset3.json"}
///     ],
///     "layer_mapping": [
///         {
///             "layer_name": "Background",
///             "offset": "0,0",
///             "tile_sets_refs": [
///                 { "tile_set_name": "TileSet1", "tint_color": "255,255,255,128", "blend_mode": "ALPHA" },
///                 { "tile_set_name": "TileSet3" }
///             ]
///         },
///         {
///             "layer_name": "Foreground",
///             "offset": "10,10",
///             "tile_sets_refs": [
///                 { "tile_set_name": "TileSet1" },
///                 { "tile_set_name": "TileSet2" }
///             ]
///         }
///     ]
/// }
//////////////////////////////////////////////////////////////

pub const TileSetDef = struct {
    resource: FileResource,
    code_offset: ?Index = null,
};

pub const TileLayerMapping = struct {
    layer_name: String,
    tint_color: ?String = null, // r,g,b,a --> u8 --> 0-255
    blend_mode: ?String = null, // BlendMode Enum field name
    offset: ?String = null, // x,y --> Float
    parallax_factor: ?String = null, // x,y --> Float
    tile_sets_refs: String,
};

pub const JSONTileMapping = struct {
    name: String,
    view_name: String,
    tile_sets: []const TileSetDef,
    layer_mapping: []const TileLayerMapping,
};

fn loadTileMappingFromJSON(attributes: *api.CallAttributes) void {
    if (attributes.getProperty(game.TaskAttributes.FILE_RESOURCE)) |file| {
        const res = firefly.api.loadFromFile(file);
        defer firefly.api.ALLOC.free(res);
        attributes.setProperty(game.TaskAttributes.JSON_RESOURCE, res);
    }

    if (attributes.getProperty(game.TaskAttributes.JSON_RESOURCE)) |json| {
        const parsed = std.json.parseFromSlice(
            JSONTileMapping,
            firefly.api.ALLOC,
            json,
            .{ .ignore_unknown_fields = true },
        ) catch unreachable;
        defer parsed.deinit();

        const jsonTileMapping: JSONTileMapping = parsed.value;
        var tile_mapping = game.TileMapping.new(.{ .name = jsonTileMapping.name });

        // process tile sets and make code offset mapping, if not exists, load it
        var code_offset: Index = 1;
        var code_offset_mapping = utils.DynIndexArray.new(api.ALLOC, 10);
        defer code_offset_mapping.deinit();

        for (0..jsonTileMapping.tile_sets.len) |i| {
            var tile_set_def = jsonTileMapping.tile_sets[i];
            if (!game.TileSet.existsName(tile_set_def.resource.name)) {
                // load tile set from file
                var tile_set_attrs = api.CallAttributes{
                    .caller_id = attributes.c1_id,
                    .caller_name = attributes.caller_name,
                };
                defer tile_set_attrs.deinit();
                tile_set_attrs.setProperty(game.TaskAttributes.FILE_RESOURCE, tile_set_def.resource.file);
                api.Task.runTaskByName(
                    if (tile_set_def.resource.load_task) |load_task| load_task else game.JSONTasks.LOAD_TILE_SET,
                    &tile_set_attrs,
                );
            }

            if (tile_set_def.code_offset == null)
                tile_set_def.code_offset = code_offset;

            code_offset = code_offset + game.TileSet.byName(tile_set_def.resource.name).?.tile_templates.size();
        }

        // prepare view
        var view_id: ?Index = null;
        if (firefly.graphics.View.idByName(jsonTileMapping.view_name)) |vid| {
            view_id = vid;
        } else {
            @panic("View does not exists: ");
        }

        // process tile layer
        for (0..jsonTileMapping.layer_mapping.len) |i| {
            const layer_mapping = jsonTileMapping.layer_mapping[i];

            // get involved layer, if name exists but layer not yet, create one
            var layer_id: ?Index = null;
            if (firefly.graphics.Layer.existsName(layer_mapping.layer_name)) {
                layer_id = firefly.graphics.Layer.idByName(layer_mapping.layer_name).?;
            } else {
                layer_id = firefly.graphics.Layer.new(.{
                    .name = layer_mapping.layer_name,
                    .view_id = view_id.?,
                }).id;
            }

            // create tile layer data
            var tile_layer_data: *game.TileLayerData = tile_mapping.withTileLayerData(layer_mapping.layer_name);
            tile_layer_data.tint = utils.parseColor(layer_mapping.tint_color);
            tile_layer_data.blend = BlendMode.byName(layer_mapping.blend_mode);
            tile_layer_data.parallax = utils.parsePosF(layer_mapping.parallax_factor);
            tile_layer_data.offset = utils.parsePosF(layer_mapping.offset);

            // add tile set references to tile layer data
            var tile_set_ref_it = std.mem.split(u8, layer_mapping.tile_sets_refs, ",");
            while (tile_set_ref_it.next()) |tile_set_name| {
                for (0..jsonTileMapping.tile_sets.len) |ii| {
                    const tile_set_ref = jsonTileMapping.tile_sets[ii];
                    if (utils.stringEquals(tile_set_ref.resource.name, tile_set_name)) {
                        _ = tile_layer_data.withTileSetMapping(.{
                            .tile_set_name = tile_set_ref.resource.name,
                            .code_offset = tile_set_ref.code_offset.?,
                        });
                        break;
                    }
                }
            }
        }

        // add tile set as owned reference if requested
        if (attributes.getProperty(game.TaskAttributes.OWNER_COMPOSITE)) |owner_name| {
            if (api.Composite.byName(owner_name)) |comp|
                comp.addCReference(game.TileSet.referenceById(tile_mapping.id, true));
        }
    }
}

//////////////////////////////////////////////////////////////
//// Default TileSetMapping JSON Binding
//////////////////////////////////////////////////////////////
