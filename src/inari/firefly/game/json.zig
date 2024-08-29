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
        .name = game.Tasks.JSON_LOAD_TILE_SET,
        .function = loadTileSetFromJSON,
    });

    _ = api.Task.new(.{
        .name = game.Tasks.JSON_LOAD_TILE_MAPPING,
        .function = loadTileMappingFromJSON,
    });

    _ = api.Task.new(.{
        .name = game.Tasks.JSON_LOAD_ROOM,
        .function = loadRoomFromJSON,
    });
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // dispose tasks
    api.Task.disposeByName(game.Tasks.JSON_LOAD_ROOM);
    api.Task.disposeByName(game.Tasks.JSON_LOAD_TILE_MAPPING);
    api.Task.disposeByName(game.Tasks.JSON_LOAD_TILE_SET);
}

//////////////////////////////////////////////////////////////
//// API
//////////////////////////////////////////////////////////////

pub const JSONAttribute = struct {
    name: String,
    value: String,
};

pub const JSONResourceHandle = struct {
    json_resource: ?String,
    free_json_resource: bool,

    pub fn new(a_id: Index) JSONResourceHandle {
        var attrs = api.Attributes.byId(a_id);
        if (attrs.get(game.TaskAttributes.FILE_RESOURCE)) |file| {
            return .{
                .json_resource = firefly.api.loadFromFile(file),
                .free_json_resource = true,
            };
        } else {
            return .{
                .json_resource = attrs.get(game.TaskAttributes.JSON_RESOURCE),
                .free_json_resource = false,
            };
        }
    }

    pub fn deinit(self: JSONResourceHandle) void {
        if (self.free_json_resource) {
            if (self.json_resource) |r| firefly.api.ALLOC.free(r);
        }
    }
};

//////////////////////////////////////////////////////////////
//// JSON Binding
//////////////////////////////////////////////////////////////

/// Refers a component of context specific kind that can be loaded from file.
/// Usually a load task shall check if the referenced component with "name" already exists.
/// If so, and "update_task" is set too, update if given task.
/// If component is not loaded yet, load the component with given load_task or default task
pub const Resource = struct {
    name: String,
    file: ?String = null,
    load_task: ?String = null,
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
    texture: Resource,
    tile_width: Float,
    tile_height: Float,
    tiles: []const JSONTile,
};

fn loadTileSetFromJSON(_: ?Index, a_id: ?Index) void {
    const attr_id = a_id orelse
        return;

    var attrs = api.Attributes.byId(attr_id);
    var json_res_handle = JSONResourceHandle.new(attr_id);
    defer json_res_handle.deinit();

    if (json_res_handle.json_resource) |json| {
        const parsed = std.json.parseFromSlice(
            JSONTileSet,
            firefly.api.ALLOC,
            json,
            .{ .ignore_unknown_fields = true },
        ) catch unreachable;
        defer parsed.deinit();

        const jsonTileSet: JSONTileSet = parsed.value;

        // check if tile set already exists. If so, do nothing
        // TODO hot reload here?
        if (game.TileSet.existsName(jsonTileSet.name))
            return;

        // check texture and load or create if needed
        if (!graphics.Texture.existsByName(jsonTileSet.texture.name)) {
            if (jsonTileSet.texture.load_task) |lt| {
                api.Task.runTaskByName(lt);
            } else {
                _ = graphics.Texture.new(.{
                    .name = api.NamePool.alloc(jsonTileSet.texture.name).?,
                    .resource = api.NamePool.alloc(jsonTileSet.texture.file).?,
                    .is_mipmap = false,
                }).load();
            }
        }
        // check Texture exists now
        if (!graphics.Texture.existsByName(jsonTileSet.texture.name))
            utils.panic(api.ALLOC, "Failed to find/load texture: {any}", .{jsonTileSet.texture});

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
        if (attrs.get(api.OWNER_COMPOSITE_TASK_ATTRIBUTE)) |owner_name| {
            if (api.Composite.byName(owner_name)) |comp|
                comp.addComponentReference(game.TileSet.referenceById(tile_set.id, true));
        }
    }
}

//////////////////////////////////////////////////////////////
//// Default TileSetMapping JSON Binding
//////////////////////////////////////////////////////////////
/// {
///     "name": "TileSetMapping1",
///     "tile_sets": [
///         { "code_offset": 1, "resource": { "name": "TileSet1", "file": "resources/tileset1.json", "load_task": "LOAD_TILE_SET" }},
///         { "code_offset": 10, "resource": { "name": "TileSet2", "file": "resources/tileset2.json"}},
///         { "code_offset": 20, "resource": { "name": "TileSet3", "file": "resources/tileset3.json"}}
///     ],
///     "layer_mapping": [
///         {
///             "layer_name": "Background",
///             "offset": "10,10",
///             "blend_mode": "ALPHA",
///             "tint_color": "255,255,255,100",
///             "parallax_factor": "2,2",
///             "tile_sets_refs": "TileSet1,TileSet3"
///         },
///         {
///             "layer_name": "Foreground",
///             "offset": "10,10",
///             "blend_mode": "ALPHA",
///             "tint_color": "255,255,255,100",
///             "tile_sets_refs": "TileSet1,TileSet2"
///         }
///     ],
///     "tile_grids": [
///         {
///             "name": "Grid1",
///             "layer": "Background",
///             "position": "0,0",
///             "spherical": false,
///             "tile_width": 16,
///             "tile_height": 16,
///             "grid_tile_width": 20,
///             "grid_tile_height": 10,
///             "codes": "1,1,1,1,0,0,0,0,,4,53,1,1,1...",
///         },
///         {
///             "name": "Grid2",
///             "layer": "Foreground",
///             "position": "0,0",
///             "spherical": false,
///             "tile_width": 16,
///             "tile_height": 16,
///             "grid_tile_width": 20,
///             "grid_tile_height": 10,
///             "codes": "1,1,1,1,0,0,0,0,,4,53,1,1,1...",
///         }
///     ]
/// }
//////////////////////////////////////////////////////////////

pub const TileSetDef = struct {
    resource: Resource,
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
    tile_sets: []const TileSetDef,
    layer_mapping: []const TileLayerMapping,
    tile_grids: []const JSONTileGrid,
};

pub const JSONTileGrid = struct {
    name: String,
    layer: String,
    position: String,
    spherical: bool = false,
    tile_width: usize,
    tile_height: usize,
    grid_tile_width: usize,
    grid_tile_height: usize,
    codes: String,
};

fn loadTileMappingFromJSON(caller_id: ?Index, a_id: ?Index) void {
    const attr_id = a_id orelse
        return;

    var attrs = api.Attributes.byId(attr_id);
    const view_name = attrs.get(game.TaskAttributes.VIEW_NAME) orelse
        @panic("Missing attribute TaskAttributes.ATTR_VIEW_NAME");
    var json_res_handle = JSONResourceHandle.new(attr_id);
    defer json_res_handle.deinit();

    if (json_res_handle.json_resource) |json| {
        const parsed = std.json.parseFromSlice(
            JSONTileMapping,
            firefly.api.ALLOC,
            json,
            .{ .ignore_unknown_fields = true },
        ) catch unreachable;
        defer parsed.deinit();

        const jsonTileMapping: JSONTileMapping = parsed.value;

        // check if tile map with name already exits. If so, do nothing
        // TODO hot reload here?
        if (game.TileMapping.existsName(jsonTileMapping.name))
            return;

        // prepare view
        var view_id: ?Index = null;
        if (firefly.graphics.View.idByName(view_name)) |vid| {
            view_id = vid;
        } else utils.panic(api.ALLOC, "View does not exists: {s}", .{view_name});

        var tile_mapping = game.TileMapping.new(.{
            .name = api.NamePool.alloc(jsonTileMapping.name),
            .view_id = view_id.?,
        });

        // process tile sets and make code offset mapping, if not exists, load it
        var code_offset: Index = 1;
        var code_offset_mapping = utils.DynIndexArray.new(api.ALLOC, 10);
        defer code_offset_mapping.deinit();

        for (0..jsonTileMapping.tile_sets.len) |i| {
            var tile_set_def = jsonTileMapping.tile_sets[i];
            if (!game.TileSet.existsName(tile_set_def.resource.name)) {
                if (tile_set_def.resource.file == null)
                    utils.panic(
                        api.ALLOC,
                        "No File defined for missing resource: {s}",
                        .{tile_set_def.resource.name},
                    );

                // load tile set from file
                api.Task.runTaskByNameWith(
                    if (tile_set_def.resource.load_task) |load_task| load_task else game.Tasks.JSON_LOAD_TILE_SET,
                    caller_id,
                    .{.{ game.TaskAttributes.FILE_RESOURCE, tile_set_def.resource.file.? }},
                );
            }

            if (tile_set_def.code_offset == null)
                tile_set_def.code_offset = code_offset;

            code_offset = code_offset + game.TileSet.byName(tile_set_def.resource.name).?.tile_templates.size();
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
                    .name = api.NamePool.alloc(layer_mapping.layer_name),
                    .view_id = view_id.?,
                    .order = i,
                }).id;
            }

            // create tile layer data
            var tile_layer_data: *game.TileLayerData = tile_mapping.withTileLayerData(.{
                .layer = api.NamePool.alloc(layer_mapping.layer_name).?,
                .tint = utils.parseColor(layer_mapping.tint_color).?,
                .blend = BlendMode.byName(layer_mapping.blend_mode),
                .parallax = utils.parsePosF(layer_mapping.parallax_factor),
                .offset = utils.parsePosF(layer_mapping.offset),
            });

            // add tile set references to tile layer data
            var tile_set_ref_it = std.mem.split(u8, layer_mapping.tile_sets_refs, ",");
            while (tile_set_ref_it.next()) |tile_set_name| {
                for (0..jsonTileMapping.tile_sets.len) |ii| {
                    const tile_set_ref = jsonTileMapping.tile_sets[ii];
                    if (utils.stringEquals(tile_set_ref.resource.name, tile_set_name)) {
                        _ = tile_layer_data.withTileSetMapping(.{
                            .tile_set_name = api.NamePool.alloc(tile_set_ref.resource.name).?,
                            .code_offset = tile_set_ref.code_offset.?,
                        });
                        break;
                    }
                }
            }
        }

        // apply tile grids
        for (0..jsonTileMapping.tile_grids.len) |i| {
            const json_grid = jsonTileMapping.tile_grids[i];
            tile_mapping.addTileGridData(.{
                .name = api.NamePool.alloc(json_grid.name).?,
                .layer = api.NamePool.alloc(json_grid.layer).?,
                .world_position = utils.parsePosF(json_grid.position) orelse .{ 0, 0 },
                .spherical = json_grid.spherical,
                .dimensions = .{
                    json_grid.grid_tile_width,
                    json_grid.grid_tile_height,
                    json_grid.tile_width,
                    json_grid.tile_height,
                },
                .codes = api.NamePool.alloc(json_grid.codes).?,
            });
        }

        // add tile set as owned reference if requested
        if (attrs.get(api.OWNER_COMPOSITE_TASK_ATTRIBUTE)) |owner_name| {
            if (api.Composite.byName(owner_name)) |comp|
                comp.addComponentReference(game.TileMapping.referenceById(tile_mapping.id, true));
        }
    }
}

//////////////////////////////////////////////////////////////
//// Default Room JSON Binding
//////////////////////////////////////////////////////////////
/// {
///     "name": "Room1",
///     "start_scene": "scene1",
///     "end_scene": "scene2",
///     "tile_sets": [
///         { "name": "TestTileSet", "file": "resources/example_tileset.json" }
///     ],
///     "tile_map": { "name": "TileMapRoom1", "file": "resources/example_tilemap1.json" },
///     "objects": [
///      {
///        "name": "t1",
///        "object_type": "room_transition",
///        "build_task": "RoomTransitionBuilder",
///        "layer": "Foreground",
///        "position": "318,16",
///        "attributes": [
///            { "name": "condition", "value": "TransitionEast"},
///            { "name": "orientation", "value": "EAST"},
///            { "name": "target", "value": "Room2"},
///            { "name": "bounds", "value": "318,16,4,16"},
///            { "name": "rotation", "value": "0"},
///            { "name": "scale", "value": "0,0"}
///        ]
///      },
///      {
///        "name": "t2",
///        "object_type": "room_transition",
///        "build_task": "RoomTransitionBuilder",
///        "layer": "Foreground",
///        "position": "256,157",
///        "attributes": [
///            { "name": "condition", "value": "TransitionSouth"},
///            { "name": "orientation", "value": "SOUTH"},
///            { "name": "target", "value": "Room3"},
///            { "name": "bounds", "value": "256,157,48,12"},
///            { "name": "rotation", "value": "0"},
///            { "name": "scale", "value": "0,0"}
///        ]
///      }
///    ]
/// }
//////////////////////////////////////////////////////////////

pub const JSONRoom = struct {
    name: String,
    bounds: String,
    start_scene: ?String = null,
    end_scene: ?String = null,
    tile_sets: []const Resource,
    tile_map: Resource,
    objects: ?[]const JSONRoomObject = null,
};

pub const JSONRoomObject = struct {
    name: String,
    object_type: String,
    build_task: String,
    layer: ?String = null,
    position: ?String = null,
    attributes: ?[]const JSONAttribute = null,
};

fn loadRoomFromJSON(_: ?Index, a_id: ?Index) void {
    const attr_id = a_id orelse
        return;

    var attrs = api.Attributes.byId(attr_id);
    const view_name = attrs.get(game.TaskAttributes.VIEW_NAME) orelse
        @panic("Missing attribute TaskAttributes.ATTR_VIEW_NAME");

    var json_res_handle = JSONResourceHandle.new(attr_id);
    defer json_res_handle.deinit();

    const json = json_res_handle.json_resource orelse {
        utils.panic(api.ALLOC, "Failed to load json from file: {any}", .{json_res_handle.json_resource});
        return;
    };

    const parsed = std.json.parseFromSlice(
        JSONRoom,
        firefly.api.ALLOC,
        json,
        .{ .ignore_unknown_fields = true },
    ) catch unreachable;
    defer parsed.deinit();

    const jsonTileMapping: JSONRoom = parsed.value;

    // check if tile map with name already exits. If so, do nothing
    // TODO hot reload here?
    if (game.Room.byName(jsonTileMapping.name) != null)
        return;

    const room = game.Room.new(.{
        .name = api.NamePool.alloc(jsonTileMapping.name).?,
        .bounds = utils.parseRectF(jsonTileMapping.bounds).?,
        .start_scene_ref = api.NamePool.alloc(jsonTileMapping.start_scene),
        .end_scene_ref = api.NamePool.alloc(jsonTileMapping.end_scene),
    });

    for (0..jsonTileMapping.tile_sets.len) |i| {
        _ = room.addTaskByName(
            game.Tasks.JSON_LOAD_TILE_SET,
            api.CompositeLifeCycle.LOAD,
            .{
                .{ game.TaskAttributes.FILE_RESOURCE, jsonTileMapping.tile_sets[i].file.? },
            },
        );
    }

    _ = room.addTaskByName(
        game.Tasks.JSON_LOAD_TILE_MAPPING,
        api.CompositeLifeCycle.LOAD,
        .{
            .{ game.TaskAttributes.FILE_RESOURCE, jsonTileMapping.tile_map.file.? },
            .{ game.TaskAttributes.VIEW_NAME, view_name },
        },
    );

    // TODO add objects as activation tasks
    if (jsonTileMapping.objects) |objects| {
        for (0..objects.len) |i| {
            var attributes = api.Attributes.new(.{});

            attributes.set(game.TaskAttributes.NAME, objects[i].name);
            attributes.set(game.TaskAttributes.VIEW_NAME, view_name);
            if (objects[i].layer) |layer|
                attributes.set(game.TaskAttributes.LAYER_NAME, layer);
            if (objects[i].position) |position|
                attributes.set(game.TaskAttributes.POSITION, position);
            if (objects[i].attributes) |attr| {
                for (0..attr.len) |ai| {
                    attributes.set(attr[ai].name, attr[ai].value);
                }
            }

            _ = room.addTaskByName(
                api.NamePool.alloc(objects[i].build_task).?,
                api.CompositeLifeCycle.LOAD,
                attributes,
            );
        }
    }
}
