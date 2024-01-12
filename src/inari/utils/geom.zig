const std = @import("std");

/// Integer rectangle as Vector4i32 [0]-->x [1]-->x [2]-->width [3]-->height
pub const RectI = @Vector(4, i32);
/// Float rectangle as Vector4f32 [0]-->x [1]-->x [2]-->width [3]-->height
pub const RectF = @Vector(4, f32);
/// Color as Vector4i8
pub const Color = @Vector(4, i8);
pub const Orientation = enum { NONE, NORTH, EAST, SOUTH, WEST };
pub const Direction = struct {
    /// horizontal direction component
    horizontal: Orientation = Orientation.NONE,
    /// vertical direction component
    vertical: Orientation = Orientation.NONE,

    pub const NO_DIRECTION = Direction{};
    pub const NORTH = Direction{ Orientation.NONE, Orientation.NORTH };
    pub const NORTH_EAST = Direction{ Orientation.EAST, Orientation.NORTH };
    pub const EAST = Direction{ Orientation.EAST, Orientation.NONE };
    pub const SOUTH_EAST = Direction{ Orientation.EAST, Orientation.SOUTH };
    pub const SOUTH = Direction{ Orientation.NONE, Orientation.SOUTH };
    pub const SOUTH_WEST = Direction{ Orientation.WEST, Orientation.SOUTH };
    pub const WEST = Direction{ Orientation.WEST, Orientation.NONE };
    pub const NORTH_WEST = Direction{ Orientation.WEST, Orientation.NORTH };
};
