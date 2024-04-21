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
const Vector4f = utils.Vector4f;
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
const ClipI = utils.ClipI;
const BindingId = api.BindingId;
const NO_BINDING = api.NO_BINDING;

//////////////////////////////////////////////////////////////
//// tile init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() !void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(TileGrid);
    EComponent.registerEntityComponent(ETile);
    // init renderer
    System(DefaultTileGridRenderer).createSystem(
        inari.firefly.Engine.DefaultRenderer.TILE,
        "Render Entities referenced in all active TileGrid",
        true,
    );
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    // deinit renderer
    System(DefaultTileGridRenderer).disposeSystem();
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
    /// captures the grid dimensions in usize and c_int
    /// [2] = grid_pixel_width,
    /// [3] = grid_pixel_height,
    /// [4] = cell_pixel_width,
    /// [5] = cell_pixel_height
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
        var width: usize = @min(grid_width, self.dimensions[0]);
        var height: usize = @min(grid_height, self.dimensions[1]);
        self.dimensions[0] = grid_width;
        self.dimensions[1] = grid_height;
        self._c_int_dimensions[0] = @as(CInt, @intCast(self.dimensions[0]));
        self._c_int_dimensions[1] = @as(CInt, @intCast(self.dimensions[1]));

        var old_grid: [][]Index = self._grid;
        construct(self);

        // copy from old
        for (0..height) |y| {
            for (0..width) |x| {
                self._grid[y][x] = old_grid[y][x];
            }
        }
    }

    pub fn setByName(self: *TileGrid, x: usize, y: usize, tile_name: String) void {
        if (Entity.byName(tile_name)) |e| {
            set(self, x, y, e.id);
        }
    }

    pub fn set(self: *TileGrid, x: usize, y: usize, tile_id: Index) void {
        if (self.spherical) {
            self._grid[y % self.dimensions[1]][x % self.dimensions[0]] = tile_id;
        } else {
            if (checkBounds) {
                self._grid[y][x] = tile_id;
            } else @panic("out of bounds");
        }
    }

    pub fn getAt(self: *TileGrid, world_pos: PosF) ?Index {
        var rel_pos: PosF = world_pos - self.world_position;
        return get(self, map_cell_x(rel_pos[0]), map_cell_x(rel_pos[1]));
    }

    pub fn get(self: *TileGrid, x: usize, y: usize) ?Index {
        if (self.spherical) {
            var r = self._grid[y % self.dimensions[1]][x % self.dimensions[0]];
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

    inline fn checkBounds(self: *TileGrid, x: usize, y: usize) bool {
        return x < self.dimensions[0] and y < self.dimensions[1];
    }

    inline fn map_cell_x(self: *TileGrid, pixel_x: usize) usize {
        return @truncate(pixel_x / self.dimensions[2]);
    }

    inline fn map_cell_y(self: *TileGrid, pixel_y: usize) usize {
        return @truncate(pixel_y / self.dimensions[3]);
    }

    pub fn getIterator(self: *TileGrid, projection: *const Projection) ?Iterator {
        var intersectionF = utils.getIntersectionRectF(
            .{
                self.world_position[0],
                self.world_position[1],
                self._dimensionsF[0] * self._dimensionsF[2],
                self._dimensionsF[1] * self._dimensionsF[3],
            },
            projection.plain,
        );

        if (intersectionF[1] <= 0 or intersectionF[3] <= 0)
            return null;

        return Iterator.new(
            self,
            .{
                @as(usize, @intFromFloat((intersectionF[0] - self.world_position[0]) / self._dimensionsF[2])),
                @as(usize, @intFromFloat((intersectionF[1] - self.world_position[1]) / self._dimensionsF[3])),
                @min(@as(usize, @intFromFloat(intersectionF[2] / self._dimensionsF[2] + 1)), self.dimensions[0]),
                @min(@as(usize, @intFromFloat(intersectionF[3] / self._dimensionsF[3] + 1)), self.dimensions[1]),
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
                // std.debug.print("clip: x1:{d} x2:{d} y1:{d} y2:{d} \n", .{
                //     c[0],
                //     @min(c[0] + c[2], grid_ref.dimensions[0]),
                //     c[1],
                //     @min(c[1] + c[3], grid_ref.dimensions[1]),
                // });
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
    var tile_grid_refs: ViewLayerMapping = undefined;

    pub fn systemInit() void {
        tile_grid_refs = ViewLayerMapping.new();
    }

    pub fn systemDeinit() void {
        tile_grid_refs.deinit();
        tile_grid_refs = undefined;
    }

    pub fn componentRegistration(id: Index, register: bool) void {
        var tile_grid = TileGrid.byId(id);
        if (register)
            tile_grid_refs.add(tile_grid.view_id, tile_grid.layer_id, id)
        else
            tile_grid_refs.remove(tile_grid.view_id, tile_grid.layer_id, id);
    }

    pub fn renderView(e: ViewRenderEvent) void {
        if (tile_grid_refs.get(e.view_id, e.layer_id)) |all| {
            var i = all.nextSetBit(0);
            while (i) |grid_id| {
                var tile_grid: *TileGrid = TileGrid.byId(grid_id);
                api.rendering.addOffset(tile_grid.world_position);
                var iterator = tile_grid.getIterator(e.projection.?);
                if (iterator) |*itr| {
                    while (itr.next()) |entity_id| {
                        var tile = ETile.byId(entity_id).?;
                        var trans = ETransform.byId(entity_id).?;
                        if (tile.sprite_template_id != NO_BINDING) {
                            api.rendering.renderSprite(
                                tile._texture_binding,
                                tile._texture_bounds,
                                itr.rel_position + trans.position,
                                trans.pivot,
                                trans.scale,
                                trans.rotation,
                                tile.tint_color,
                                tile.blend_mode,
                                null,
                            );
                        }
                    }
                }
                api.rendering.addOffset(tile_grid.world_position * utils.NEG_VEC2F);
                i = all.nextSetBit(grid_id + 1);
            }
        }
    }
};
