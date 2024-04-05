const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const graphics = inari.firefly.graphics;

const System = api.System;
const Entity = api.Entity;
const EComponent = api.EComponent;
const EntityCondition = api.EntityCondition;
const EComponentAspectGroup = api.EComponentAspectGroup;
const ComponentEvent = api.ComponentEvent;
const ActionType = api.Component.ActionType;
const EMultiplier = api.EMultiplier;
const ViewRenderEvent = graphics.ViewRenderEvent;
const ViewLayerMapping = graphics.ViewLayerMapping;
const ETransform = graphics.ETransform;
const SpriteTemplate = graphics.SpriteTemplate;
const Component = api.Component;
const Projection = api.Projection;

const Direction = utils.Direction;
const Vector2i = utils.Vector2i;
const PosF = utils.PosF;
const PosI = utils.PosI;
const Index = utils.Index;
const String = utils.String;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const Float = utils.Float;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const RectF = utils.RectF;
const RectI = utils.RectI;
const CInt = utils.CInt;
const BindingId = api.BindingId;
const NO_BINDING = api.NO_BINDING;

//////////////////////////////////////////////////////////////
//// shape init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(TileGrid);
    EComponent.registerEntityComponent(ETile);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // TODO
}

//////////////////////////////////////////////////////////////
//// ETile Tile Entity Component
//////////////////////////////////////////////////////////////

pub const ETile = struct {
    pub usingnamespace EComponent.Trait(@This(), "ETile");

    id: Index = UNDEF_INDEX,
    sprite_template_id: Index = UNDEF_INDEX,
    tint_color: ?Color = null,
    blend_mode: ?BlendMode = null,

    _texture_bounds: RectF = undefined,
    _texture_binding: BindingId = NO_BINDING,

    pub fn activation(self: *ETile, active: bool) void {
        if (active) {
            if (self.sprite_template_id == UNDEF_INDEX)
                @panic("Missing sprite_template_id");

            var template = SpriteTemplate.byId(self.sprite_template_id);
            self._texture_bounds = template.texture_bounds;
            self._texture_binding = template.texture_binding;

            if (template.flip_x) {
                self._texture_bounds[2] = -self._texture_bounds[2];
            }
            if (template.flip_y) {
                self._texture_bounds[3] = -self._texture_bounds[3];
            }
        } else {
            self._texture_bounds = undefined;
            self._texture_binding = UNDEF_INDEX;
        }
    }

    pub fn destruct(self: *ETile) void {
        self.sprite_template_id = UNDEF_INDEX;
        self._texture_bounds = undefined;
        self._texture_binding = NO_BINDING;
        self.tint_color = null;
        self.blend_mode = null;
    }
};

//////////////////////////////////////////////////////////////
//// TileGrid Component
//////////////////////////////////////////////////////////////

pub const TileGrid = struct {
    pub usingnamespace Component.Trait(TileGrid, .{ .name = "TileGrid" });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    world_position: PosF,
    view_id: ?Index = null,
    layer_id: ?Index = null,
    spherical: bool = false,

    grid_width: usize,
    grid_height: usize,
    cell_width: usize,
    cell_height: usize,

    _grid: [][]Index = undefined,

    pub fn construct(self: *TileGrid) void {
        self._grid = api.COMPONENT_ALLOC.alloc([]Index, self.grid_height) catch unreachable;
        for (0..self.grid_height) |i| {
            self._grid[i] = api.COMPONENT_ALLOC.alloc(Index, self.grid_width) catch unreachable;
        }
        self.clear();
    }

    pub fn destruct(self: *TileGrid) void {
        for (0..self.grid_height) |i| {
            api.COMPONENT_ALLOC.free(self._grid[i]);
        }
        api.COMPONENT_ALLOC.free(self._grid);
    }

    pub fn clear(self: *TileGrid) void {
        for (0..self._grid.len) |y| {
            for (0..self._grid[y].len) |x| {
                self._grid[y][x] = UNDEF_INDEX;
            }
        }
    }

    pub fn resize(self: *TileGrid, grid_width: usize, grid_height: usize) void {
        var width = @min(grid_width, self.grid_width);
        var height = @min(grid_height, self.grid_height);
        self.grid_width = grid_width;
        self.grid_height = grid_height;

        var old_grid: [][]Index = self._grid;
        construct(self);

        // copy from old
        for (0..height) |y| {
            for (0..width) |x| {
                self._grid[y][x] = old_grid[y][x];
            }
        }
    }

    pub fn setByNameP(self: *TileGrid, pos: PosI, tile_name: String) void {
        setByName(self, pos[0], pos[1], tile_name);
    }

    pub fn setByName(self: *TileGrid, x: usize, y: usize, tile_name: String) void {
        if (Entity.byName(tile_name)) |e| {
            set(self, x, y, e.id);
        }
    }

    pub fn setP(self: *TileGrid, pos: PosI, tile_id: Index) void {
        set(self, pos[0], pos[1], tile_id);
    }

    pub fn set(self: *TileGrid, x: usize, y: usize, tile_id: Index) void {
        if (self.spherical) {
            self._grid[y % self.grid_height][x % self.grid_width] = tile_id;
        } else {
            if (checkBounds) {
                self._grid[y][x] = tile_id;
            } else @panic("out of bounds");
        }
    }

    pub fn getAt(self: *TileGrid, world_pos: PosF) ?Index {
        var rel_pos: PosF = world_pos - self.world_position;
        return get(self, rel_pos[0] / self.cell_width, rel_pos[1] / self.cell_height);
    }

    pub fn getP(self: *TileGrid, pos: PosI) ?Index {
        return get(self, pos[0], pos[1]);
    }

    pub fn get(self: *TileGrid, x: usize, y: usize) ?Index {
        if (self.spherical) {
            var r = self._grid[y % self.grid_height][x % self.grid_width];
            if (r == UNDEF_INDEX) return null else return r;
        } else {
            if (checkBounds) {
                var r = self._grid[y][x];
                if (r == UNDEF_INDEX) return null else return r;
            } else return null;
        }
    }

    pub fn getNeighbor(self: *TileGrid, x: usize, y: usize, direction: Direction, distance: usize) ?Index {
        return switch (direction) {
            Direction.NORTH => self.get(x, y - distance),
            Direction.NORTH_EAST => self.get(x + distance, y - distance),
            Direction.EAST => self.get(x + distance, y),
            Direction.SOUTH_EAST => self.get(x + distance, y + distance),
            Direction.SOUTH => self.get(x, y + distance),
            Direction.SOUTH_WEST => self.get(x - distance, y + distance),
            Direction.WEST => self.get(x - distance, y),
            Direction.NORTH_WEST => self.get(x - distance, y - distance),
            Direction.NO_DIRECTION => self.get(x, y),
        };
    }

    // private fun mapWorldClipToTileGridClip(worldClip: Vector4i, tileGrid: TileGrid, result: Vector4i) {
    //         tmpClip(
    //             floor((worldClip.x - tileGrid.position.x) / tileGrid.cellDim.v0).toInt(),
    //             floor((worldClip.y - tileGrid.position.y) / tileGrid.cellDim.v1).toInt()
    //         )
    //         val x2 =
    //             ceil((worldClip.x - tileGrid.position.x + worldClip.width) / tileGrid.cellDim.v0).toInt()
    //         val y2 =
    //             ceil((worldClip.y - tileGrid.position.y + worldClip.height) / tileGrid.cellDim.v1).toInt()
    //         tmpClip.width = x2 - tmpClip.x
    //         tmpClip.height = y2 - tmpClip.y
    //         GeomUtils.intersection(tmpClip, tileGrid.normalisedWorldBounds, result)
    //     }

    pub fn getIterator(self: *TileGrid, projection: *Projection) Iterator {
        // TODO is this still right and/or is there a better way?
        var temp: RectI = .{
            (projection.plain[0] - @as(CInt, @intFromFloat(self.world_position[0]))) / self.grid_width,
            (projection.plain[1] - @as(CInt, @intFromFloat(self.world_position[1]))) / self.grid_height,
            (projection.plain[0] - @as(CInt, @intFromFloat(self.world_position[0])) + projection.plain[2]) / self.grid_width,
            (projection.plain[1] - @as(CInt, @intFromFloat(self.world_position[1])) + projection.plain[3]) / self.grid_height,
        };
        temp[2] = temp[2] - temp[0];
        temp[3] = temp[3] - temp[1];
        return Iterator.new(
            self,
            utils.getIntersectionRectI(temp, .{ 0, 0, self.grid_width, self.grid_height }),
        );
    }

    pub const Iterator = struct {
        _gridRef: *const TileGrid,
        _clip: RectI,
        _x: usize,
        _y: usize,

        world_position: PosI,

        fn new(gridRef: *const TileGrid, clip: ?RectI) Iterator {
            var x = if (clip) |c| c[0] else 0;
            if (x > gridRef.grid_width)
                x = gridRef.grid_width;
            var y = if (clip) |c| c[1] else 0;
            if (y > gridRef.grid_height)
                y = gridRef.grid_height;
            var w = if (clip) |c| x + c[2] else gridRef.grid_width;
            if (w > gridRef.grid_width)
                w = gridRef.grid_width;
            var h = if (clip) |c| y + c[3] else gridRef.grid_height;
            if (h > gridRef.grid_height)
                h = gridRef.grid_height;
            return .{
                ._gridRef = gridRef,
                ._clip = .{ x, y, w, h },
                ._x = x - 1,
                ._y = y,
                .world_position = .{
                    gridRef.world_position[0] + (x * gridRef.cell_width),
                    gridRef.world_position[1] + (y * gridRef.cell_height),
                },
            };
        }

        pub fn next(self: *Iterator) ?Index {
            self._x = self._x + 1;
            if (self._x < self._clip[2])
                return self._gridRef._grid[self._y][self._x];

            self._x = self._clip[0];
            self._y = self._y + 1;
            if (self._y < self._clip[3])
                return self._gridRef._grid[self._y][self._x];

            return null;
        }
    };

    inline fn checkBounds(self: *TileGrid, x: usize, y: usize) bool {
        return x < self.grid_width and y < self.grid_width;
    }

    pub fn format(
        self: TileGrid,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "TileGrid[{d}|{?s}]\n  pos:{any} view:{any} layer:{any}\n  spherical:{any}\n  grid:{d}|{d}\n  cell:{d}|{d}\n  {any}",
            self,
        );
    }
};

//////////////////////////////////////////////////////////////
//// Default Tile Grid Renderer
//////////////////////////////////////////////////////////////

const DefaultTileGridRenderer = struct {
    var tile_grid_refs: ViewLayerMapping = undefined;

    pub fn systemInit() void {
        tile_grid_refs = ViewLayerMapping.new();
    }

    pub fn systemDeinit() void {
        tile_grid_refs.deinit();
        tile_grid_refs = undefined;
    }

    pub fn systemActivation(active: bool) void {
        if (active) {
            TileGrid.subscribe(notifyTileGridEvent);
        } else {
            TileGrid.unsubscribe(notifyTileGridEvent);
        }
    }

    pub fn notifyTileGridEvent(e: ComponentEvent) void {
        if (e.c_id) |id| {
            var tile_grid = TileGrid.byId(id);
            switch (e.event_type) {
                ActionType.ACTIVATED => tile_grid_refs.add(tile_grid.view_id, tile_grid.layer_id, id),
                ActionType.DEACTIVATING => tile_grid_refs.remove(tile_grid.view_id, tile_grid.layer_id, id),
                else => {},
            }
        }
    }

    //var clip: RectI = .{ 0, 0, 0, 0 };
    pub fn renderView(e: ViewRenderEvent) void {
        if (tile_grid_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |grid_id| {
                var tile_grid: *TileGrid = TileGrid.byId(grid_id).?;
                api.rendering.addOffset(tile_grid.world_position);
                var iterator = tile_grid.getIterator(e.projection);
                while (iterator.next()) |entity_id| {
                    var tile = ETile.byId(entity_id).?;
                    var trans = ETransform.byId(entity_id).?;
                    if (tile.sprite_template_id != NO_BINDING) {
                        api.rendering.renderSprite(
                            tile._texture_binding,
                            tile._texture_bounds,
                            trans.position,
                            trans.pivot,
                            trans.scale,
                            trans.rotation,
                            tile.tint_color,
                            tile.blend_mode,
                            null,
                        );
                    }
                }
                api.rendering.addOffset(tile_grid.world_position * utils.NEG_VEC2F);
            }
        }
    }
};
