const std = @import("std");
const utils = @import("utils.zig");
const CInt = utils.CInt;
const Float = utils.Float;
const Byte = utils.Byte;

/// Two dimensional vector of i32 values
pub const Vector2i = @Vector(2, CInt);
/// Three dimensional vector of i32 values
pub const Vector3i = @Vector(3, CInt);
/// Four Two dimensional vector of i32 values
pub const Vector4i = @Vector(4, CInt);

/// Two dimensional vector of f32 values
pub const Vector2f = @Vector(2, Float);
/// Three dimensional vector of f32 values
pub const Vector3f = @Vector(3, Float);
/// Four Two dimensional vector of f32 values
pub const Vector4f = @Vector(4, Float);

/// Integer rectangle as Vector4i32 [0]-->x [1]-->x [2]-->width [3]-->height
pub const RectI = Vector4i;
/// Float rectangle as Vector4f32 [0]-->x [1]-->x [2]-->width [3]-->height
pub const RectF = Vector4f;

pub const PosI = Vector2i;
pub const PosF = Vector2f;

/// Color as Vector4u8
pub const Color = @Vector(4, Byte);

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

// vec math...
pub fn magnitude2i(v: *Vector2i) f32 {
    return @sqrt(@as(f32, @floatFromInt(v[0] * v[0] + v[1] * v[1])));
}
pub fn magnitude3i(v: *Vector3i) f32 {
    return @sqrt(@as(f32, @floatFromInt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])));
}
pub fn magnitude4i(v: *Vector4i) f32 {
    return @sqrt(@as(f32, @floatFromInt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3])));
}
pub fn magnitude2f(v: *Vector2f) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1]);
}
pub fn magnitude3f(v: *Vector3f) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}
pub fn magnitude4f(v: *Vector4f) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2] + v[3] * v[3]);
}

pub fn normalize2i(v: *Vector2i) void {
    var m: i32 = @intFromFloat(magnitude2i(v));
    if (m == 0) {
        v[0] = 0;
        v[1] = 0;
    } else {
        v[0] = @divTrunc(v[0], m);
        v[1] = @divTrunc(v[1], m);
    }
}
pub fn normalize3i(v: *Vector3i) void {
    var m: i32 = @intFromFloat(magnitude3i(v));
    if (m == 0) {
        v[0] = 0;
        v[1] = 0;
        v[2] = 0;
    } else {
        v[0] = @divTrunc(v[0], m);
        v[1] = @divTrunc(v[1], m);
        v[2] = @divTrunc(v[2], m);
    }
}
pub fn normalize4i(v: *Vector4i) void {
    var m: i32 = @intFromFloat(magnitude4i(v));
    if (m == 0) {
        v[0] = 0;
        v[1] = 0;
        v[2] = 0;
        v[3] = 0;
    } else {
        v[0] = @divTrunc(v[0], m);
        v[1] = @divTrunc(v[1], m);
        v[2] = @divTrunc(v[2], m);
        v[3] = @divTrunc(v[3], m);
    }
}

pub fn normalize2f(v: *Vector2f) void {
    var m = magnitude2f(v);
    if (m == 0) {
        v[0] = 0;
        v[1] = 0;
    } else {
        v[0] = v[0] / m;
        v[1] = v[1] / m;
    }
}

pub fn normalize3f(v: *Vector3f) void {
    var m = magnitude3f(v);
    if (m == 0) {
        v[0] = 0;
        v[1] = 0;
        v[2] = 0;
    } else {
        v[0] = v[0] / m;
        v[1] = v[1] / m;
        v[2] = v[2] / m;
    }
}
pub fn normalize4f(v: *Vector4f) void {
    var m = magnitude4f(v);
    if (m == 0) {
        v[0] = 0;
        v[1] = 0;
        v[2] = 0;
        v[3] = 0;
    } else {
        v[0] = v[0] / m;
        v[1] = v[1] / m;
        v[2] = v[2] / m;
        v[3] = v[3] / m;
    }
}

pub fn distance2i(p1: *Vector2i, p2: *Vector2i) f32 {
    var dx = p2[0] - p1[0];
    var dy = p2[1] - p1[1];

    return @sqrt(@as(f32, @floatFromInt(dx * dx + dy * dy)));
}

pub fn distance2f(p1: *Vector2f, p2: *Vector2f) f32 {
    var d = p2.* - p1.*;
    return @sqrt(d[0] * d[0] + d[1] * d[1]);
}

// testing vec
test "vec math" {
    var v1 = Vector2i{ 2, 3 };
    normalize2i(&v1);
    try std.testing.expect(v1[0] == 0);
    try std.testing.expect(v1[1] == 1);

    var v2 = Vector2f{ 2, 3 };
    normalize2f(&v2);
    try std.testing.expect(v2[0] == 0.554700195);
    try std.testing.expect(v2[1] == 0.832050323);

    // distance
    var p1 = Vector2i{ 1, 1 };
    var p2 = Vector2i{ 2, 2 };
    var dp1p2 = distance2i(&p1, &p2);
    try std.testing.expect(dp1p2 == 1.4142135381698608);
}
