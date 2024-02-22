const std = @import("std");
const utils = @import("utils.zig");
const CInt = utils.CInt;
const Float = utils.Float;
const Byte = utils.Byte;

pub const HALF_PI: Float = std.math.pi / 2;
pub const TAU: Float = 2 * std.math.pi;
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

//////////////////////////////////////////////////////////////
//// Easing functions
//////////////////////////////////////////////////////////////

pub const Easing = struct {
    ptr: *anyopaque,
    f: *const fn (ptr: *anyopaque, Float) Float,

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
            .ptr = ptr,
            .f = gen.f,
        };
    }

    fn get(self: Easing, t: Float) Float {
        return self.f(self.ptr, t);
    }
};

pub const Easing_Linear: Easing = LinearEasing.default.easing();
const LinearEasing = struct {
    var default = LinearEasing{};

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

pub const Easing_Exponential_InOut: Easing = ExponentialInOutEasing.default.easing();
const ExponentialInOutEasing = struct {
    var default = ExponentialInOutEasing{};

    fn f(_: *ExponentialInOutEasing, t: Float) Float {
        var tt = t * 2;
        return if (tt <= 1)
            std.math.pow(2, 10 * tt - 10) / 2
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
        return if (tt <= 1) {
            (1 - std.math.sqrt(1 - tt * tt)) / 2;
        } else {
            var ttt = tt - 2;
            (std.math.sqrt(1 - ttt * ttt) + 1) / 2;
        };
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

    b1: Float = 4 / 11,
    b2: Float = 6 / 11,
    b3: Float = 8 / 11,
    b4: Float = 3 / 4,
    b5: Float = 9 / 11,
    b6: Float = 10 / 11,
    b7: Float = 15 / 16,
    b8: Float = 21 / 22,
    b9: Float = 63 / 64,

    fn f(self: *BounceInEasing, t: Float) Float {
        var _t = 1 - t;
        var b0: Float = 1 / self.b1 / self.b1;
        return 1 - switch (_t) {
            _t < self.b1 => return self.b0 * _t * _t,
            _t < self.b3 => {
                var tt = _t - self.b2;
                b0 * tt * tt + self.b4;
            },
            _t < self.b6 => {
                var tt = _t - self.b5;
                b0 * tt * tt + self.b7;
            },
            else => {
                var tt = _t - self.b8;
                b0 * tt * tt + self.b9;
            },
        };
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

    b1: Float = 4 / 11,
    b2: Float = 6 / 11,
    b3: Float = 8 / 11,
    b4: Float = 3 / 4,
    b5: Float = 9 / 11,
    b6: Float = 10 / 11,
    b7: Float = 15 / 16,
    b8: Float = 21 / 22,
    b9: Float = 63 / 64,

    fn f(self: *BounceOutEasing, t: Float) Float {
        var b0: Float = 1 / self.b1 / self.b1;
        return switch (t) {
            t < self.b1 => return self.b0 * t * t,
            t < self.b3 => {
                var tt = t - self.b2;
                b0 * tt * tt + self.b4;
            },
            t < self.b6 => {
                var tt = t - self.b5;
                b0 * tt * tt + self.b7;
            },
            else => {
                var tt = t - self.b8;
                b0 * tt * tt + self.b9;
            },
        };
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
    var quad = PolyInEasing{ .exp = 2 };
    var cubic = PolyInEasing{ .exp = 3 };
    var quart = PolyInEasing{ .exp = 4 };
    var quint = PolyInEasing{ .exp = 5 };

    exp: Float,

    fn f(self: *PolyInEasing, t: Float) Float {
        return std.math.pow(Float, t, self.exp);
    }

    fn easing(self: PolyInEasing) Easing {
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

    fn easing(self: PolyOutEasing) Easing {
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
            std.math.pow(tt, self.exp) / 2
        else
            2 - std.math.pow(2.0 - tt, self.exp) / 2;
    }

    fn easing(self: PolyInOutEasing) Easing {
        return Easing.init(self);
    }
};

// test easing
test "easing interface" {
    try std.testing.expect(2.1230000 == Easing_Linear.get(2.123));
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
