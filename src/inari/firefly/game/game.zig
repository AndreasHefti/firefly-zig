const std = @import("std");
const firefly = @import("../firefly.zig");
const api = firefly.api;
const graphics = firefly.graphics;
const tile = @import("tile.zig");
const json = @import("json.zig");
const world = @import("world.zig");
const player = @import("player.zig");

const Vector2f = firefly.utils.Vector2f;
const RectF = firefly.utils.RectF;
const PosF = firefly.utils.PosF;
const Index = firefly.utils.Index;
const String = firefly.utils.String;

//////////////////////////////////////////////////////////////
//// general game package init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    api.ComponentControlType(SimplePivotCamera).init();

    // init sub packages
    tile.init();
    world.init();
    json.init();
    player.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit sub packages
    player.deinit();
    json.deinit();
    world.deinit();
    tile.deinit();

    api.ComponentControlType(SimplePivotCamera).deinit();
}

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const GlobalConditions = struct {
    const ENTITY_MOVES = "ENTITY_MOVES";
    const ENTITY_MOVES_UP = "ENTITY_MOVES_UP";
    const ENTITY_MOVES_DOWN = "ENTITY_MOVES_DOWN";
    const ENTITY_MOVES_RIGHT = "ENTITY_MOVES_RIGHT";
    const ENTITY_MOVES_LEFT = "ENTITY_MOVES_LEFT";

    var loaded = false;

    pub fn load() void {
        defer loaded = true;
        if (loaded) return;

        _ = api.CCondition.new(.{ .name = ENTITY_MOVES, .condition = .{ .f = entityMoves } });
        _ = api.CCondition.new(.{ .name = ENTITY_MOVES_UP, .condition = .{ .f = entityMovesUp } });
        _ = api.CCondition.new(.{ .name = ENTITY_MOVES_DOWN, .condition = .{ .f = entityMovesDown } });
        _ = api.CCondition.new(.{ .name = ENTITY_MOVES_RIGHT, .condition = .{ .f = entityMovesRight } });
        _ = api.CCondition.new(.{ .name = ENTITY_MOVES_LEFT, .condition = .{ .f = entityMovesLeft } });
    }

    pub fn dispose() void {
        defer loaded = false;
        if (!loaded) return;

        api.CCondition.disposeByName(ENTITY_MOVES);
        api.CCondition.disposeByName(ENTITY_MOVES_UP);
        api.CCondition.disposeByName(ENTITY_MOVES_DOWN);
        api.CCondition.disposeByName(ENTITY_MOVES_RIGHT);
        api.CCondition.disposeByName(ENTITY_MOVES_LEFT);
    }

    fn entityMoves(index: ?Index, _: ?api.Attributes) bool {
        if (index) |i|
            if (api.EMovement.byId(i)) |m| return m.velocity[0] != 0 or m.velocity[1] != 0;
        return false;
    }

    fn entityMovesUp(index: ?Index, _: ?api.Attributes) bool {
        if (index) |i|
            if (api.EMovement.byId(i)) |m| return m.velocity[1] < 0;
        return false;
    }

    fn entityMovesDown(index: ?Index, _: ?api.Attributes) bool {
        if (index) |i|
            if (api.EMovement.byId(i)) |m| return m.velocity[1] > 0;
        return false;
    }

    fn entityMovesRight(index: ?Index, _: ?api.Attributes) bool {
        if (index) |i|
            if (api.EMovement.byId(i)) |m| return m.velocity[0] > 0;
        return false;
    }

    fn entityMovesLeft(index: ?Index, _: ?api.Attributes) bool {
        if (index) |i|
            if (api.EMovement.byId(i)) |m| return m.velocity[0] < 0;
        return false;
    }
};

pub const TaskAttributes = struct {
    /// Name of the current view
    pub const ATTR_VIEW_NAME = "VIEW_NAME";
    /// File resource name. If this is set, a task shall try to load the data from referenced file
    pub const FILE_RESOURCE = "file_name";
    /// JSON String resource reference. If this is set, a task shall interpret this as JSON Sting
    /// and try to load defined components from JSON
    pub const JSON_RESOURCE = "json_resource";
    /// Name of the owner composite. If this is set, task should get the
    /// composite referenced to and add all created components as owner to the composite
    pub const OWNER_COMPOSITE = "owner_composite";
};

pub const TileDimensionType = tile.TileDimensionType;
pub const BaseMaterialType = tile.BaseMaterialType;
pub const TileAnimationFrame = tile.TileAnimationFrame;
pub const TileSet = tile.TileSet;
pub const SpriteData = tile.SpriteData;
pub const TileTemplate = tile.TileTemplate;
pub const TileMapping = tile.TileMapping;
pub const TileSetMapping = tile.TileSetMapping;
pub const TileLayerData = tile.TileLayerData;

pub const JSONTasks = json.JSONTasks;
pub const JSONTile = json.JSONTile;
pub const JSONTileSet = json.JSONTileSet;

pub const Room = world.Room;
pub const RoomState = world.RoomState;
pub const Area = world.Area;

pub const PlatformerCollisionResolver = player.PlatformerCollisionResolver;

//////////////////////////////////////////////////////////////
//// Simple pivot camera
//////////////////////////////////////////////////////////////

pub const SimplePivotCamera = struct {
    pub usingnamespace api.ControlTypeTrait(SimplePivotCamera, graphics.View);

    name: String,
    pixel_perfect: bool = false,
    snap_to_bounds: ?RectF,
    pivot: *PosF = undefined,
    offset: Vector2f = .{ 0, 0 },
    enable_parallax: bool = false,
    velocity_relative_to_pivot: Vector2f = .{ 1, 1 },

    pub fn setPivot(self: *SimplePivotCamera, view_id: Index, pivot: *PosF) void {
        self.pivot = pivot;
        self.adjust(view_id);
    }

    pub fn adjust(self: *SimplePivotCamera, view_id: Index) void {
        var view = graphics.View.byId(view_id);
        const move = getMove(self, view);
        view.adjustProjection(
            @floor(view.projection.position + move),
            false,
            self.snap_to_bounds,
        );
    }

    pub fn update(call_context: firefly.api.CallContext) void {
        if (call_context.caller_id) |view_id|
            if (api.ComponentControlType(SimplePivotCamera).stateByControlId(call_context.parent_id)) |self| {
                var view = graphics.View.byId(view_id);
                const move = getMove(self, view);
                //std.debug.print("move: {d}\n", .{move});
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
                                var layer = firefly.graphics.Layer.byId(i);
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
            };
    }

    inline fn getMove(self: *SimplePivotCamera, view: *graphics.View) Vector2f {
        const cam_world_pivot: Vector2f = .{
            (view.projection.position[0] + view.projection.width / 2) / view.projection.zoom / view.scale.?[0],
            (view.projection.position[1] + view.projection.height / 2) / view.projection.zoom / view.scale.?[1],
        };
        //std.debug.print("self pivot: {d} cam_world_pivot: {d} \n", .{ self.pivot.*, cam_world_pivot });
        return self.pivot.* + self.offset - cam_world_pivot;
    }
};
