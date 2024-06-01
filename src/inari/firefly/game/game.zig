const std = @import("std");
const firefly = @import("../firefly.zig");
const tile = @import("tile.zig");
const json = @import("json.zig");

const View = firefly.graphics.View;
const ComponentControlType = firefly.api.ComponentControlType;
const Vector2f = firefly.utils.Vector2f;
const RectF = firefly.utils.RectF;
const PosF = firefly.utils.PosF;
const Float = firefly.utils.Float;
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

    ComponentControlType(SimplePivotCamera).init();

    // init sub packages
    try tile.init();
    try json.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit sub packages
    json.deinit();
    tile.deinit();

    ComponentControlType(SimplePivotCamera).deinit();
}

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const GameTaskAttributes = struct {
    pub const OWNER_COMPOSITE = "owner_composite";
    pub const LOAD_FILE_NAME = "file_name";
    pub const JSON_RESOURCE = "json_resource";
};

pub const TileDimensionType = tile.TileDimensionType;
pub const TileContactMaterialType = tile.TileContactMaterialType;
pub const TileAnimationFrame = tile.TileAnimationFrame;
pub const TileSet = tile.TileSet;
pub const SpriteData = tile.SpriteData;
pub const TileTemplate = tile.TileTemplate;
pub const TileMapping = tile.TileMapping;
pub const MappedTileSet = tile.MappedTileSet;
pub const TileSetLayerMapping = tile.TileSetLayerMapping;

pub const JSONTasks = json.JSONTasks;

//////////////////////////////////////////////////////////////
//// Simple pivot camera
//////////////////////////////////////////////////////////////

pub const SimplePivotCamera = struct {
    pub const component_type = View;

    name: String,
    pixel_perfect: bool = false,
    snap_to_bounds: ?RectF,
    pivot: *PosF = undefined,
    offset: Vector2f = .{ 0, 0 },
    velocity_relative_to_pivot: Vector2f = .{ 1, 1 },

    pub fn setPivot(self: *SimplePivotCamera, view_id: Index, pivot: *PosF) void {
        self.pivot = pivot;
        self.adjust(view_id);
    }

    pub fn adjust(self: *SimplePivotCamera, view_id: Index) void {
        var view = View.byId(view_id);
        const move = getMove(self, view);
        view.adjustProjection(
            @floor(view.projection.position + move),
            false,
            self.snap_to_bounds,
        );
    }

    pub fn update(view_id: Index, control_id: Index) void {
        if (ComponentControlType(SimplePivotCamera).stateByControlId(control_id)) |self| {
            var view = View.byId(view_id);
            const move = getMove(self, view);
            if (@abs(move[0]) > 0.1 or @abs(move[1]) > 0.1) {
                view.moveProjection(
                    move * self.velocity_relative_to_pivot,
                    self.pixel_perfect,
                    self.snap_to_bounds,
                );
            }
        }
    }

    inline fn getMove(self: *SimplePivotCamera, view: *View) Vector2f {
        const cam_world_pivot: Vector2f = .{
            (view.projection.position[0] + view.projection.width / 2) / view.projection.zoom,
            (view.projection.position[1] + view.projection.height / 2) / view.projection.zoom,
        };
        return self.pivot.* + self.offset - cam_world_pivot;
    }
};

// pub fn ScreenSizeAdapter(view_id: Index, control_id: Index) void {

// }
