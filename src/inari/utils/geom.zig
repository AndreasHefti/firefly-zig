const std = @import("std");
const utils = @import("utils.zig");
const CInt = utils.CInt;
const Float = utils.Float;
const Byte = utils.Byte;
const BitSet = utils.BitSet;

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

pub fn intersectsRectI(r1: RectI, r2: RectI) bool {
    return !(r2[0] >= r1[0] + r1[2] or r2[0] + r2[2] <= r1[0] or r2[1] >= r1[1] + r1[3] or r2[1] + r2[3] <= r1[1]);
}

pub fn intersectionRectI(r1: RectI, r2: RectI) RectI {
    var x1 = @max(r1[0], r2[0]);
    var y1 = @max(r1[1], r2[1]);
    var x2 = @min(r1[0] + r1[2] - 1, r2[0] + r2[2] - 1);
    var y2 = @min(r1[1] + r1[3] - 1, r2[1] + r2[3] - 1);

    return RectI{ x1, y1, @max(0, x2 - x1 + 1), @max(0, y2 - y1 + 1) };
}

pub fn isRegionRectI(r1: RectI) bool {
    return r1[2] > 0 and r1[3] > 0;
}

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
};

pub const Easing_Linear: Easing = LinearEasing.default.easing();
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

pub const Easing_Exponential_In: Easing = ExponentialInEasing.default.easing();
const ExponentialInEasing = struct {
    var default = ExponentialInEasing{};

    fn f(_: *ExponentialInEasing, t: Float) Float {
        return std.math.pow(Float, 2, 10.0 * t - 10.0);
    }

    fn easing(self: *ExponentialInEasing) Easing {
        return Easing.init(self);
    }
};

pub const Easing_Exponential_Out: Easing = ExponentialOutEasing.default.easing();
const ExponentialOutEasing = struct {
    var default = ExponentialOutEasing{};

    fn f(_: *ExponentialOutEasing, t: Float) Float {
        return 1 - std.math.pow(Float, 2, -10.0 * t);
    }

    fn easing(self: *ExponentialOutEasing) Easing {
        return Easing.init(self);
    }
};

pub const Easing_Exponential_In_Out: Easing = ExponentialInOutEasing.default.easing();
const ExponentialInOutEasing = struct {
    var default = ExponentialInOutEasing{};

    fn f(_: *ExponentialInOutEasing, t: Float) Float {
        var tt = t * 2;
        return if (tt <= 1)
            std.math.pow(Float, 2, 10 * tt - 10) / 2
        else
            2 - std.math.pow(Float, 2, 10.0 - 10.0 * tt) / 2;
    }

    fn easing(self: *ExponentialInOutEasing) Easing {
        return Easing.init(self);
    }
};

pub const Easing_Sin_In: Easing = SinInEasing.default.easing();
const SinInEasing = struct {
    var default = SinInEasing{};

    fn f(_: *SinInEasing, t: Float) Float {
        return 1 - std.math.cos(t * HALF_PI);
    }

    fn easing(self: *SinInEasing) Easing {
        return Easing.init(self);
    }
};

pub const Easing_Sin_Out: Easing = SinOutEasing.default.easing();
const SinOutEasing = struct {
    var default = SinOutEasing{};

    fn f(_: *SinOutEasing, t: Float) Float {
        return std.math.sin(t * HALF_PI);
    }

    fn easing(self: *SinOutEasing) Easing {
        return Easing.init(self);
    }
};

pub const Easing_Sin_In_Out: Easing = SinInOutEasing.default.easing();
const SinInOutEasing = struct {
    var default = SinInOutEasing{};

    fn f(_: *SinInOutEasing, t: Float) Float {
        return (1 - std.math.cos(std.math.pi * t)) / 2;
    }

    fn easing(self: *SinInOutEasing) Easing {
        return Easing.init(self);
    }
};

pub const Easing_Circ_In: Easing = CircInEasing.default.easing();
const CircInEasing = struct {
    var default = CircInEasing{};

    fn f(_: *CircInEasing, t: Float) Float {
        return 1 - std.math.sqrt(1 - t * t);
    }

    fn easing(self: *CircInEasing) Easing {
        return Easing.init(self);
    }
};

pub const Easing_Circ_Out: Easing = CircOutEasing.default.easing();
const CircOutEasing = struct {
    var default = CircOutEasing{};

    fn f(_: *CircOutEasing, t: Float) Float {
        var tt = t - 1;
        return std.math.sqrt(1 - tt * tt);
    }

    fn easing(self: *CircOutEasing) Easing {
        return Easing.init(self);
    }
};

pub const Easing_Circ_In_Out: Easing = CircInOutEasing.default.easing();
const CircInOutEasing = struct {
    var default = CircInOutEasing{};

    fn f(_: *CircInOutEasing, t: Float) Float {
        var tt = t * 2;
        if (tt <= 1) {
            return (1 - std.math.sqrt(1 - tt * tt)) / 2.0;
        } else {
            var ttt = tt - 2;
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
pub const Easing_Back_In: Easing = BackInEasing.default.easing();
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
pub const Easing_Back_Out: Easing = BackOutEasing.default.easing();
const BackOutEasing = struct {
    var default = BackOutEasing{};

    back_factor: Float = 1.70158,

    fn f(self: *BackOutEasing, t: Float) Float {
        var tt = t - 1;
        return tt * tt * ((self.back_factor + 1) * tt + self.back_factor) + 1;
    }

    fn easing(self: *BackOutEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingElasticIn(amplitude: Float, period: Float) Easing {
    return (ElasticInEasing{ .amplitude = amplitude, .period = period }).easing();
}
pub const Easing_Elastic_In: Easing = ElasticInEasing.default.easing();
const ElasticInEasing = struct {
    var default = ElasticInEasing{};

    amplitude: Float = 1,
    period: Float = 0.3,

    fn f(self: *ElasticInEasing, t: Float) Float {
        var a = if (self.amplitude >= 1) self.amplitude else 1;
        var p = self.period / TAU;
        var s = std.math.asin(1 / a) * p;
        var tt = t - 1;
        return a * std.math.pow(Float, 2, 10 * tt) * std.math.sin((s - tt) / p);
    }

    fn easing(self: *ElasticInEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingElasticOut(amplitude: Float, period: Float) Easing {
    return (ElasticOutEasing{ .amplitude = amplitude, .period = period }).easing();
}
pub const Easing_Elastic_Out: Easing = ElasticOutEasing.default.easing();
const ElasticOutEasing = struct {
    var default = ElasticOutEasing{};

    amplitude: Float = 1,
    period: Float = 0.3,

    fn f(self: *ElasticOutEasing, t: Float) Float {
        var a = if (self.amplitude >= 1) self.amplitude else 1;
        var p = self.period / TAU;
        var s = std.math.asin(1 / a) * p;
        var tt = t - 1;
        return 1 - a * std.math.pow(Float, 2, -10 * tt) * std.math.sin((tt - s) / p);
    }

    fn easing(self: *ElasticOutEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingBounceIn(b1: Float, b2: Float, b3: Float, b4: Float, b5: Float, b6: Float, b7: Float, b8: Float, b9: Float) Easing {
    return (BounceInEasing{ .b1 = b1, .b2 = b2, .b3 = b3, .b4 = b4, .b5 = b5, .b6 = b6, .b7 = b7, .b8 = b8, .b9 = b9 }).easing();
}
pub const Easing_Bounce_In: Easing = BounceInEasing.default.easing();
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
        var _t: Float = 1.0 - t;
        var b0: Float = 1 / self.b1 / self.b1;

        if (_t < self.b1)
            return 1.0 - (b0 * _t * _t);
        if (_t < self.b3) {
            var tt = _t - self.b2;
            return 1.0 - (b0 * tt * tt + self.b4);
        }
        if (_t < self.b6) {
            var tt = _t - self.b5;
            return 1.0 - (b0 * tt * tt + self.b7);
        }

        var tt = _t - self.b8;
        return 1.0 - (b0 * tt * tt + self.b9);
    }

    fn easing(self: *BounceInEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingBounceOut(b1: Float, b2: Float, b3: Float, b4: Float, b5: Float, b6: Float, b7: Float, b8: Float, b9: Float) Easing {
    return (BounceOutEasing{ .b1 = b1, .b2 = b2, .b3 = b3, .b4 = b4, .b5 = b5, .b6 = b6, .b7 = b7, .b8 = b8, .b9 = b9 }).easing();
}
pub const Easing_Bounce_Out: Easing = BounceOutEasing.default.easing();
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
        var b0: Float = 1.0 / self.b1 / self.b1;
        if (t < self.b1)
            return b0 * t * t;
        if (t < self.b3) {
            var tt = t - self.b2;
            return b0 * tt * tt + self.b4;
        }
        if (t < self.b6) {
            var tt = t - self.b5;
            return b0 * tt * tt + self.b7;
        }

        var tt = t - self.b8;
        return b0 * tt * tt + self.b9;
    }

    fn easing(self: *BounceOutEasing) Easing {
        return Easing.init(self);
    }
};

pub fn easingPolyIn(exp: Float) Easing {
    return (PolyInEasing{ .exp = exp }).easing();
}
pub const Easing_Quad_In: Easing = PolyInEasing.quad.easing();
pub const Easing_Cubic_In: Easing = PolyInEasing.cubic.easing();
pub const Easing_Quart_In: Easing = PolyInEasing.quart.easing();
pub const Easing_Quint_In: Easing = PolyInEasing.quint.easing();
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
pub const Easing_Quad_Out: Easing = PolyOutEasing.quad.easing();
pub const Easing_Cubic_Out: Easing = PolyOutEasing.cubic.easing();
pub const Easing_Quart_Out: Easing = PolyOutEasing.quart.easing();
pub const Easing_Quint_Out: Easing = PolyOutEasing.quint.easing();
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
pub const Easing_Quad_In_Out: Easing = PolyInOutEasing.quad.easing();
pub const Easing_Cubic_In_Out: Easing = PolyInOutEasing.cubic.easing();
pub const Easing_Quart_In_Out: Easing = PolyInOutEasing.quart.easing();
pub const Easing_Quint_In_Out: Easing = PolyInOutEasing.quint.easing();
const PolyInOutEasing = struct {
    var quad = PolyInOutEasing{ .exp = 2 };
    var cubic = PolyInOutEasing{ .exp = 3 };
    var quart = PolyInOutEasing{ .exp = 4 };
    var quint = PolyInOutEasing{ .exp = 5 };

    exp: Float,

    fn f(self: *PolyInOutEasing, t: Float) Float {
        var tt = t * 2;
        return if (tt <= 1)
            std.math.pow(Float, tt, self.exp) / 2
        else
            2 - std.math.pow(Float, 2.0 - tt, self.exp) / 2;
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
        var u: Float = 1.0 - t;
        var s0: Vector2f = @splat(u * u * u);
        var s1: Vector2f = @splat(3.0 * u * u * t);
        var s2: Vector2f = @splat(3.0 * u * t * t);
        var s3: Vector2f = @splat(t * t * t);

        return v0 * s0 + v1 * s1 + v2 * s2 + v3 * s3;
    }

    // v′(t)=u^2 (v1−v0) + 2tu (v2−v1) + t^2 (v3−v2)
    // ax(rad) = atan2(v'.y(t), v'.x(t))
    //
    fn ax(v0: Vector2f, v1: Vector2f, v2: Vector2f, v3: Vector2f, t: Float) Float {
        var u: Float = 1.0 - t;
        var s0: Vector2f = @splat(std.math.pow(Float, u, 2));
        var s1: Vector2f = @splat(2.0 * t * u);
        var s2: Vector2f = @splat(std.math.pow(Float, t, 2.0));

        return angleX(s0 * (v1 - v0) + s1 * (v2 - v1) + s2 * (v3 - v2));
    }
};

//////////////////////////////////////////////////////////////
//// Bit Mask
//////////////////////////////////////////////////////////////

pub const BitMask = struct {

    // BitMask properties
    width: usize,
    height: usize,
    bits: BitSet,

    // internal references
    _length: usize,
    _temp_bits: BitSet,
    _allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator, width: usize, height: usize) BitMask {
        const l = width * height;
        return BitMask{
            .width = width,
            .height = height,
            .bits = BitSet.newEmpty(allocator, l) catch unreachable,
            ._length = l,
            ._temp_bits = BitSet.newEmpty(allocator, l) catch unreachable,
            ._allocator = allocator,
        };
    }

    pub fn deinit(self: *BitMask) void {
        self.bits.deinit();
        self._temp_bits.deinit();
        self.width = 0;
        self.height = 0;
        self.bits = undefined;
        self._allocator = undefined;
    }

    pub fn isSet(self: BitMask, x: usize, y: usize) bool {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height)
            return false;

        return self.bits.isSet(y * self.width + x);
    }

    pub fn setBit(self: *BitMask, index: usize) void {
        self.bits.set(index);
    }

    pub fn setBitAt(self: *BitMask, x: usize, y: usize) void {
        self.setBitValueAt(x, y, true);
    }

    pub fn setBitValueAt(self: *BitMask, x: usize, y: usize, bit: bool) void {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height)
            return;

        self.bits.setValue(y * self.width + x, bit);
    }

    pub fn setBits(self: *BitMask, bits: []u8) void {
        for (0..bits.len) |i| {
            if (bits[i] == 1)
                self.bits.set(i)
            else
                self.bits.setValue(i, false);
        }
    }

    pub fn setRegion(self: *BitMask, region: RectI, bit: bool) void {
        if (!isRegionRectI(region))
            return;

        for (0..utils.i32_usize(region[3])) |y| {
            for (0..utils.i32_usize(region[2])) |x| {
                const rel_x: i32 = region[0] + utils.usize_i32(x);
                const rel_y: i32 = region[1] + utils.usize_i32(y);
                if (rel_x >= 0 and rel_y >= 0 and rel_x < self.width and rel_y < self.height)
                    self.bits.setValue(utils.i32_usize(rel_y) * self.width + utils.i32_usize(rel_x), bit);
            }
        }
    }

    pub fn setRegionFrom(self: *BitMask, region: RectI, bits: []const u8) void {
        if (!isRegionRectI(region))
            return;

        for (0..utils.i32_usize(region[3])) |y| {
            for (0..utils.i32_usize(region[2])) |x| {
                const rel_x: i32 = region[0] + utils.usize_i32(x);
                const rel_y: i32 = region[1] + utils.usize_i32(y);
                if (rel_x >= 0 and rel_y >= 0 and rel_x < self.width and rel_y < self.height)
                    self.bits.setValue(
                        utils.i32_usize(rel_y) * self.width + utils.i32_usize(rel_x),
                        bits[y * utils.i32_usize(region[2]) + x] != 0,
                    );
            }
        }
    }

    pub fn clip(self: BitMask, region: RectI) BitMask {
        var empty = getEmptyIntersectionMask(self, region);
        if (empty) |*result| {
            defer result.deinit();
            result.fill();
            return createIntersectionMask(
                self,
                result.*,
                if (region[0] < 0) 0 else region[0],
                if (region[1] < 0) 0 else region[1],
                bitOpAND,
            );
        } else {
            return BitMask.new(self._allocator, 0, 0);
        }
    }

    pub fn createIntersectionMask(
        self: BitMask,
        other: BitMask,
        x_offset: i32,
        y_offset: i32,
        comptime bit_op: BitOperation,
    ) BitMask {
        var empty = getEmptyIntersectionMask(self, .{
            x_offset,
            y_offset,
            utils.usize_i32(other.width),
            utils.usize_i32(other.height),
        });
        if (empty) |*result| {
            for (0..result.height) |y| {
                for (0..result.width) |x| {
                    var x1: usize = if (x_offset > 0) x + utils.i32_usize(x_offset) else x;
                    var y1: usize = if (y_offset > 0) y + utils.i32_usize(y_offset) else y;
                    var x2: usize = if (x_offset < 0) x + utils.i32_usize(x_offset) else x;
                    var y2: usize = if (y_offset < 0) y + utils.i32_usize(y_offset) else y;
                    result.setBitValueAt(x, y, bit_op(self.isSet(x1, y1), other.isSet(x2, y2)));
                }
            }

            return result.*;
        } else {
            return BitMask.new(self._allocator, 0, 0);
        }
    }

    pub fn fill(self: *BitMask) void {
        clearMask(self);
        for (0..self._length) |i| {
            self.bits.set(i);
        }
    }

    pub fn clearMask(self: *BitMask) void {
        self.bits.clear();
        self._temp_bits.clear();
    }

    pub fn format(
        self: BitMask,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("BitMask[{d}|{d}]\n", .{ self.width, self.height });
        for (0..self.height) |y| {
            try writer.writeAll("  ");
            for (0..self.width) |x| {
                if (self.isSet(x, y)) {
                    try writer.writeAll("1,");
                } else {
                    try writer.writeAll("0,");
                }
            }
            try writer.writeAll("\n");
        }
    }

    fn getEmptyIntersectionMask(self: BitMask, region: RectI) ?BitMask {
        var intersection_region = intersectionRectI(
            .{ 0, 0, utils.usize_i32(self.width), utils.usize_i32(self.height) },
            region,
        );

        if (!isRegionRectI(intersection_region))
            return null;

        return BitMask.new(
            self._allocator,
            utils.i32_usize(intersection_region[2]),
            utils.i32_usize(intersection_region[3]),
        );
    }
};
