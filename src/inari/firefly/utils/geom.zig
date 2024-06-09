const std = @import("std");
const utils = @import("utils.zig");
const CInt = utils.CInt;
const Float = utils.Float;
const Byte = utils.Byte;
const BitSet = utils.BitSet;
const String = utils.String;

pub const HALF_PI: Float = std.math.pi / 2.0;
pub const TAU: Float = 2 * std.math.pi;

pub const BitOperation = *const fn (bool, bool) callconv(.Inline) bool;
pub inline fn bitOpAND(b1: bool, b2: bool) bool {
    return b1 and b2;
}
pub inline fn bitOpOR(b1: bool, b2: bool) bool {
    return b1 or b2;
}
pub inline fn bitOpXOR(b1: bool, b2: bool) bool {
    return b1 != b2;
}

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

/// Integer rectangle as Vector4 i32 [0]-->x [1]-->y [2]-->width [3]-->height
pub const RectI = Vector4i;
/// Float rectangle as Vector4 f32 [0]-->x [1]-->y [2]-->width [3]-->height
pub const RectF = Vector4f;
/// Integer Position as Vector2 i32 [0]-->x [1]-->y
pub const PosI = Vector2i;
/// Float Position as Vector2 f32 [0]-->x [1]-->y
pub const PosF = Vector2f;

pub const CircleI = Vector3i;
pub const CircleF = Vector3f;

pub const ClipI = @Vector(4, usize);

pub const NEG_VEC2I = Vector2i{ -1, -1 };
pub const NEG_VEC3I = Vector3i{ -1, -1, -1 };
pub const NEG_VEC4I = Vector4i{ -1, -1, -1, -1 };
pub const NEG_VEC2F = Vector2f{ -1, -1 };
pub const NEG_VEC3F = Vector3f{ -1, -1, -1 };
pub const NEG_VEC4F = Vector4f{ -1, -1, -1, -1 };

pub inline fn posF_usize_RectF(posF: ?PosF, w: usize, h: usize) ?RectF {
    if (posF) |pf| {
        return .{ pf[0], pf[1], utils.usize_f32(w), utils.usize_f32(h) };
    }
    return null;
}

pub inline fn parseUsize(value: ?String) usize {
    if (value) |v|
        return std.fmt.parseInt(usize, v, 10) catch 0;
    return 0;
}

pub inline fn parsePosF(value: ?String) ?PosF {
    if (value) |v| {
        if (v.len == 0) return null;
        var it = std.mem.split(u8, v, ",");
        return .{
            if (it.next()) |n| std.fmt.parseFloat(Float, n) catch return null else return null,
            if (it.next()) |n| std.fmt.parseFloat(Float, n) catch return null else return null,
        };
    }
    return null;
}

pub inline fn parsePosFSep(x: ?String, y: ?String) ?PosF {
    if (x == null and y == null) return null;
    return .{
        std.fmt.parseFloat(Float, x.?) catch 0,
        std.fmt.parseFloat(Float, y.?) catch 0,
    };
}

pub inline fn parseRectF(value: ?String) ?RectF {
    if (value) |v| {
        if (v.len == 0) return null;
        var it = std.mem.split(u8, v, ",");
        return .{
            if (it.next()) |n| std.fmt.parseFloat(Float, n) catch return null else return null,
            if (it.next()) |n| std.fmt.parseFloat(Float, n) catch return null else return null,
            if (it.next()) |n| std.fmt.parseFloat(Float, n) catch return null else return null,
            if (it.next()) |n| std.fmt.parseFloat(Float, n) catch return null else return null,
        };
    }
    return null;
}

pub inline fn parseColor(value: ?String) ?Color {
    if (value) |v| {
        if (v.len == 0) return null;
        var it = std.mem.split(u8, v, ",");
        return .{
            if (it.next()) |n| parseByte(n) else return null,
            if (it.next()) |n| parseByte(n) else return null,
            if (it.next()) |n| parseByte(n) else return null,
            if (it.next()) |n| parseByte(n) else return null,
        };
    }
    return null;
}

pub inline fn parseByte(value: ?String) Byte {
    if (value) |b| return std.fmt.parseInt(Byte, b, 10) catch return 0;
    return 0;
}

pub inline fn rectIFromRectF(rect: RectF) RectI {
    return .{
        @intFromFloat(@floor(rect[0])),
        @intFromFloat(@floor(rect[1])),
        @intFromFloat(@ceil(rect[2])),
        @intFromFloat(@ceil(rect[3])),
    };
}

pub inline fn rectFFromRectI(rect: RectI) RectF {
    return .{
        @floatFromInt(rect[0]),
        @floatFromInt(rect[1]),
        @floatFromInt(rect[2]),
        @floatFromInt(rect[3]),
    };
}

pub inline fn rectIToClip(rect: RectI) ClipI {
    return .{
        utils.i32_usize(rect[0]),
        utils.i32_usize(rect[1]),
        utils.i32_usize(rect[2]),
        utils.i32_usize(rect[3]),
    };
}

pub inline fn rectFToClip(rect: RectF) ClipI {
    return .{
        @intFromFloat(@floor(rect[0])),
        @intFromFloat(@floor(rect[1])),
        @intFromFloat(@ceil(rect[2])),
        @intFromFloat(@ceil(rect[3])),
    };
}

pub inline fn posIFromPosF(pos: PosF) PosI {
    return .{
        @intFromFloat(@floor(pos[0])),
        @intFromFloat(@floor(pos[1])),
    };
}

pub inline fn posFFromPosI(pos: PosI) PosF {
    return .{
        @floatFromInt(pos[0]),
        @floatFromInt(pos[1]),
    };
}

pub inline fn areaRectI(r: RectI) CInt {
    return r[2] * r[3];
}

pub inline fn areaRectF(r: RectF) Float {
    return r[2] * r[3];
}

pub fn containsRectI(r: RectI, x: CInt, y: CInt) bool {
    return x >= r[0] and y >= r[1] and x < r[0] + r[2] and y < r[1] + r[3];
}

pub fn containsRectF(r: RectF, x: Float, y: Float) bool {
    return x >= r[0] and y >= r[1] and x < r[0] + r[2] and y < r[1] + r[3];
}

pub fn containsCircI(c: CircleI, x: CInt, y: CInt) bool {
    const dx = c[0] - x;
    const dy = c[1] - y;
    return std.math.sqrt(utils.cint_usize(dx * dx + dy * dy)) < c[2];
}

pub fn containsCircF(c: CircleF, x: Float, y: Float) bool {
    const dx = c[0] - x;
    const dy = c[1] - y;
    return std.math.sqrt(dx * dx + dy * dy) < c[2];
}

pub fn intersectsRectI(r1: RectI, r2: RectI) bool {
    return !(r2[0] >= r1[0] + r1[2] or r2[0] + r2[2] <= r1[0] or r2[1] >= r1[1] + r1[3] or r2[1] + r2[3] <= r1[1]);
}

pub fn intersectsRectF(r1: RectF, r2: RectF) bool {
    return !(r2[0] >= r1[0] + r1[2] or r2[0] + r2[2] <= r1[0] or r2[1] >= r1[1] + r1[3] or r2[1] + r2[3] <= r1[1]);
}

pub fn intersectsRectIOffset(r1: RectI, r2: RectI, offset: Vector2i) bool {
    const r1x = r1[0] + offset[0];
    const r1y = r1[1] + offset[1];
    return !(r2[0] >= r1x + r1[2] or r2[0] + r2[2] <= r1x or r2[1] >= r1y + r1[3] or r2[1] + r2[3] <= r1y);
}

pub fn intersectsRectFOffset(r1: RectF, r2: RectF, offset: Vector2f) bool {
    const r1x = r1[0] + offset[0];
    const r1y = r1[1] + offset[1];
    return !(r2[0] >= r1x + r1[2] or r2[0] + r2[2] <= r1x or r2[1] >= r1y + r1[3] or r2[1] + r2[3] <= r1y);
}

pub fn intersectsCI(c1: CircleI, c2: CircleI) bool {
    const dx = (c1[0] + c1[2]) - (c2[0] + c2[2]);
    const dy = (c1[1] + c1[2]) - (c2[1] + c2[2]);
    return std.math.sqrt(dx * dx + dy * dy) < c1[3] + c2[3];
}

pub fn intersectsCF(c1: CircleF, c2: CircleF) bool {
    const dx = (c1[0] + c1[2]) - (c2[0] + c2[2]);
    const dy = (c1[1] + c1[2]) - (c2[1] + c2[2]);
    return std.math.sqrt(dx * dx + dy * dy) < c1[2] + c2[2];
}

pub fn intersectsCIOffset(c1: CircleI, c2: CircleI, offset: Vector2i) bool {
    const dx = (c1[0] + offset[0] + c1[2]) - (c2[0] + c2[2]);
    const dy = (c1[1] + offset[1] + c1[2]) - (c2[1] + c2[2]);
    return std.math.sqrt(dx * dx + dy * dy) < c1[2] + c2[2];
}

pub fn intersectsCFOffset(c1: CircleF, c2: CircleF, offset: Vector2f) bool {
    const dx = (c1[0] + offset[0] + c1[2]) - (c2[0] + c2[2]);
    const dy = (c1[1] + offset[1] + c1[2]) - (c2[1] + c2[2]);
    return std.math.sqrt(dx * dx + dy * dy) < c1[2] + c2[2];
}

pub fn intersectsCRI(c: CircleI, r: RectI) bool {
    const dx = c[0] - r[0] - @divTrunc(r[2], 2);
    const dy = c[1] - r[1] - @divTrunc(r[3], 2);

    if (dx > c[2] or dy > c[2])
        return false;

    return if (dx <= 0 or dy <= 0)
        true
    else
        dx * dx + dy * dy <= c[2] * c[2];
}

pub fn intersectsCRF(c: CircleF, r: RectF) bool {
    const dx = c[0] - r[0] - r[2] / 2;
    const dy = c[1] - r[1] - r[3] / 2;

    if (dx > c[2] or dy > c[2])
        return false;

    return if (dx <= 0 or dy <= 0)
        true
    else
        dx * dx + dy * dy <= c[2] * c[2];
}

pub fn intersectsCRIOffset(c: CircleI, r: RectI, offset: Vector2i) bool {
    const dx = @abs(c[0] + offset[0] - r[0]) - r[2] / 2;
    const dy = @abs(c[1] + offset[1] - r[1]) - r[3] / 2;

    if (dx > c[2] or dy > c[2])
        return false;

    return if (dx <= 0 or dy <= 0)
        true
    else
        dx * dx + dy * dy <= c[2] * c[2];
}

pub fn intersectsCRFOffset(c: CircleF, r: RectF, offset: Vector2f) bool {
    const dx = @abs(c[0] + offset[0] - r[0]) - r[2] / 2;
    const dy = @abs(c[1] + offset[1] - r[1]) - r[3] / 2;

    if (dx > c[2] or dy > c[2])
        return false;

    return if (dx <= 0 or dy <= 0)
        true
    else
        dx * dx + dy * dy <= c[2] * c[2];
}

pub fn intersectionRectI(r1: RectI, r2: RectI, result: *RectI) void {
    result[0] = @max(r1[0], r2[0]);
    result[1] = @max(r1[1], r2[1]);
    const x2 = @min(r1[0] + r1[2] - 1, r2[0] + r2[2] - 1);
    const y2 = @min(r1[1] + r1[3] - 1, r2[1] + r2[3] - 1);
    result[2] = @max(0, x2 - result[0] + 1);
    result[3] = @max(0, y2 - result[1] + 1);
}

pub fn intersectionRectF(r1: RectF, r2: RectF, result: *RectF) void {
    result[0] = @max(r1[0], r2[0]);
    result[1] = @max(r1[1], r2[1]);
    const x2 = @min(r1[0] + r1[2] - 1, r2[0] + r2[2] - 1);
    const y2 = @min(r1[1] + r1[3] - 1, r2[1] + r2[3] - 1);
    result[2] = @max(0, x2 - result[0] + 1);
    result[3] = @max(0, y2 - result[1] + 1);
}

pub fn getIntersectionRectI(r1: RectI, r2: RectI) RectI {
    const x1 = @max(r1[0], r2[0]);
    const y1 = @max(r1[1], r2[1]);
    const x2 = @min(r1[0] + r1[2] - 1, r2[0] + r2[2] - 1);
    const y2 = @min(r1[1] + r1[3] - 1, r2[1] + r2[3] - 1);

    return RectI{ x1, y1, @max(0, x2 - x1 + 1), @max(0, y2 - y1 + 1) };
}

pub fn getIntersectionRectF(r1: RectF, r2: RectF) RectF {
    const x1 = @max(r1[0], r2[0]);
    const y1 = @max(r1[1], r2[1]);
    const x2 = @min(r1[0] + r1[2] - 1, r2[0] + r2[2] - 1);
    const y2 = @min(r1[1] + r1[3] - 1, r2[1] + r2[3] - 1);

    return RectF{ x1, y1, @max(0, x2 - x1 + 1), @max(0, y2 - y1 + 1) };
}

pub fn getIntersectionNormalizedI(r1: RectI, r2: RectI) ClipI {
    const x1 = @max(r1[0], r2[0]);
    const y1 = @max(r1[1], r2[1]);
    const x2 = @min(r1[0] + r1[2] - 1, r2[0] + r2[2] - 1);
    const y2 = @min(r1[1] + r1[3] - 1, r2[1] + r2[3] - 1);

    return ClipI{ 0, 0, @max(0, x2 - x1 + 1), @max(0, y2 - y1 + 1) };
}

pub fn isRegionRectI(r1: RectI) bool {
    return r1[2] > 0 and r1[3] > 0;
}

pub fn isRegionRectF(r1: RectF) bool {
    return r1[2] > 0 and r1[3] > 0;
}

/// Color as Vector4u8
pub const Color = @Vector(4, Byte);

pub inline fn hasColor(color: ?Color) bool {
    if (color) |c|
        return c[0] != 0 or c[1] != 0 or c[2] != 0;
    return false;
}

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

fn angleX(v: Vector2f) Float {
    std.math.atan2(Float, v.y, v.x);
}
fn angleY(v: Vector2f) Float {
    std.math.atan2(Float, v.x, v.y);
}
fn radToDeg(r: Float, invert: bool) Float {
    return if (invert)
        -r * (180.0 / std.math.pi)
    else
        r * (180.0 / std.math.pi);
}

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
    const m: i32 = @intFromFloat(magnitude2i(v));
    if (m == 0) {
        v[0] = 0;
        v[1] = 0;
    } else {
        v[0] = @divTrunc(v[0], m);
        v[1] = @divTrunc(v[1], m);
    }
}
pub fn normalize3i(v: *Vector3i) void {
    const m: i32 = @intFromFloat(magnitude3i(v));
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
    const m: i32 = @intFromFloat(magnitude4i(v));
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
    const m = magnitude2f(v);
    if (m == 0) {
        v[0] = 0;
        v[1] = 0;
    } else {
        v[0] = v[0] / m;
        v[1] = v[1] / m;
    }
}

pub fn normalize3f(v: *Vector3f) void {
    const m = magnitude3f(v);
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
    const m = magnitude4f(v);
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
    const dx = p2[0] - p1[0];
    const dy = p2[1] - p1[1];

    return @sqrt(@as(f32, @floatFromInt(dx * dx + dy * dy)));
}

pub fn distance2f(p1: *Vector2f, p2: *Vector2f) f32 {
    const d = p2.* - p1.*;
    return @sqrt(d[0] * d[0] + d[1] * d[1]);
}

//////////////////////////////////////////////////////////////
//// Easing functions
//////////////////////////////////////////////////////////////

pub const Easing = struct {
    _ptr: *anyopaque,
    _f: *const fn (ptr: *anyopaque, Float) Float,

    fn init(ptr: anytype) Easing {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn f(pointer: *anyopaque, t: Float) Float {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.f(self, t);
            }
        };

        return .{
            ._ptr = ptr,
            ._f = gen.f,
        };
    }

    pub fn f(self: Easing, t: Float) Float {
        return self._f(self._ptr, t);
    }

    pub const Linear = LinearEasing.default.easing();
    pub const Exponential_In = ExponentialInEasing.default.easing();
    pub const Exponential_Out = ExponentialOutEasing.default.easing();
    pub const Exponential_In_Out = ExponentialInOutEasing.default.easing();
    pub const Sin_In = SinInEasing.default.easing();
    pub const Sin_Out = SinOutEasing.default.easing();
    pub const Sin_In_Out = SinInOutEasing.default.easing();
    pub const Circ_In = CircInEasing.default.easing();
    pub const Circ_Out = CircOutEasing.default.easing();
    pub const Circ_In_Out = CircInOutEasing.default.easing();
    pub const Back_In = BackInEasing.default.easing();
    pub const Back_Out = BackOutEasing.default.easing();
    pub const Elastic_In = ElasticInEasing.default.easing();
    pub const Elastic_Out = ElasticOutEasing.default.easing();
    pub const Bounce_In = BounceInEasing.default.easing();
    pub const Bounce_Out = BounceOutEasing.default.easing();
    pub const Quad_In = PolyInEasing.quad.easing();
    pub const Cubic_In = PolyInEasing.cubic.easing();
    pub const Quart_In = PolyInEasing.quart.easing();
    pub const Quint_In = PolyInEasing.quint.easing();
    pub const Quad_Out = PolyOutEasing.quad.easing();
    pub const Cubic_Out = PolyOutEasing.cubic.easing();
    pub const Quart_Out = PolyOutEasing.quart.easing();
    pub const Quint_Out = PolyOutEasing.quint.easing();
    pub const Quad_In_Out = PolyInOutEasing.quad.easing();
    pub const Cubic_In_Out = PolyInOutEasing.cubic.easing();
    pub const Quart_In_Out = PolyInOutEasing.quart.easing();
    pub const Quint_In_Out = PolyInOutEasing.quint.easing();
};

const LinearEasing = struct {
    var default = LinearEasing{ .exp = 1 };

    exp: Float = 2,

    fn f(_: *LinearEasing, t: Float) Float {
        return t;
    }

    fn easing(self: *LinearEasing) Easing {
        return Easing.init(self);
    }
};

const ExponentialInEasing = struct {
    var default = ExponentialInEasing{};

    fn f(_: *ExponentialInEasing, t: Float) Float {
        return std.math.pow(Float, 2, 10.0 * t - 10.0);
    }

    fn easing(self: *ExponentialInEasing) Easing {
        return Easing.init(self);
    }
};

const ExponentialOutEasing = struct {
    var default = ExponentialOutEasing{};

    fn f(_: *ExponentialOutEasing, t: Float) Float {
        return 1 - std.math.pow(Float, 2, -10.0 * t);
    }

    fn easing(self: *ExponentialOutEasing) Easing {
        return Easing.init(self);
    }
};

const ExponentialInOutEasing = struct {
    var default = ExponentialInOutEasing{};

    fn f(_: *ExponentialInOutEasing, t: Float) Float {
        const tt = t * 2;
        return if (tt <= 1)
            std.math.pow(Float, 2, 10 * tt - 10) / 2
        else
            (2 - std.math.pow(Float, 2, 10.0 - 10.0 * tt)) / 2;
    }

    fn easing(self: *ExponentialInOutEasing) Easing {
        return Easing.init(self);
    }
};

const SinInEasing = struct {
    var default = SinInEasing{};

    fn f(_: *SinInEasing, t: Float) Float {
        return 1 - std.math.cos(t * HALF_PI);
    }

    fn easing(self: *SinInEasing) Easing {
        return Easing.init(self);
    }
};

const SinOutEasing = struct {
    var default = SinOutEasing{};

    fn f(_: *SinOutEasing, t: Float) Float {
        return std.math.sin(t * HALF_PI);
    }

    fn easing(self: *SinOutEasing) Easing {
        return Easing.init(self);
    }
};

const SinInOutEasing = struct {
    var default = SinInOutEasing{};

    fn f(_: *SinInOutEasing, t: Float) Float {
        return (1 - std.math.cos(std.math.pi * t)) / 2;
    }

    fn easing(self: *SinInOutEasing) Easing {
        return Easing.init(self);
    }
};

const CircInEasing = struct {
    var default = CircInEasing{};

    fn f(_: *CircInEasing, t: Float) Float {
        return 1 - std.math.sqrt(1 - t * t);
    }

    fn easing(self: *CircInEasing) Easing {
        return Easing.init(self);
    }
};

const CircOutEasing = struct {
    var default = CircOutEasing{};

    fn f(_: *CircOutEasing, t: Float) Float {
        const tt = t - 1;
        return std.math.sqrt(1 - tt * tt);
    }

    fn easing(self: *CircOutEasing) Easing {
        return Easing.init(self);
    }
};

const CircInOutEasing = struct {
    var default = CircInOutEasing{};

    fn f(_: *CircInOutEasing, t: Float) Float {
        const tt = t * 2;
        if (tt <= 1) {
            return (1 - std.math.sqrt(1 - tt * tt)) / 2.0;
        } else {
            const ttt = tt - 2;
            return (std.math.sqrt(1 - ttt * ttt) + 1) / 2.0;
        }
    }

    fn easing(self: *CircInOutEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingBackIn(back_factor: Float) Easing {
    return (BackInEasing{ .back_factor = back_factor }).easing();
}

const BackInEasing = struct {
    var default = BackInEasing{};

    back_factor: Float = 1.70158,

    fn f(self: *BackInEasing, t: Float) Float {
        return t * t * ((self.back_factor + 1) * t - self.back_factor);
    }

    fn easing(self: *BackInEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingBackOut(back_factor: Float) Easing {
    return (BackInEasing{ .back_factor = back_factor }).easing();
}

const BackOutEasing = struct {
    var default = BackOutEasing{};

    back_factor: Float = 1.70158,

    fn f(self: *BackOutEasing, t: Float) Float {
        const tt = t - 1;
        return tt * tt * ((self.back_factor + 1) * tt + self.back_factor) + 1;
    }

    fn easing(self: *BackOutEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingElasticIn(amplitude: Float, period: Float) Easing {
    return (ElasticInEasing{ .amplitude = amplitude, .period = period }).easing();
}

const ElasticInEasing = struct {
    var default = ElasticInEasing{};

    amplitude: Float = 1,
    period: Float = 0.3,

    fn f(self: *ElasticInEasing, t: Float) Float {
        const a = if (self.amplitude >= 1) self.amplitude else 1;
        const p = self.period / TAU;
        const s = std.math.asin(1 / a) * p;
        const tt = t - 1;
        return a * std.math.pow(Float, 2, 10 * tt) * std.math.sin((s - tt) / p);
    }

    fn easing(self: *ElasticInEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingElasticOut(amplitude: Float, period: Float) Easing {
    return (ElasticOutEasing{ .amplitude = amplitude, .period = period }).easing();
}

const ElasticOutEasing = struct {
    var default = ElasticOutEasing{};

    amplitude: Float = 1,
    period: Float = 0.3,

    fn f(self: *ElasticOutEasing, t: Float) Float {
        const a = if (self.amplitude >= 1) self.amplitude else 1;
        const p = self.period / TAU;
        const s: Float = std.math.asin(1 / a) * p;
        const tt: Float = t + 1;
        return 1.0 - (a * std.math.pow(Float, 2, -10 * tt) * std.math.sin((tt + s) / p));
    }

    fn easing(self: *ElasticOutEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingBounceIn(b1: Float, b2: Float, b3: Float, b4: Float, b5: Float, b6: Float, b7: Float, b8: Float, b9: Float) Easing {
    return (BounceInEasing{ .b1 = b1, .b2 = b2, .b3 = b3, .b4 = b4, .b5 = b5, .b6 = b6, .b7 = b7, .b8 = b8, .b9 = b9 }).easing();
}

const BounceInEasing = struct {
    var default = BounceInEasing{};

    b1: Float = 4.0 / 11.0,
    b2: Float = 6.0 / 11.0,
    b3: Float = 8.0 / 11.0,
    b4: Float = 3.0 / 4.0,
    b5: Float = 9.0 / 11.0,
    b6: Float = 10.0 / 11.0,
    b7: Float = 15.0 / 16.0,
    b8: Float = 21.0 / 22.0,
    b9: Float = 63.0 / 64.0,

    fn f(self: *BounceInEasing, t: Float) Float {
        const _t: Float = 1.0 - t;
        const b0: Float = 1 / self.b1 / self.b1;

        if (_t < self.b1)
            return 1.0 - (b0 * _t * _t);
        if (_t < self.b3) {
            const tt = _t - self.b2;
            return 1.0 - (b0 * tt * tt + self.b4);
        }
        if (_t < self.b6) {
            const tt = _t - self.b5;
            return 1.0 - (b0 * tt * tt + self.b7);
        }

        const tt = _t - self.b8;
        return 1.0 - (b0 * tt * tt + self.b9);
    }

    fn easing(self: *BounceInEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingBounceOut(b1: Float, b2: Float, b3: Float, b4: Float, b5: Float, b6: Float, b7: Float, b8: Float, b9: Float) Easing {
    return (BounceOutEasing{ .b1 = b1, .b2 = b2, .b3 = b3, .b4 = b4, .b5 = b5, .b6 = b6, .b7 = b7, .b8 = b8, .b9 = b9 }).easing();
}
const BounceOutEasing = struct {
    var default = BounceOutEasing{};

    b1: Float = 4.0 / 11.0,
    b2: Float = 6.0 / 11.0,
    b3: Float = 8.0 / 11.0,
    b4: Float = 3.0 / 4.0,
    b5: Float = 9.0 / 11.0,
    b6: Float = 10.0 / 11.0,
    b7: Float = 15.0 / 16.0,
    b8: Float = 21.0 / 22.0,
    b9: Float = 63.0 / 64.0,

    fn f(self: *BounceOutEasing, t: Float) Float {
        const b0: Float = 1.0 / self.b1 / self.b1;
        if (t < self.b1)
            return b0 * t * t;
        if (t < self.b3) {
            const tt = t - self.b2;
            return b0 * tt * tt + self.b4;
        }
        if (t < self.b6) {
            const tt = t - self.b5;
            return b0 * tt * tt + self.b7;
        }

        const tt = t - self.b8;
        return b0 * tt * tt + self.b9;
    }

    fn easing(self: *BounceOutEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingPolyIn(exp: Float) Easing {
    return (PolyInEasing{ .exp = exp }).easing();
}
const PolyInEasing = struct {
    var quad = PolyInEasing{};
    var cubic = PolyInEasing{ .exp = 3 };
    var quart = PolyInEasing{ .exp = 4 };
    var quint = PolyInEasing{ .exp = 5 };

    exp: Float = 2,

    fn f(self: *PolyInEasing, t: Float) Float {
        return std.math.pow(Float, t, self.exp);
    }

    fn easing(self: *PolyInEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingPolyOut(exp: Float) Easing {
    return (PolyOutEasing{ .exp = exp }).easing();
}

const PolyOutEasing = struct {
    var quad = PolyOutEasing{ .exp = 2 };
    var cubic = PolyOutEasing{ .exp = 3 };
    var quart = PolyOutEasing{ .exp = 4 };
    var quint = PolyOutEasing{ .exp = 5 };

    exp: Float,

    fn f(self: *PolyOutEasing, t: Float) Float {
        return 1 - (std.math.pow(Float, 1 - t, self.exp));
    }

    fn easing(self: *PolyOutEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingPolyInOut(exp: Float) Easing {
    return (PolyInOutEasing{ .exp = exp }).easing();
}

const PolyInOutEasing = struct {
    var quad = PolyInOutEasing{ .exp = 2 };
    var cubic = PolyInOutEasing{ .exp = 3 };
    var quart = PolyInOutEasing{ .exp = 4 };
    var quint = PolyInOutEasing{ .exp = 5 };

    exp: Float,

    fn f(self: *PolyInOutEasing, t: Float) Float {
        const tt = t * 2;
        return if (tt <= 1)
            std.math.pow(Float, tt, self.exp) / 2
        else
            (2 - std.math.pow(Float, 2.0 - tt, self.exp)) / 2;
    }

    fn easing(self: *PolyInOutEasing) Easing {
        return Easing.init(self);
    }
};

//////////////////////////////////////////////////////////////
//// Bezier Curve
//////////////////////////////////////////////////////////////

pub const CubicBezierFunction = struct {
    p0: Vector2f,
    p1: Vector2f,
    p2: Vector2f,
    p3: Vector2f,

    pub fn fp(self: *CubicBezierFunction, t: Float, invert: bool) Vector2f {
        return if (invert)
            vt(self.p3, self.p2, self.p1, self.p0, t)
        else
            vt(self.p0, self.p1, self.p2, self.p3, t);
    }

    pub fn fax(self: *CubicBezierFunction, t: Float, invert: bool) Vector2f {
        return if (invert)
            ax(self.p3, self.p2, self.p1, self.p0, t)
        else
            ax(self.p0, self.p1, self.p2, self.p3, t);
    }

    //  u = 1f - t
    //
    //  s0 = u * u * u
    //  s1 = 3.0 * u * u * t
    //  s2 = 3.0 * u * t * t
    //  s3 = t * t * t
    //
    //  v(t) = s0 * v0 + s1 * v1 + s2 * v2 + s3 * v3
    fn vt(v0: Vector2f, v1: Vector2f, v2: Vector2f, v3: Vector2f, t: Float) Vector2f {
        const u: Float = 1.0 - t;
        const s0: Vector2f = @splat(u * u * u);
        const s1: Vector2f = @splat(3.0 * u * u * t);
        const s2: Vector2f = @splat(3.0 * u * t * t);
        const s3: Vector2f = @splat(t * t * t);

        return v0 * s0 + v1 * s1 + v2 * s2 + v3 * s3;
    }

    // v′(t)=u^2 (v1−v0) + 2tu (v2−v1) + t^2 (v3−v2)
    // ax(rad) = atan2(v'.y(t), v'.x(t))
    //
    fn ax(v0: Vector2f, v1: Vector2f, v2: Vector2f, v3: Vector2f, t: Float) Float {
        const u: Float = 1.0 - t;
        const s0: Vector2f = @splat(std.math.pow(Float, u, 2));
        const s1: Vector2f = @splat(2.0 * t * u);
        const s2: Vector2f = @splat(std.math.pow(Float, t, 2.0));

        return angleX(s0 * (v1 - v0) + s1 * (v2 - v1) + s2 * (v3 - v2));
    }
};

//////////////////////////////////////////////////////////////
//// Bit Mask
//////////////////////////////////////////////////////////////

pub const BitMask = struct {
    width: usize,
    height: usize,
    bits: BitSet,

    pub fn new(allocator: std.mem.Allocator, width: usize, height: usize) BitMask {
        return BitMask{
            .width = width,
            .height = height,
            .bits = BitSet.newEmpty(allocator, width * height),
        };
    }

    pub fn deinit(self: *BitMask) void {
        self.bits.deinit();
        self.bits = undefined;
    }

    pub fn isEmpty(self: *BitMask) bool {
        return self.bits.nextSetBit(0) == null;
    }

    pub fn fill(self: *BitMask) void {
        self.bits.fill();
    }

    pub fn reset(self: *BitMask, width: usize, height: usize) void {
        self.width = width;
        self.height = height;
        self.bits.clear();
        self.bits.resize(width * height, false);
    }

    pub fn clear(self: *BitMask) void {
        self.bits.clear();
    }

    pub fn setBitAt(self: *BitMask, x: usize, y: usize) void {
        if (x >= self.width or y >= self.height)
            return;

        self.bits.set(y * self.width + x);
    }

    pub fn setBitValueAt(self: *BitMask, x: usize, y: usize, value: bool) void {
        if (x >= self.width or y >= self.height)
            return;

        self.bits.setValue(y * self.width + x, value);
    }

    pub fn isBitSetAt(self: BitMask, x: usize, y: usize) bool {
        if (x >= self.width or y >= self.height)
            return false;

        return self.bits.isSet(y * self.width + x);
    }

    pub fn setRectI(self: *BitMask, rect: RectI, value: bool) void {
        if (rect[2] <= 0 or rect[3] <= 0)
            return;

        self.setClip(rectIToClip(.{
            if (rect[0] < 0) 0 else rect[0],
            if (rect[1] < 0) 0 else rect[1],
            if (rect[0] < 0) rect[0] + rect[2] else rect[2],
            if (rect[1] < 0) rect[1] + rect[3] else rect[3],
        }), value);
    }

    pub fn setRectFOffset(self: *BitMask, rect: RectF, offset: Vector2f, value: bool) void {
        setRectF(self, .{ rect[0] + offset[0], rect[1] + offset[1], rect[2], rect[3] }, value);
    }

    pub fn setRectF(self: *BitMask, rect: RectF, value: bool) void {
        if (rect[2] <= 0 or rect[3] <= 0)
            return;

        self.setClip(rectFToClip(.{
            if (rect[0] < 0) 0 else rect[0],
            if (rect[1] < 0) 0 else rect[1],
            if (rect[0] < 0) rect[0] + rect[2] else rect[2],
            if (rect[1] < 0) rect[1] + rect[3] else rect[3],
        }), value);
    }

    pub fn setClip(self: *BitMask, clip: ClipI, value: bool) void {
        if (clip[0] >= self.width or clip[1] >= self.height)
            return; // clip out of range

        for (clip[1]..@min(clip[1] + clip[3], self.height)) |y| {
            for (clip[0]..@min(clip[0] + clip[2], self.width)) |x| {
                self.bits.setValue(y * self.width + x, value);
            }
        }
    }

    pub fn setCircleF(self: *BitMask, circle: CircleF, value: bool) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                if (utils.containsCircF(circle, @floatFromInt(x), @floatFromInt(y)))
                    self.bits.setValue(y * self.width + x, value);
            }
        }
    }

    pub fn setCircleI(self: *BitMask, circle: CircleI, value: bool) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                if (utils.containsCircI(circle, @intCast(x), @intCast(y)))
                    self.bits.setValue(y * self.width + x, value);
            }
        }
    }

    pub fn setIntersectionF(
        self: *BitMask,
        other: BitMask,
        offset: Vector2f,
        comptime bit_op: BitOperation,
    ) void {
        setIntersection(
            self,
            other,
            .{
                @intFromFloat(@floor(offset[0])),
                @intFromFloat(@floor(offset[1])),
            },
            bit_op,
        );
    }

    pub fn setIntersection(
        self: *BitMask,
        other: BitMask,
        offset: ?Vector2i,
        comptime bit_op: BitOperation,
    ) void {
        if (offset) |off| {
            for (0..self.height) |y| {
                for (0..self.width) |x| {
                    const x1: CInt = utils.usize_cint(x) - off[0];
                    const y1: CInt = utils.usize_cint(y) - off[1];
                    if (x1 >= 0 and y1 >= 0 and x1 < other.width and y1 < other.height)
                        self.setBitValueAt(
                            x,
                            y,
                            bit_op(self.isBitSetAt(x, y), other.isBitSetAt(@intCast(x1), @intCast(y1))),
                        );
                }
            }
        } else {
            for (0..self.height) |y|
                for (0..self.width) |x|
                    self.setBitValueAt(x, y, bit_op(self.isBitSetAt(x, y), other.isBitSetAt(x, y)));
        }
    }

    pub fn format(
        self: BitMask,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("BitMask[{any}|{any}]\n", .{ self.width, self.height });
        for (0..self.height) |y| {
            try writer.writeAll("  ");
            for (0..self.width) |x| {
                if (self.isBitSetAt(x, y)) {
                    try writer.writeAll("1,");
                } else {
                    try writer.writeAll("0,");
                }
            }
            try writer.writeAll("\n");
        }
    }
};
