const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const graphics = firefly.graphics;

const Vector4f = utils.Vector4f;
const PosF = utils.PosF;
const Index = utils.Index;
const String = utils.String;
const Float = utils.Float;
const Color = utils.Color;
const BlendMode = api.BlendMode;
const RectF = utils.RectF;
const CInt = utils.CInt;
const BindingId = api.BindingId;
const UNDEF_INDEX = utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// tile init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    BasicTileTypes.UNDEFINED = TileTypeAspectGroup.getAspect("UNDEFINED");
    api.Component.registerComponent(TileGrid);
    api.EComponent.registerEntityComponent(ETile);
    // init renderer
    api.System(DefaultTileGridRenderer).createSystem(
        firefly.Engine.DefaultRenderer.TILE,
        "Render Entities referenced in all active TileGrid",
        true,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit renderer
    api.System(DefaultTileGridRenderer).disposeSystem();
}

//////////////////////////////////////////////////////////////
//// Tile API
//////////////////////////////////////////////////////////////

// Tile Type Aspects
pub const TileTypeAspectGroup = utils.AspectGroup(struct {
    pub const name = "TileType";
});
pub const TileTypeAspect = TileTypeAspectGroup.Aspect;
pub const TileTypeKind = TileTypeAspectGroup.Kind;
pub const BasicTileTypes = struct {
    pub var UNDEFINED: TileTypeAspect = undefined;
};

//////////////////////////////////////////////////////////////
//// ETile Tile Entity Component
//////////////////////////////////////////////////////////////

pub const ETile = struct {
    pub usingnamespace api.EComponent.Trait(@This(), "ETile");

    id: Index = UNDEF_INDEX,
    sprite_template_id: Index = UNDEF_INDEX,
    tint_color: ?Color = null,
    blend_mode: ?BlendMode = null,

    pub fn destruct(self: *ETile) void {
        self.sprite_template_id = UNDEF_INDEX;
        self.tint_color = null;
        self.blend_mode = null;
    }

    pub const Property = struct {
        pub fn FrameId(id: Index) *Index {
            return &ETile.byId(id).?.sprite_template_id;
        }
        pub fn TintColor(id: Index) *Color {
            var tile = ETile.byId(id).?;
            if (tile.tint_color == null) {
                tile.tint_color = Color{};
            }
            return &tile.tint_color.?;
        }
    };
};

//////////////////////////////////////////////////////////////
//// TileGrid Component
//////////////////////////////////////////////////////////////

pub const TileGrid = struct {
    pub usingnamespace api.Component.Trait(TileGrid, .{
        .name = "TileGrid",
    });

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    world_position: PosF,
    view_id: ?Index = null,
    layer_id: ?Index = null,
    spherical: bool = false,
    /// captures the grid dimensions in usize and c_int
    /// [0] = grid_tile_width,
    /// [1] = grid_tile_height,
    /// [2] = tile_width,
    /// [3] = tile_height
    dimensions: @Vector(4, usize),

    _dimensionsF: Vector4f = undefined,
    _grid: [][]Index = undefined,

    pub fn construct(self: *TileGrid) void {
        self._dimensionsF = .{
            @as(Float, @floatFromInt(self.dimensions[0])),
            @as(Float, @floatFromInt(self.dimensions[1])),
            @as(Float, @floatFromInt(self.dimensions[2])),
            @as(Float, @floatFromInt(self.dimensions[3])),
        };

        self._grid = api.COMPONENT_ALLOC.alloc([]Index, self.dimensions[1]) catch unreachable;
        for (0..self.dimensions[1]) |i| {
            self._grid[i] = api.COMPONENT_ALLOC.alloc(Index, self.dimensions[0]) catch unreachable;
        }
        self.clear();
    }

    pub fn destruct(self: *TileGrid) void {
        for (0..self.dimensions[1]) |i| {
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
        const width: usize = @min(grid_width, self.dimensions[0]);
        const height: usize = @min(grid_height, self.dimensions[1]);
        self.dimensions[0] = grid_width;
        self.dimensions[1] = grid_height;
        self._c_int_dimensions[0] = @as(CInt, @intCast(self.dimensions[0]));
        self._c_int_dimensions[1] = @as(CInt, @intCast(self.dimensions[1]));

        const old_grid: [][]Index = self._grid;
        construct(self);

        // copy from old
        for (0..height) |y| {
            for (0..width) |x| {
                self._grid[y][x] = old_grid[y][x];
            }
        }
    }

    pub fn setByName(self: *TileGrid, x: usize, y: usize, tile_name: String) void {
        if (api.Entity.byName(tile_name)) |e| {
            set(self, x, y, e.id);
        }
    }

    pub fn set(self: *TileGrid, x: usize, y: usize, tile_id: Index) void {
        if (self.spherical) {
            self._grid[y % self.dimensions[1]][x % self.dimensions[0]] = tile_id;
        } else {
            if (self.checkBounds(x, y)) {
                self._grid[y][x] = tile_id;
            } else @panic("out of bounds");
        }
    }

    pub fn getAt(self: *TileGrid, world_pos: PosF) ?Index {
        const rel_pos: PosF = world_pos - self.world_position;
        return get(self, map_cell_x(rel_pos[0]), map_cell_x(rel_pos[1]));
    }

    pub fn get(self: *TileGrid, x: usize, y: usize) ?Index {
        if (self.spherical) {
            const r = self._grid[y % self.dimensions[1]][x % self.dimensions[0]];
            if (r == UNDEF_INDEX) return null else return r;
        } else {
            if (checkBounds) {
                const r = self._grid[y][x];
                if (r == UNDEF_INDEX) return null else return r;
            } else return null;
        }
    }

    pub fn getNeighbor(self: *TileGrid, x: usize, y: usize, direction: utils.Direction, distance: usize) ?Index {
        return switch (direction) {
            .NORTH => self.get(x, y - distance),
            .NORTH_EAST => self.get(x + distance, y - distance),
            .EAST => self.get(x + distance, y),
            .SOUTH_EAST => self.get(x + distance, y + distance),
            .SOUTH => self.get(x, y + distance),
            .SOUTH_WEST => self.get(x - distance, y + distance),
            .WEST => self.get(x - distance, y),
            .NORTH_WEST => self.get(x - distance, y - distance),
            .NO_DIRECTION => self.get(x, y),
        };
    }

    inline fn checkBounds(self: *TileGrid, x: usize, y: usize) bool {
        return x < self.dimensions[0] and y < self.dimensions[1];
    }

    inline fn map_cell_x(self: *TileGrid, pixel_x: usize) usize {
        return @truncate(pixel_x / self.dimensions[2]);
    }

    inline fn map_cell_y(self: *TileGrid, pixel_y: usize) usize {
        return @truncate(pixel_y / self.dimensions[3]);
    }

    pub inline fn getIteratorForProjection(self: *TileGrid, projection: *const api.Projection) ?Iterator {
        var offset: utils.Vector2f = projection.position;
        if (self.layer_id) |lid| {
            if (graphics.Layer.byId(lid).offset) |l_off| {
                offset -= l_off;
            }
        }

        return getIteratorWorldClipF(
            self,
            .{
                offset[0] / projection.zoom,
                offset[1] / projection.zoom,
                projection.width / projection.zoom,
                projection.height / projection.zoom,
            },
        );
    }

    pub fn getIteratorWorldClipF(self: *TileGrid, clip: RectF) ?Iterator {
        const intersectionF = utils.getIntersectionRectF(
            .{
                self.world_position[0],
                self.world_position[1],
                self._dimensionsF[0] * self._dimensionsF[2],
                self._dimensionsF[1] * self._dimensionsF[3],
            },
            clip,
        );

        if (intersectionF[2] <= 0 or intersectionF[3] <= 0)
            return null;

        return Iterator.new(
            self,
            .{
                @as(usize, @intFromFloat((intersectionF[0] - self.world_position[0]) / self._dimensionsF[2])),
                @as(usize, @intFromFloat((intersectionF[1] - self.world_position[1]) / self._dimensionsF[3])),
                @min(@as(usize, @intFromFloat(@ceil(intersectionF[2] / self._dimensionsF[2] + 1))), self.dimensions[0]),
                @min(@as(usize, @intFromFloat(@ceil(intersectionF[3] / self._dimensionsF[3] + 1))), self.dimensions[1]),
            },
        );
    }

    pub const Iterator = struct {
        _grid_ref: *const TileGrid,
        _x1: usize,
        _y1: usize,
        _x2: usize,
        _y2: usize,
        _x: usize,
        _y: usize,

        rel_position: PosF,

        fn new(grid_ref: *const TileGrid, clip: ?@Vector(4, usize)) Iterator {
            if (clip) |c| {
                return .{
                    ._grid_ref = grid_ref,
                    ._x1 = c[0],
                    ._y1 = c[1],
                    ._x2 = @min(c[0] + c[2], grid_ref.dimensions[0]),
                    ._y2 = @min(c[1] + c[3], grid_ref.dimensions[1]),
                    ._x = c[0],
                    ._y = c[1],
                    .rel_position = .{
                        @as(Float, @floatFromInt(c[0])) * grid_ref._dimensionsF[2],
                        @as(Float, @floatFromInt(c[1])) * grid_ref._dimensionsF[3],
                    },
                };
            } else {
                return .{
                    ._grid_ref = grid_ref,
                    ._x1 = 0,
                    ._y1 = 0,
                    ._x2 = grid_ref.dimensions[0],
                    ._y2 = grid_ref.dimensions[1],
                    ._x = 0,
                    ._y = 0,
                    .rel_position = .{
                        grid_ref._dimensionsF[0] * grid_ref._dimensionsF[2],
                        grid_ref._dimensionsF[1] * grid_ref._dimensionsF[3],
                    },
                };
            }
        }

        pub fn next(self: *Iterator) ?Index {
            defer self._x = self._x + 1;
            if (self._x < self._x2) {
                self.rel_position[0] = @floatFromInt(self._x * self._grid_ref.dimensions[2]);
                self.rel_position[1] = @floatFromInt(self._y * self._grid_ref.dimensions[3]);
                return self._grid_ref._grid[self._y][self._x];
            }

            self._x = self._x1;
            self._y = self._y + 1;
            if (self._y < self._y2) {
                self.rel_position[0] = @floatFromInt(self._x * self._grid_ref.dimensions[2]);
                self.rel_position[1] = @floatFromInt(self._y * self._grid_ref.dimensions[3]);
                return self._grid_ref._grid[self._y][self._x];
            }

            return null;
        }
    };

    pub fn format(
        self: TileGrid,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "TileGrid[{d}|{?s}]\n  pos:{any} view:{any} layer:{any}\n  spherical:{any}\n  dimensions:{any}\n  ud:{any}\n  {any}",
            self,
        );
    }
};

//////////////////////////////////////////////////////////////
//// Default Tile Grid Renderer
//////////////////////////////////////////////////////////////

const DefaultTileGridRenderer = struct {
    pub const component_register_type = TileGrid;
    var tile_grid_refs: graphics.ViewLayerMapping = undefined;

    pub fn systemInit() void {
        tile_grid_refs = graphics.ViewLayerMapping.new();
    }

    pub fn systemDeinit() void {
        tile_grid_refs.deinit();
        tile_grid_refs = undefined;
    }

    pub fn componentRegistration(id: Index, register: bool) void {
        const tile_grid = TileGrid.byId(id);
        if (register)
            tile_grid_refs.add(tile_grid.view_id, tile_grid.layer_id, id)
        else
            tile_grid_refs.remove(tile_grid.view_id, tile_grid.layer_id, id);
    }

    pub fn renderView(e: graphics.ViewRenderEvent) void {
        if (tile_grid_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |grid_id| {
                i = all.nextSetBit(grid_id + 1);

                var tile_grid: *TileGrid = TileGrid.byId(grid_id);
                var iterator = tile_grid.getIteratorForProjection(e.projection.?) orelse continue;

                firefly.api.rendering.addOffset(tile_grid.world_position);

                while (iterator.next()) |entity_id| {
                    if (entity_id == UNDEF_INDEX)
                        continue;

                    const tile = ETile.byId(entity_id) orelse continue;
                    const trans = graphics.ETransform.byId(entity_id) orelse continue;
                    const sprite_template: *graphics.SpriteTemplate = graphics.SpriteTemplate.byId(tile.sprite_template_id);
                    api.rendering.renderSprite(
                        sprite_template.texture_binding,
                        sprite_template.texture_bounds,
                        iterator.rel_position + trans.position,
                        trans.pivot,
                        trans.scale,
                        trans.rotation,
                        tile.tint_color,
                        tile.blend_mode,
                        null,
                    );
                }

                api.rendering.addOffset(tile_grid.world_position * utils.NEG_VEC2F);
            }
        }
    }
};
