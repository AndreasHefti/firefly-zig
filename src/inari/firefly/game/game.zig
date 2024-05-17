const std = @import("std");
const firefly = @import("../firefly.zig");

const View = firefly.graphics.View;
const ComponentControlType = firefly.api.ComponentControlType;
const Vector2f = firefly.utils.Vector2f;
const RectF = firefly.utils.RectF;
const PosF = firefly.utils.PosF;
const Float = firefly.utils.Float;
const Index = firefly.utils.Index;
const String = firefly.utils.String;

var initialized = false;

pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    ComponentControlType(SimplePivotCamera).init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    ComponentControlType(SimplePivotCamera).deinit();
}

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const SimplePivotCamera = struct {
    pub var component_type = View;

    name: ?String,
    pixel_perfect: bool = false,
    snap_to_bounds: ?RectF,
    velocity: Float,
    pivot: *PosF,

    pub fn update(view_id: Index) void {
        if (ComponentControlType(SimplePivotCamera).byId(view_id)) |self| {
            var view = View.byId(view_id);
            if (getMove(self, view)) |move|
                view.move(.{ move[0] * self.velocity, move[1] * self.velocity }, self.pixel_perfect);
        }
    }

    fn getMove(self: *SimplePivotCamera, view: *View) ?Vector2f {
        const _zoom: Float = 1 / view.projection.zoom;
        const view_h: Float = view.projection.width / _zoom;
        const view_hh = view_h / 2;
        const view_v = view.projection.height / _zoom;
        const view_vh = view_v / 2;
        const x_max = self.snap_to_bounds[2] - view_h;
        const y_max = self.snap_to_bounds[3] - view_v;

        var pos: Vector2f = .{
            self.pivot[0] + _zoom - view_hh,
            self.pivot[1] + _zoom - view_vh,
        };

        if (pos[0] < self.snap_to_bounds[0])
            pos[0] = self.snap_to_bounds[0];
        if (pos[1] < self.snap_to_bounds[1])
            pos[1] = self.snap_to_bounds[1];

        pos[0] = @min(pos[0], x_max);
        pos[1] = @min(pos[1], y_max);
        pos = @ceil(pos - view.projection.position);

        return if (pos[0] != 0 or pos[1] != 0) pos else null;
    }
};
