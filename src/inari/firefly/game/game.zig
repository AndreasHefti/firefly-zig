const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;
const physics = firefly.physics;

const behavior = @import("behavior.zig");
const tile = @import("tile.zig");
const json = @import("json.zig");
const world = @import("world.zig");
const platformer = @import("platformer.zig");

const Vector2f = firefly.utils.Vector2f;
const RectF = firefly.utils.RectF;
const PosF = firefly.utils.PosF;
const Index = firefly.utils.Index;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const String = firefly.utils.String;

//////////////////////////////////////////////////////////////
//// general game package init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    Groups.PAUSEABLE = api.GroupAspectGroup.getAspect("PAUSEABLE");
    // init sub packages
    behavior.init();
    tile.init();
    world.init();
    json.init();
    platformer.init();

    api.Component.Subtype.register(api.Control, SimplePivotCamera, "SimplePivotCamera");

    MaterialTypes.NONE = physics.ContactMaterialAspectGroup.getAspect("NONE");
    MaterialTypes.TERRAIN = physics.ContactMaterialAspectGroup.getAspect("TERRAIN");
    MaterialTypes.PROJECTILE = physics.ContactMaterialAspectGroup.getAspect("PROJECTILE");
    MaterialTypes.WATER = physics.ContactMaterialAspectGroup.getAspect("WATER");
    MaterialTypes.LADDER = physics.ContactMaterialAspectGroup.getAspect("LADDER");
    MaterialTypes.ROPE = physics.ContactMaterialAspectGroup.getAspect("ROPE");
    MaterialTypes.INTERACTIVE = physics.ContactMaterialAspectGroup.getAspect("INTERACTIVE");

    ContactTypes.FULL_CONTACT = physics.ContactTypeAspectGroup.getAspect("FULL_CONTACT");
    ContactTypes.ROOM_TRANSITION = physics.ContactTypeAspectGroup.getAspect("ROOM_TRANSITION");

    // conditions
    _ = api.Condition.Component.new(.{ .name = Conditions.GOES_WEST, .check = goesEast });
    _ = api.Condition.Component.new(.{ .name = Conditions.GOES_EAST, .check = goesWest });
    _ = api.Condition.Component.new(.{ .name = Conditions.GOES_NORTH, .check = goesNorth });
    _ = api.Condition.Component.new(.{ .name = Conditions.GOES_SOUTH, .check = goesSouth });
}

pub fn initJSONIntegration() void {
    json.initJSONTasks();
}

pub fn initTiledIntegration() void {
    initJSONIntegration();
    json.initTiledTasks();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit sub packages
    platformer.deinit();
    json.deinit();
    world.deinit();
    tile.deinit();
    behavior.deinit();
}

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const TileDimensionType = tile.TileDimensionType;
pub const TileAnimationFrame = tile.TileAnimationFrame;
pub const TileSet = tile.TileSet;
pub const SpriteData = tile.SpriteData;
pub const TileTemplate = tile.TileTemplate;
pub const TileMapping = tile.TileMapping;
pub const TileSetMapping = tile.TileSetMapping;
pub const TileLayerData = tile.TileLayerData;

pub const JSONTile = json.JSONTile;
pub const JSONTileSet = json.JSONTileSet;

pub const Player = world.Player;
pub const Room = world.Room;
pub const RoomState = world.RoomState;
pub const World = world.World;
pub const TransitionContactCallback = world.TransitionContactCallback;

pub const PlatformerCollisionResolver = platformer.PlatformerCollisionResolver;
pub const SimplePlatformerHorizontalMoveControl = platformer.SimplePlatformerHorizontalMoveControl;
pub const SimplePlatformerJumpControl = platformer.SimplePlatformerJumpControl;

pub const BehaviorFunction = behavior.BehaviorFunction;
pub const BehaviorNode = behavior.BehaviorNode;
pub const BehaviorTreeBuilder = behavior.BehaviorTreeBuilder;
pub const EBehavior = behavior.EBehavior;
pub const BehaviorSystem = behavior.BehaviorSystem;
pub const SequenceFunction = behavior.sequence;
pub const FallbackFunction = behavior.fallback;
pub const ParallelFunction = behavior.parallel;

pub const Groups = struct {
    pub var PAUSEABLE: api.GroupAspect = undefined;
};

pub const TaskAttributes = struct {
    pub const NAME: String = "name";
    /// Name of the involved View
    pub const VIEW_NAME: String = "view";
    /// Name of involved Layer
    pub const LAYER_NAME: String = "layer";
    /// Position, Format: "x,y"
    pub const POSITION: String = "position";
    /// Bounds, Format: "x,y,width,height"
    pub const BOUNDS: String = "bounds";
    /// Arbitrary properties, Format: "prop1|prop2|prop3|..."
    pub const PROPERTIES: String = "props";

    /// File resource name. If this is set, a task shall try to load the data from referenced file
    //pub const FILE_RESOURCE = "FILE_RESOURCE";
    /// JSON String resource reference. If this is set, a task shall interpret this as JSON Sting
    /// and try to load defined components from JSON
    pub const JSON_RESOURCE = "JSON_RESOURCE";

    pub const JSON_RESOURCE_TILE_SET_FILE: String = "JSON_RESOURCE_TILE_SET_FILE";
    pub const JSON_RESOURCE_TILE_MAP_FILE: String = "JSON_RESOURCE_TILE_MAP_FILE";
    pub const JSON_RESOURCE_ROOM_FILE: String = "JSON_RESOURCE_ROOM_FILE";
    pub const JSON_RESOURCE_WORLD_FILE: String = "JSON_RESOURCE_WORLD_FILE";

    // The room name within the context
    pub const ROOM_NAME: String = "room";
};

pub const Tasks = struct {
    pub const JSON_LOAD_TILE_SET: String = "load_tile_set_json_default";
    pub const JSON_LOAD_TILE_MAPPING: String = "load_tile_mapping_json_default";
    pub const JSON_LOAD_ROOM: String = "load_room_json_default";
    pub const JSON_LOAD_WORLD: String = "load_world_json_default";

    pub const JSON_LOAD_TILED_TILE_SET: String = "load_tiled_tile_set_json_default";
    pub const JSON_LOAD_TILED_TILE_MAPPING: String = "load_tiled_tile_mapping_json_default";
    pub const JSON_LOAD_TILED_ROOM: String = "load_tiled_room_json_default";

    pub const SIMPLE_ROOM_TRANSITION_SCENE_BUILDER: String = "simpleRoomTransitionBuilder";
    pub const ROOM_TRANSITION_BUILDER: String = "room_transition_builder";
};

pub const MaterialTypes = struct {
    pub var NONE: physics.ContactMaterialAspect = undefined;
    pub var TERRAIN: physics.ContactMaterialAspect = undefined;
    pub var PROJECTILE: physics.ContactMaterialAspect = undefined;
    pub var WATER: physics.ContactMaterialAspect = undefined;
    pub var LADDER: physics.ContactMaterialAspect = undefined;
    pub var ROPE: physics.ContactMaterialAspect = undefined;

    pub var INTERACTIVE: physics.ContactMaterialAspect = undefined;
};

pub const ContactTypes = struct {
    pub var FULL_CONTACT: physics.ContactTypeAspect = undefined;
    pub var ROOM_TRANSITION: physics.ContactTypeAspect = undefined;
};

pub const Conditions = struct {
    pub const GOES_EAST: String = "GOES_EAST";
    pub const GOES_WEST: String = "GOES_WEST";
    pub const GOES_NORTH: String = "GOES_NORTH";
    pub const GOES_SOUTH: String = "GOES_SOUTH";
};

fn goesEast(ctx: *api.CallContext) bool {
    return physics.EMovement.Component.byId(ctx.id_1).velocity[0] > 0;
}

fn goesWest(ctx: *api.CallContext) bool {
    return physics.EMovement.Component.byId(ctx.id_1).velocity[0] < 0;
}

fn goesNorth(ctx: *api.CallContext) bool {
    return physics.EMovement.Component.byId(ctx.id_1).velocity[1] < 0;
}

fn goesSouth(ctx: *api.CallContext) bool {
    return physics.EMovement.Component.byId(ctx.id_1).velocity[1] > 0;
}

pub const SimpleRoomTransitionScene = world.SimpleRoomTransitionScene;

//////////////////////////////////////////////////////////////
//// Game Pausing API
//////////////////////////////////////////////////////////////
/// de/activate all Entities with BaseGroupAspect.GroupAspect
/// set in Entity groups Kind
///
pub fn pauseGame() void {
    pause(true);
}

pub fn resumeGame() void {
    pause(false);
}

fn pause(p: bool) void {
    var next = api.Entity.Component.nextId(0);
    while (next) |i| {
        next = api.Entity.Component.nextId(i + 1);
        var entity = api.Entity.Component.byId(i);
        var groups = entity.groups orelse continue;
        if (groups.hasAspect(Groups.PAUSEABLE)) {
            entity.activation(!p);
        }
    }
}

//////////////////////////////////////////////////////////////
//// Simple pivot camera
//////////////////////////////////////////////////////////////

pub const SimplePivotCamera = struct {
    pub const Component = api.Component.SubTypeMixin(api.Control, SimplePivotCamera);

    id: Index = UNDEF_INDEX,
    name: String,
    pixel_perfect: bool = false,
    snap_to_bounds: ?RectF,
    pivot: *PosF = undefined,
    offset: Vector2f = .{ 0, 0 },
    enable_parallax: bool = false,
    velocity_relative_to_pivot: Vector2f = .{ 1, 1 },

    pub fn controlledComponentType() api.ComponentAspect {
        return graphics.View.Component.aspect;
    }

    pub fn setPivot(self: *SimplePivotCamera, view_id: Index, pivot: *PosF) void {
        self.pivot = pivot;
        self.adjust(view_id);
    }

    pub fn adjust(self: *SimplePivotCamera, view_id: Index) void {
        var view = graphics.View.Component.byId(view_id);
        const move = getMove(self, view);
        view.moveProjection(
            .{
                move[0] * view.projection.zoom * view.scale.?[0],
                move[1] * view.projection.zoom * view.scale.?[1],
            },
            true,
            self.snap_to_bounds,
        );
    }

    pub fn update(ctx: *api.CallContext) void {
        const self = Component.byId(ctx.caller_id);
        var view = graphics.View.Component.byId(ctx.id_1);
        const move = getMove(self, view);

        if (@abs(move[0]) > 0.1 or @abs(move[1]) > 0.1) {
            view.moveProjection(
                move * self.velocity_relative_to_pivot,
                self.pixel_perfect,
                self.snap_to_bounds,
            );

            // apply parallax scrolling if enabled
            if (self.enable_parallax) {
                if (view.ordered_active_layer) |ol| {
                    var next = ol.slots.nextSetBit(0);
                    while (next) |i| {
                        var layer = firefly.graphics.Layer.Component.byId(i);
                        if (layer.parallax) |parallax| {
                            if (layer.offset) |*off| {
                                off[0] = -view.projection.position[0] * parallax[0];
                                off[1] = -view.projection.position[1] * parallax[1];
                                if (self.pixel_perfect) {
                                    off[0] = @floor(off[0]);
                                    off[1] = @floor(off[1]);
                                }
                            }
                        }
                        next = ol.slots.nextSetBit(i + 1);
                    }
                }
            }
        }
    }

    inline fn getMove(self: *SimplePivotCamera, view: *graphics.View) Vector2f {
        const cam_world_pivot: Vector2f = .{
            (view.projection.position[0] + view.projection.width / 2) / view.projection.zoom / view.scale.?[0],
            (view.projection.position[1] + view.projection.height / 2) / view.projection.zoom / view.scale.?[1],
        };
        return self.pivot.* + self.offset - cam_world_pivot;
    }
};
