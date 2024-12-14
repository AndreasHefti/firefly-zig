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
//// game json init
//////////////////////////////////////////////////////////////

var initialized = false;
var dispose_json_tasks = false;
var dispose_tiled_tasks = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // dispose tasks
    if (dispose_json_tasks) {
        api.Task.Naming.dispose(game.Tasks.JSON_LOAD_ROOM);
        api.Task.Naming.dispose(game.Tasks.JSON_LOAD_TILE_MAPPING);
        api.Task.Naming.dispose(game.Tasks.JSON_LOAD_TILE_SET);
        api.Task.Naming.dispose(game.Tasks.JSON_LOAD_WORLD);
        dispose_json_tasks = false;
    }

    if (dispose_tiled_tasks) {
        api.Task.Naming.dispose(game.Tasks.JSON_LOAD_TILED_TILE_SET);
        dispose_tiled_tasks = false;
    }
}

//////////////////////////////////////////////////////////////
//// Firefly JSON API
//////////////////////////////////////////////////////////////

pub fn initJSONTasks() void {
    _ = api.Task.Component.new(.{
        .name = game.Tasks.JSON_LOAD_TILE_SET,
        .function = loadTileSetFromJSONTask,
    });

    _ = api.Task.Component.new(.{
        .name = game.Tasks.JSON_LOAD_TILE_MAPPING,
        .function = loadTileMappingFromJSONTask,
    });

    _ = api.Task.Component.new(.{
        .name = game.Tasks.JSON_LOAD_ROOM,
        .function = loadRoomFromJSONTask,
    });

    _ = api.Task.Component.new(.{
        .name = game.Tasks.JSON_LOAD_WORLD,
        .function = loadWorldFromJSONTask,
    });

    dispose_json_tasks = true;
}

pub const JSONFileTypes = struct {
    const WORLD = "World";
    const ROOM = "Room";
    const TILE_MAP = "TileMap";
    const TILE_SET = "TileSet";
};

pub const JSONAttribute = struct {
    name: String,
    value: String,
};

pub fn parseJSONFromFile(file: String, decryption_pwd: ?String, comptime T: type) T {
    const json = api.loadFromFile(file, decryption_pwd);
    const parsed = std.json.parseFromSlice(
        T,
        firefly.api.LOAD_ALLOC,
        json,
        .{ .ignore_unknown_fields = true },
    ) catch unreachable;
    return parsed.value;
}

pub fn parseJSONFromAttributes(attributes_id: ?Index, file_attribute: ?String, comptime T: type) T {
    if (attributes_id == null)
        @panic("No attributes provided");

    var attrs = api.Attributes.Component.byId(attributes_id.?);
    var json: String = undefined;

    if (file_attribute) |fa| {
        if (attrs.get(fa)) |file| {
            json = firefly.api.loadFromFile(file, attrs.get(game.TaskAttributes.JSON_RESOURCE_DECRYPT_PWD));
        } else {
            json = attrs.get(game.TaskAttributes.JSON_RESOURCE) orelse
                @panic("No JSON_RESOURCE attribute found");
        }
    } else {
        json = attrs.get(game.TaskAttributes.JSON_RESOURCE) orelse
            @panic("No JSON_RESOURCE attribute found");
    }

    const parsed = std.json.parseFromSlice(
        T,
        firefly.api.LOAD_ALLOC,
        json,
        .{ .ignore_unknown_fields = true },
    ) catch unreachable;
    return parsed.value;
}

fn checkFileType(json: anytype, file_type: String) void {
    if (json.file_type) |ft|
        if (!utils.stringEquals(ft, file_type))
            utils.panic(api.ALLOC, "File type mismatch, expected type {s}", .{file_type});
}

//////////////////////////////////////////////////////////////
//// JSON Binding
//////////////////////////////////////////////////////////////

/// Refers a component of context specific kind that can be loaded from file.
/// Usually a load task shall check if the referenced component with "name" already exists.
/// If so, and "update_task" is set too, update if given task.
/// If component is not loaded yet, load the component with given load_task or default task
pub const Resource = struct {
    name: String,
    file: String,
    load_task: ?String = null,
};

//////////////////////////////////////////////////////////////
//// Default TileSet JSON Binding
//////////////////////////////////////////////////////////////
///  {
///      "file_type": "TileSet",
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
    props: String, // "pos_x,pos_y|?flip_x|?flip_y|?contact_material_type|?contact_mask|?groups[g1,g3,...]"
    animation: ?String = null, // "duration,pos_x,pos_y,flip_x,flip_y|duration,pos_x,pos_y,flip_x,flip_y|..."
};

pub const JSONTileSet = struct {
    file_type: ?String = null,
    name: String,
    texture: Resource,
    tile_width: usize,
    tile_height: usize,
    tiles: []const JSONTile,
};

fn loadTileSetFromJSONTask(ctx: *api.CallContext) void {
    const jsonTileSet = parseJSONFromAttributes(
        ctx.attributes_id,
        game.TaskAttributes.JSON_RESOURCE_TILE_SET_FILE,
        JSONTileSet,
    );

    checkFileType(jsonTileSet, JSONFileTypes.TILE_SET);
    const tile_set_id = loadTileSet(jsonTileSet);

    if (ctx.c_ref_callback) |callback|
        callback(game.TileSet.Component.getReference(tile_set_id, true).?, ctx);
}

fn loadTileSet(jsonTileSet: JSONTileSet) Index {
    // check if tile set already exists. If so, do nothing
    // TODO hot reload here?
    if (game.TileSet.Naming.exists(jsonTileSet.name))
        return game.TileSet.Naming.getId(jsonTileSet.name);

    // check texture and load or create if needed
    if (!graphics.Texture.Component.existsByName(jsonTileSet.texture.name)) {
        if (jsonTileSet.texture.load_task) |lt| {
            api.Task.runTaskByName(lt);
        } else {
            _ = graphics.Texture.Component.newActive(.{
                .name = utils.NamePool.alloc(jsonTileSet.texture.name).?,
                .resource = utils.NamePool.alloc(jsonTileSet.texture.file).?,
                .is_mipmap = false,
            });
        }
    }
    // check Texture exists now
    if (!graphics.Texture.Component.existsByName(jsonTileSet.texture.name))
        utils.panic(api.ALLOC, "Failed to find/load texture: {any}", .{jsonTileSet.texture});

    const tile_width: Float = utils.usize_f32(jsonTileSet.tile_width);
    const tile_height: Float = utils.usize_f32(jsonTileSet.tile_height);

    // create TileSet from jsonTileSet
    var tile_set = game.TileSet.Component.newAndGet(.{
        .name = utils.NamePool.alloc(jsonTileSet.name),
        .texture_name = utils.NamePool.alloc(jsonTileSet.texture.name).?,
        .tile_width = tile_width,
        .tile_height = tile_height,
    });

    // create all tile templates for tile set
    for (0..jsonTileSet.tiles.len) |i| {
        var it = utils.StringPropertyIterator.new(jsonTileSet.tiles[i].props);

        if (it.nextPosF()) |tex_pos| {
            var tile_template: game.TileTemplate = .{
                .name = utils.NamePool.alloc(jsonTileSet.tiles[i].name),
                .sprite_data = .{
                    .texture_pos = .{
                        tex_pos[0] * tile_width,
                        tex_pos[1] * tile_height,
                    },
                    .flip_x = it.nextBoolean(),
                    .flip_y = it.nextBoolean(),
                },
                .contact_material_type = it.nextAspect(physics.ContactMaterialAspectGroup),
                .contact_mask_name = utils.NamePool.alloc(if (it.nextBoolean()) jsonTileSet.tiles[i].name else null),
                .groups = it.nextName(),
            };

            if (jsonTileSet.tiles[i].animation) |a| {
                var it_a1 = std.mem.split(u8, a, "|");
                while (it_a1.next()) |frame| {
                    if (frame.len == 0)
                        continue;

                    var it_a2 = std.mem.split(u8, frame, ",");
                    tile_template = tile_template.withAnimationFrame(.{
                        .duration = utils.parseUsize(it_a2.next().?),
                        .sprite_data = .{
                            .texture_pos = .{
                                utils.parseFloat(it_a2.next()) * tile_width,
                                utils.parseFloat(it_a2.next()) * tile_height,
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
    return tile_set.id;
}

//////////////////////////////////////////////////////////////
//// Default TileSetMapping JSON Binding
//////////////////////////////////////////////////////////////
/// {
///     "file_type": "TileSet",
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
    file_type: ?String = null,
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

fn loadTileMappingFromJSONTask(ctx: *api.CallContext) void {
    const jsonTileMapping = parseJSONFromAttributes(
        ctx.attributes_id,
        game.TaskAttributes.JSON_RESOURCE_TILE_MAP_FILE,
        JSONTileMapping,
    );

    const view_name = ctx.attribute(game.TaskAttributes.VIEW_NAME);
    checkFileType(jsonTileMapping, JSONFileTypes.TILE_MAP);
    const tile_mapping_id = loadTileMapping(
        jsonTileMapping,
        view_name,
    );

    if (ctx.c_ref_callback) |callback|
        callback(game.TileMapping.Component.getReference(tile_mapping_id, true).?, ctx);
}

fn loadTileMapping(jsonTileMapping: JSONTileMapping, view_name: String) Index {
    // check if tile map with name already exits. If so, do nothing
    // TODO hot reload here?
    if (game.TileMapping.Naming.exists(jsonTileMapping.name))
        return game.TileMapping.Naming.getId(jsonTileMapping.name);

    // prepare view
    const view_id = graphics.View.Naming.getId(view_name);
    var tile_mapping = game.TileMapping.Component.newAndGet(.{
        .name = utils.NamePool.alloc(jsonTileMapping.name),
        .view_id = view_id,
    });

    // process tile sets and make code offset mapping, if not exists, load it
    var code_offset: Index = 1;
    var code_offset_mapping = utils.DynIndexArray.new(api.ALLOC, 10);
    defer code_offset_mapping.deinit();

    for (0..jsonTileMapping.tile_sets.len) |i| {
        var tile_set_def = jsonTileMapping.tile_sets[i];
        if (!game.TileSet.Naming.exists(tile_set_def.resource.name)) {
            // load tile set from file
            if (tile_set_def.resource.load_task) |load_task| {
                api.Task.runTaskByName(load_task);
            } else {
                api.Task.runTaskByNameWith(
                    game.Tasks.JSON_LOAD_TILE_SET,
                    .{ .attributes_id = api.Attributes.newGet(
                        null,
                        .{
                            .{ game.TaskAttributes.JSON_RESOURCE_TILE_SET_FILE, tile_set_def.resource.file },
                        },
                    ).id },
                );
            }
        }

        if (tile_set_def.code_offset == null)
            tile_set_def.code_offset = code_offset;

        code_offset = code_offset + game.TileSet.Naming.byName(tile_set_def.resource.name).?.tile_templates.size();
    }

    // process tile layer
    for (0..jsonTileMapping.layer_mapping.len) |i| {
        const layer_mapping = jsonTileMapping.layer_mapping[i];

        // get involved layer, if name exists but layer not yet, create one
        var layer_id: ?Index = null;
        if (graphics.Layer.Naming.exists(layer_mapping.layer_name)) {
            layer_id = graphics.Layer.Naming.getId(layer_mapping.layer_name);
        } else {
            layer_id = graphics.Layer.Component.new(.{
                .name = utils.NamePool.alloc(layer_mapping.layer_name),
                .view_id = view_id,
                .order = i,
            });
        }

        // create tile layer data
        var tile_layer_data = tile_mapping.withTileLayerData(.{
            .layer = utils.NamePool.alloc(layer_mapping.layer_name).?,
            .tint = utils.parseColor(layer_mapping.tint_color).?,
            .blend = utils.enumByName(BlendMode, layer_mapping.blend_mode),
            .parallax = utils.parsePosF(layer_mapping.parallax_factor),
            .offset = utils.parsePosF(layer_mapping.offset),
        });

        // add tile set references to tile layer data
        var tile_set_ref_it = std.mem.splitScalar(u8, layer_mapping.tile_sets_refs, ',');
        while (tile_set_ref_it.next()) |tile_set_name| {
            for (0..jsonTileMapping.tile_sets.len) |ii| {
                const tile_set_ref = jsonTileMapping.tile_sets[ii];
                if (utils.stringEquals(tile_set_ref.resource.name, tile_set_name)) {
                    _ = tile_layer_data.withTileSetMapping(.{
                        .tile_set_name = utils.NamePool.alloc(tile_set_ref.resource.name).?,
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
            .name = utils.NamePool.alloc(json_grid.name).?,
            .layer = utils.NamePool.alloc(json_grid.layer).?,
            .world_position = utils.parsePosF(json_grid.position) orelse .{ 0, 0 },
            .spherical = json_grid.spherical,
            .dimensions = .{
                json_grid.grid_tile_width,
                json_grid.grid_tile_height,
                json_grid.tile_width,
                json_grid.tile_height,
            },
            .codes = utils.NamePool.alloc(json_grid.codes).?,
        });
    }

    return tile_mapping.id;
}

//////////////////////////////////////////////////////////////
//// Default Room JSON Binding
//////////////////////////////////////////////////////////////
/// {
///     "file_type": "Room,"
///     "name": "Room1",
///     "start_scene": "scene1",
///     "end_scene": "scene2",
///     "attributes": [
///         { "name": "test_attribute1", "value": "attr_value1"}
///     ]
///     "tile_sets": [
///         { "name": "TestTileSet", "file": "resources/example_tileset.json" }
///     ],
///     "tasks": [
///          {
///               "name": "task1",
///               "life_cycle": "LOAD or ACTIVATION or DEACTIVATION or DISPOSE",
///               "attributes": [
///                    { "name": "task_attribute1", "value": "attr_value1"}
///              ]
///          }
///     ],
///
/// NOTE: either of
///     "tile_mapping_file": { "name": "TileMapRoom1", "file": "resources/example_tilemap1.json" },
///     "tile_mapping": {
///         TileSetMapping JSON
///     }
///
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
    file_type: ?String = null,
    name: String,
    bounds: String,
    start_scene: ?String = null,
    end_scene: ?String = null,
    tasks: ?[]const JSONTask = null,
    attributes: ?[]const JSONAttribute = null,
    tile_mapping_file: ?Resource = null,
    tile_mapping: ?JSONTileMapping = null,
    objects: ?[]const JSONRoomObject = null,
};

pub const JSONTask = struct {
    name: String,
    life_cycle: String,
    attributes: ?[]const JSONAttribute = null,
};

pub const JSONRoomObject = struct {
    name: String,
    object_type: String,
    build_task: String,
    layer: ?String = null,
    position: ?String = null,
    attributes: ?[]const JSONAttribute = null,
};

fn loadRoomFromJSONTask(ctx: *api.CallContext) void {
    const jsonRoom = parseJSONFromAttributes(
        ctx.attributes_id,
        game.TaskAttributes.JSON_RESOURCE_ROOM_FILE,
        JSONRoom,
    );

    const room_id = loadRoom(jsonRoom, ctx);
    // add composite owned reference if requested
    if (ctx.c_ref_callback) |callback| {
        if (api.Composite.Component.getReference(room_id, true)) |ref| {
            var r = ref;
            r.activation = null;
            callback(r, ctx);
        }
    }
}

fn loadRoom(jsonRoom: JSONRoom, ctx: *api.CallContext) Index {
    const view_name = ctx.attribute(game.TaskAttributes.VIEW_NAME);
    checkFileType(jsonRoom, JSONFileTypes.ROOM);

    // TODO hot reload here?
    if (game.Room.Component.byName(jsonRoom.name) != null)
        return game.Room.Component.idByName(jsonRoom.name).?;

    const room_id = game.Room.Component.new(.{
        .name = utils.NamePool.alloc(jsonRoom.name).?,
        .bounds = utils.parseRectF(jsonRoom.bounds).?,
        .start_scene_ref = utils.NamePool.alloc(jsonRoom.start_scene),
        .end_scene_ref = utils.NamePool.alloc(jsonRoom.end_scene),
    });

    if (jsonRoom.attributes) |a| {
        for (0..a.len) |i|
            game.Room.Composite.Attributes.setAttribute(
                room_id,
                a[i].name,
                a[i].value,
            );
    }

    addAttributes(room_id, jsonRoom.attributes);
    addTasks(room_id, jsonRoom.tasks);

    if (jsonRoom.tile_mapping_file) |tile_mapping_file| {
        game.Room.Composite.addTaskByName(
            room_id,
            tile_mapping_file.load_task orelse game.Tasks.JSON_LOAD_TILE_MAPPING,
            api.CompositeLifeCycle.LOAD,
            api.Attributes.newGet(
                null,
                .{
                    .{ game.TaskAttributes.JSON_RESOURCE_TILE_MAP_FILE, tile_mapping_file.file },
                    .{ game.TaskAttributes.VIEW_NAME, view_name },
                },
            ).id,
        );
    } else if (jsonRoom.tile_mapping) |tm| {
        const tileMappingJSON = std.json.stringifyAlloc(api.ALLOC, tm, .{}) catch unreachable;
        defer api.ALLOC.free(tileMappingJSON);

        game.Room.Composite.addTaskByName(
            room_id,
            game.Tasks.JSON_LOAD_TILE_MAPPING,
            api.CompositeLifeCycle.LOAD,
            api.Attributes.newGet(
                null,
                .{
                    .{ game.TaskAttributes.JSON_RESOURCE, tileMappingJSON },
                    .{ game.TaskAttributes.VIEW_NAME, view_name },
                },
            ).id,
        );
    } else {
        @panic("Neither tile_mapping_file nor tile_mapping property found");
    }

    // add objects as activation tasks
    if (jsonRoom.objects) |objects| {
        for (0..objects.len) |i| {
            var attributes = api.Attributes.newGet(
                utils.NamePool.format("room_object_{s}_{s}", .{ jsonRoom.name, objects[i].name }),
                .{
                    .{ game.TaskAttributes.NAME, objects[i].name },
                    .{ game.TaskAttributes.VIEW_NAME, view_name },
                },
            );

            if (objects[i].attributes) |attr| {
                for (0..attr.len) |ai|
                    attributes.set(attr[ai].name, attr[ai].value);
            }

            game.Room.Composite.addTaskByName(
                room_id,
                utils.NamePool.alloc(objects[i].build_task).?,
                api.CompositeLifeCycle.ACTIVATE,
                attributes.id,
            );
        }
    }

    return room_id;
}

//////////////////////////////////////////////////////////////
//// Default World JSON Binding
//////////////////////////////////////////////////////////////
////
//// {
////    "file_type": "World",
////    "name": "World2",
////    "room_transitions": [
////        {
////            "name": "enterRoom",
////            "builder": "simple_room_transition_scene",
////            "attributes": [
////                { "name": "NAME", "value": "enterRoom"}
////            ]
////        },
////        {
////            "name": "exitRoom",
////            "builder": "simple_room_transition_scene",
////            "attributes": [
////                { "name": "NAME", "value": "exitRoom"},
////                { "name": "exit", "value": "true"}
////            ]
////        }
////    ],
///     "tasks": [
///          {
///               "name": "task1",
///               "life_cycle": "LOAD or ACTIVATION or DEACTIVATION or DISPOSE",
///               "attributes": [
///                    { "name": "task_attribute1", "value": "attr_value1"}
///              ]
///          }
///     ],
////    "attributes": [
////        { "name": "description", "value": "This is a test world with three rooms."}
////    ],
////    "rooms": [
////        {
////            "name": "Room1",
////            "file": { "name": "Room1", "file": "resources/example_room1.json" },
////            "attributes": [
////                { "name": "description", "value": "This es the entrance room."}
////            ]
////        },
////        {
////            "name": "Room2",
////            "file": { "name": "Room1", "file": "resources/example_room2.json" }
////        },
////        {
////            "name": "Room3",
////            "file": { "name": "Room1", "file": "resources/example_room3.json" }
////        }
////    ]
//// }
///////////////////////////////////////////////////////////////

pub const JSONWorld = struct {
    file_type: ?String = null,
    name: String,
    room_transitions: ?[]const JSONRoomTransition = null,
    tasks: ?[]const JSONTask = null,
    attributes: ?[]const JSONAttribute = null,
    rooms: []JSONRoomRef,
};

pub const JSONRoomRef = struct {
    name: String,
    file: Resource,
    attributes: ?[]const JSONAttribute = null,
};

pub const JSONRoomTransition = struct {
    name: String,
    builder: String,
    attributes: ?[]const JSONAttribute = null,
};

fn loadWorldFromJSONTask(ctx: *api.CallContext) void {
    const jsonWorld = parseJSONFromAttributes(
        ctx.attributes_id,
        game.TaskAttributes.JSON_RESOURCE_WORLD_FILE,
        JSONWorld,
    );

    checkFileType(jsonWorld, JSONFileTypes.WORLD);

    const view_name = ctx.attribute(game.TaskAttributes.VIEW_NAME);
    const world_id = game.World.Component.new(.{
        .name = utils.NamePool.alloc(jsonWorld.name).?,
    });

    if (jsonWorld.room_transitions) |room_transitions| {
        for (0..room_transitions.len) |i| {
            var attributes: *api.Attributes = api.Attributes.newGet(
                utils.NamePool.alloc(room_transitions[i].name),
                .{
                    .{ game.TaskAttributes.NAME, room_transitions[i].name },
                    .{ game.TaskAttributes.VIEW_NAME, view_name },
                },
            );

            if (room_transitions[i].attributes) |a| {
                for (0..a.len) |ia|
                    attributes.set(a[ia].name, a[ia].value);
            }

            game.World.Composite.addTaskByName(
                world_id,
                game.Tasks.SIMPLE_ROOM_TRANSITION_SCENE_BUILDER,
                api.CompositeLifeCycle.LOAD,
                attributes.id,
            );
        }
    }

    addAttributes(world_id, jsonWorld.attributes);
    addTasks(world_id, jsonWorld.tasks);

    for (0..jsonWorld.rooms.len) |i| {
        game.World.Composite.addTaskByName(
            world_id,
            game.Tasks.JSON_LOAD_ROOM,
            api.CompositeLifeCycle.LOAD,
            api.Attributes.newGet(
                null,
                .{
                    .{ game.TaskAttributes.JSON_RESOURCE_ROOM_FILE, utils.NamePool.alloc(jsonWorld.rooms[i].file.file).? },
                    .{ game.TaskAttributes.VIEW_NAME, view_name },
                },
            ).id,
        );
    }
}

fn addAttributes(c_id: Index, attributes: ?[]const JSONAttribute) void {
    if (attributes) |a| {
        for (0..a.len) |i|
            game.World.Composite.Attributes.setAttribute(
                c_id,
                a[i].name,
                a[i].value,
            );
    }
}

fn addTasks(c_id: Index, tasks: ?[]const JSONTask) void {
    if (tasks) |tsk| {
        for (0..tsk.len) |i| {
            if (!api.Task.Naming.exists(tsk[i].name)) {
                std.log.warn("Task with name: {s} does not exist!", .{tsk[i].name});
                continue;
            }

            var attr_id: ?Index = null;
            if (tsk[i].attributes) |a| {
                attr_id = api.Attributes.Component.new(.{});
                for (0..a.len) |a_id|
                    game.Room.Composite.Attributes.setAttribute(
                        c_id,
                        a[a_id].name,
                        a[a_id].value,
                    );
            }

            game.Room.Composite.addTaskByName(
                c_id,
                utils.NamePool.alloc(tsk[i].name).?,
                utils.enumByName(api.CompositeLifeCycle, tsk[i].life_cycle).?,
                attr_id,
            );
        }
    }
}

//////////////////////////////////////////////////////////////
//// Tiled JSON API
//////////////////////////////////////////////////////////////

pub fn initTiledTasks() void {
    _ = api.Task.Component.new(.{
        .name = game.Tasks.JSON_LOAD_TILED_TILE_SET,
        .function = loadTiledTileSetTask,
    });
    _ = api.Task.Component.new(.{
        .name = game.Tasks.JSON_LOAD_TILED_ROOM,
        .function = loadTiledRoomTask,
    });

    dispose_tiled_tasks = true;
}

const P_NAME_ATLAS_NAME: String = "atlas_name";
const P_NAME_ATLAS_FILE: String = "atlas_file";
const P_NAME_NAME: String = "name";
const P_NAME_PROPS: String = "props";
const P_NAME_ANIMATION: String = "animation";

const P_NAME_TILE_SETS: String = "tile_sets";
const P_NAME_TASKS: String = "tasks";
const P_NAME_START_SCENE: String = "start_scene";
const P_NAME_END_SCENE: String = "end_scene";
const P_NAME_ATTRIBUTES: String = "attributes";
const P_NAME_LIFE_CYCLE: String = "life_cycle";
const P_NAME_OFFSET: String = "offset";
const P_NAME_FILE: String = "file";
const P_NAME_LOAD_TASK: String = "load_task";

const P_NAME_TINT_COLOR: String = "tint_color";
const P_NAME_BLEND_MODE: String = "blend_mode";
const P_NAME_TILE_SET_REFS: String = "tile_sets";
const P_NAME_BUILD_TASK: String = "build_task";
const P_NAME_LAYER: String = "layer";
const P_NAME_BOUNDS: String = "bounds";

const TILE_LAYER_NAME: String = "tilelayer";
const OBJECT_GROUP_NAME: String = "objectgroup";

pub fn getPropertyValue(properties: []const TiledProperty, name: String) ?String {
    for (0..properties.len) |i| {
        if (utils.stringEquals(name, properties[i].name) and properties[i].value.len > 0)
            return properties[i].value;
    }
    return null;
}

pub fn toJSONAttributes(attributes_str: String) []const JSONAttribute {
    var a_it = utils.StringAttributeIterator.new(attributes_str);
    var a_list = std.ArrayList(JSONAttribute).init(api.LOAD_ALLOC);
    while (a_it.next()) |r| {
        var t_attr = a_list.addOne() catch unreachable;
        t_attr.name = r.name;
        t_attr.value = r.value;
    }
    return a_list.toOwnedSlice() catch unreachable;
}

pub fn getAttributeValue(attrs: []const JSONAttribute, name: String) ?String {
    for (0..attrs.len) |i| {
        if (utils.stringEquals(name, attrs[i].name) and attrs[i].value.len > 0)
            return attrs[i].value;
    }
    return null;
}

// Tiled Tile Set JSON mapping

pub const TiledProperty = struct {
    name: String,
    value: String,
};

pub const TiledTile = struct {
    id: Index,
    properties: []const TiledProperty,
};

pub const TiledTileSet = struct {
    name: String,
    image: String,
    columns: usize,
    properties: []const TiledProperty,
    tilecount: usize,
    tileheight: usize,
    tilewidth: usize,
    tiles: []const TiledTile,
};

pub fn convertTiledTileSet(tiled: TiledTileSet) JSONTileSet {
    const tiles: []JSONTile = api.LOAD_ALLOC.alloc(JSONTile, tiled.tiles.len) catch undefined;

    for (0..tiled.tiles.len) |i| {
        const tile = tiled.tiles[i];
        const index = tile.id;
        tiles[index] = JSONTile{
            .name = getPropertyValue(tile.properties, P_NAME_NAME).?,
            .props = getPropertyValue(tile.properties, P_NAME_PROPS).?,
            .animation = getPropertyValue(tile.properties, P_NAME_ANIMATION),
        };
    }

    return JSONTileSet{
        .file_type = JSONFileTypes.TILE_SET,
        .name = tiled.name,
        .texture = Resource{
            .name = getPropertyValue(tiled.properties, P_NAME_ATLAS_NAME).?,
            .file = getPropertyValue(tiled.properties, P_NAME_ATLAS_FILE).?,
        },
        .tile_width = tiled.tilewidth,
        .tile_height = tiled.tileheight,
        .tiles = tiles,
    };
}

fn loadTiledTileSetTask(ctx: *api.CallContext) void {
    const tiled_tile_set = parseJSONFromAttributes(
        ctx.attributes_id,
        game.TaskAttributes.JSON_RESOURCE_TILE_SET_FILE,
        TiledTileSet,
    );
    const tile_set = convertTiledTileSet(tiled_tile_set);
    const tile_set_id = loadTileSet(tile_set);

    if (ctx.c_ref_callback) |callback|
        callback(game.TileSet.Component.getReference(tile_set_id, true).?, ctx);
}

// // Tiled TileMap / Room JSON Mapping

pub const TiledTileMap = struct {
    width: usize,
    height: usize,
    tilewidth: usize,
    tileheight: usize,
    infinite: bool,
    properties: []const TiledProperty,
    layers: []const TiledMapLayer,
};

pub const TiledMapLayer = struct {
    type: String,
    name: String,
    x: Float,
    y: Float,
    width: ?usize = null,
    height: ?usize = null,
    visible: bool,
    opacity: Float,
    parallaxx: ?Float = null,
    parallaxy: ?Float = null,
    data: ?[]const Index = null,
    objects: ?[]const TiledObject = null,
    properties: ?[]const TiledProperty = null,
};

pub const TiledObject = struct {
    type: String,
    name: String,
    visible: bool,
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    rotation: Float,
    properties: []const TiledProperty,
};

pub fn convertTiledTileMapToJSONRoom(tiles_tile_map: TiledTileMap) JSONRoom {

    // global attributes
    const attr_string = getPropertyValue(tiles_tile_map.properties, P_NAME_ATTRIBUTES).?;
    const attrs = toJSONAttributes(attr_string);

    // tasks...
    var task_list = std.ArrayList(JSONTask).init(api.LOAD_ALLOC);
    if (getPropertyValue(tiles_tile_map.properties, P_NAME_TASKS)) |taks_string| {
        var task_it = utils.StringListIterator.new(taks_string);
        while (task_it.next()) |task_attr_str| {
            const task_attrs = toJSONAttributes(task_attr_str);
            var new = task_list.addOne() catch unreachable;
            new.name = getAttributeValue(task_attrs, P_NAME_NAME).?;
            new.life_cycle = getAttributeValue(task_attrs, P_NAME_LIFE_CYCLE).?;
            new.attributes = task_attrs;
        }
    }

    return JSONRoom{
        .file_type = JSONFileTypes.ROOM,
        .name = getPropertyValue(tiles_tile_map.properties, P_NAME_NAME).?,
        .bounds = utils.NamePool.format("0,0,{d},{d}", .{
            tiles_tile_map.width * tiles_tile_map.tilewidth,
            tiles_tile_map.height * tiles_tile_map.tileheight,
        }),
        .start_scene = getPropertyValue(tiles_tile_map.properties, P_NAME_START_SCENE),
        .end_scene = getPropertyValue(tiles_tile_map.properties, P_NAME_END_SCENE),
        .tasks = if (task_list.items.len > 0) task_list.toOwnedSlice() catch unreachable else null,
        .attributes = attrs,
        .tile_mapping = convertTiledTileMap(tiles_tile_map),
        .objects = convertTiledObjects(tiles_tile_map.layers),
    };
}

fn loadTiledRoomTask(ctx: *api.CallContext) void {
    const tiles_tile_map = parseJSONFromAttributes(
        ctx.attributes_id,
        game.TaskAttributes.JSON_RESOURCE_ROOM_FILE,
        TiledTileMap,
    );

    const jsonRoom = convertTiledTileMapToJSONRoom(tiles_tile_map);

    // load tile-sets from Tiled files so they are not tried to be loaded from regular JSON files later on
    if (jsonRoom.tile_mapping) |tile_mapping| {
        for (0..tile_mapping.tile_sets.len) |i| {
            api.Task.runTaskByNameWith(
                game.Tasks.JSON_LOAD_TILED_TILE_SET,
                .{ .attributes_id = api.Attributes.newGet(null, .{
                    .{
                        game.TaskAttributes.JSON_RESOURCE_TILE_SET_FILE,
                        tile_mapping.tile_sets[i].resource.file,
                    },
                }).id },
            );
        }
    }

    const room_id = loadRoom(jsonRoom, ctx);
    if (ctx.c_ref_callback) |callback|
        callback(game.TileSet.Component.getReference(room_id, true).?, ctx);
}

fn convertTiledTileMap(tiled_tile_map: TiledTileMap) JSONTileMapping {
    var grid_list = std.ArrayList(JSONTileGrid).init(api.LOAD_ALLOC);
    var layer_list = std.ArrayList(TileLayerMapping).init(api.LOAD_ALLOC);
    const layers = tiled_tile_map.layers;

    for (0..layers.len) |i| {
        if (utils.stringEquals(layers[i].type, TILE_LAYER_NAME)) {
            var new_layer = layer_list.addOne() catch unreachable;
            new_layer.layer_name = layers[i].name;
            new_layer.offset = utils.NamePool.format("{d},{d}", .{ layers[i].x, layers[i].y });
            new_layer.parallax_factor = utils.NamePool.format("{d},{d}", .{ layers[i].parallaxx orelse 0, layers[i].parallaxy orelse 0 });
            new_layer.tint_color = getPropertyValue(layers[i].properties.?, P_NAME_TINT_COLOR);
            new_layer.blend_mode = getPropertyValue(layers[i].properties.?, P_NAME_BLEND_MODE);
            new_layer.tile_sets_refs = getPropertyValue(layers[i].properties.?, P_NAME_TILE_SET_REFS).?;

            var new_grid = grid_list.addOne() catch unreachable;
            new_grid.name = layers[i].name; // TODO same as layer?
            new_grid.layer = layers[i].name;
            new_grid.grid_tile_width = layers[i].width.?;
            new_grid.grid_tile_height = layers[i].height.?;
            new_grid.tile_width = tiled_tile_map.tilewidth;
            new_grid.tile_height = tiled_tile_map.tileheight;
            new_grid.position = new_layer.offset orelse "0,0";
            new_grid.spherical = false; // TODO
            new_grid.codes = toCodes(layers[i].data);
        }
    }

    // tile sets...
    var tile_set_list = std.ArrayList(TileSetDef).init(api.LOAD_ALLOC);
    if (getPropertyValue(tiled_tile_map.properties, P_NAME_TILE_SETS)) |tile_sets_string| {
        var tile_set_it = utils.StringListIterator.new(tile_sets_string);
        while (tile_set_it.next()) |tile_set_attr_str| {
            var tile_set_attrs = utils.StringAttributeMap.new(tile_set_attr_str, api.LOAD_ALLOC);
            var new = tile_set_list.addOne() catch unreachable;
            new.code_offset = utils.parseUsize(tile_set_attrs.get(P_NAME_OFFSET));
            new.resource.name = tile_set_attrs.get(P_NAME_NAME);
            new.resource.file = tile_set_attrs.get(P_NAME_FILE);
            new.resource.load_task = tile_set_attrs.getOptinal(P_NAME_LOAD_TASK);
        }
    }

    return JSONTileMapping{
        .name = getPropertyValue(tiled_tile_map.properties, P_NAME_NAME).?,
        .tile_sets = tile_set_list.toOwnedSlice() catch unreachable,
        .tile_grids = grid_list.toOwnedSlice() catch unreachable,
        .layer_mapping = layer_list.toOwnedSlice() catch unreachable,
    };
}

fn toCodes(data: ?[]const Index) String {
    if (data) |d| {
        var buffer = utils.StringBuffer.init(api.LOAD_ALLOC);
        for (0..d.len) |i| {
            if (i > 0)
                buffer.append(",");
            buffer.print("{d}", .{d[i]});
        }
        return utils.NamePool.alloc(buffer.toString()).?;
    }
    @panic("No code data found");
}

fn convertTiledObjects(layers: []const TiledMapLayer) ?[]const JSONRoomObject {
    var list = std.ArrayList(JSONRoomObject).init(api.LOAD_ALLOC);
    for (0..layers.len) |i| {
        if (utils.stringEquals(layers[i].type, OBJECT_GROUP_NAME)) {
            if (layers[i].objects) |object| {
                for (0..object.len) |j| {
                    var new = list.addOne() catch unreachable;
                    new.name = object[j].name;
                    new.object_type = object[j].type;
                    new.attributes = convertObjectAttributes(object[j]);
                    new.build_task = getAttributeValue(new.attributes.?, P_NAME_BUILD_TASK).?;
                    new.layer = getAttributeValue(new.attributes.?, P_NAME_LAYER);
                }
            }
        }
    }
    return list.toOwnedSlice() catch unreachable;
}

fn convertObjectAttributes(object: TiledObject) ?[]const JSONAttribute {
    var list = std.ArrayList(JSONAttribute).init(api.LOAD_ALLOC);
    var bounds = list.addOne() catch unreachable;
    bounds.name = P_NAME_BOUNDS;
    bounds.value = utils.NamePool.format("{d},{d},{d},{d}", .{
        object.x,
        object.y,
        object.width,
        object.height,
    });

    for (0..object.properties.len) |i| {
        var new = list.addOne() catch unreachable;
        new.name = object.properties[i].name;
        new.value = object.properties[i].value;
    }

    return list.toOwnedSlice() catch unreachable;
}
