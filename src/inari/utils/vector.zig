const std = @import("std");

/// Two dimensional vector of i32 values
pub const Vector2i = [2]i32;
/// Three dimensional vector of i32 values
pub const Vector3i = [3]i32;
/// Four Two dimensional vector of i32 values
pub const Vector4i = [4]i32;

/// Two dimensional vector of u8 values
pub const Vector2u8 = [2]u8;
/// Three dimensional vector of u8 values
pub const Vector3u8 = [3]u8;
/// Four Two dimensional vector of u8 values
pub const Vector4u8 = [4]u8;

/// Two dimensional vector of f32 values
pub const Vector2f = [2]f32;
/// Three dimensional vector of f32 values
pub const Vector3f = [3]f32;
/// Four Two dimensional vector of f32 values
pub const Vector4f = [4]f32;

pub const vecmath = struct {

    // Integer
    pub inline fn i_add(dest: []i32, source: []i32) void {
        for (0..dest.len) |i| {
            if (source.len > i) {
                dest[i] += source[i];
            }
        }
    }
    pub inline fn i_minus(dest: []i32, source: []i32) void {
        for (0..dest.len) |i| {
            if (source.len > i) {
                dest[i] -= source[i];
            }
        }
    }
    pub inline fn i_times(dest: []i32, source: []i32) void {
        for (0..dest.len) |i| {
            if (source.len > i) {
                dest[i] *= source[i];
            }
        }
    }
    pub inline fn i_div(dest: []i32, source: []i32) void {
        for (0..dest.len) |i| {
            if (source.len > i) {
                dest[i] = @divTrunc(dest[i], source[i]);
            }
        }
    }

    pub inline fn i_addScalar(dest: []i32, scalar: i32) void {
        for (0..dest.len) |i| {
            dest[i] += scalar;
        }
    }
    pub inline fn i_minusScalar(dest: []i32, scalar: i32) void {
        for (0..dest.len) |i| {
            dest[i] -= scalar;
        }
    }
    pub inline fn i_timesScalar(dest: []i32, scalar: i32) void {
        for (0..dest.len) |i| {
            dest[i] *= scalar;
        }
    }
    pub inline fn i_divScalar(dest: []i32, scalar: i32) void {
        for (0..dest.len) |i| {
            dest[i] = @divTrunc(dest[i], scalar);
        }
    }

    // Float
    pub inline fn f_add(dest: []f32, source: []f32) void {
        for (0..dest.len) |i| {
            if (source.len > i) {
                dest[i] += source[i];
            }
        }
    }
    pub inline fn f_minus(dest: []f32, source: []f32) void {
        for (0..dest.len) |i| {
            if (source.len > i) {
                dest[i] -= source[i];
            }
        }
    }
    pub inline fn f_times(dest: []f32, source: []f32) void {
        for (0..dest.len) |i| {
            if (source.len > i) {
                dest[i] *= source[i];
            }
        }
    }
    pub inline fn f_div(dest: []f32, source: []f32) void {
        for (0..dest.len) |i| {
            if (source.len > i) {
                dest[i] = @divTrunc(dest[i], source[i]);
            }
        }
    }

    // Float int scalar
    pub inline fn f_addScalar(dest: []f32, scalar: i32) void {
        for (0..dest.len) |i| {
            dest[i] += scalar;
        }
    }
    pub inline fn f_minusScalar(dest: []f32, scalar: i32) void {
        for (0..dest.len) |i| {
            dest[i] -= scalar;
        }
    }
    pub inline fn f_timesScalar(dest: []f32, scalar: i32) void {
        for (0..dest.len) |i| {
            dest[i] *= scalar;
        }
    }
    pub inline fn f_divScalar(dest: []f32, scalar: i32) void {
        for (0..dest.len) |i| {
            dest[i] = @divTrunc(dest[i], scalar);
        }
    }

    // Float float scalar
    pub inline fn f_addScalarf(dest: []f32, scalar: f32) void {
        for (0..dest.len) |i| {
            dest[i] += scalar;
        }
    }
    pub inline fn f_minusScalarf(dest: []f32, scalar: f32) void {
        for (0..dest.len) |i| {
            dest[i] -= scalar;
        }
    }
    pub inline fn f_timesScalarf(dest: []f32, scalar: f32) void {
        for (0..dest.len) |i| {
            dest[i] *= scalar;
        }
    }
    pub inline fn f_divScalarf(dest: []f32, scalar: f32) void {
        for (0..dest.len) |i| {
            dest[i] = @divTrunc(dest[i], scalar);
        }
    }
};

test "add integer" {
    var v1i = Vector2i{ 0, 0 };
    var v2i = Vector3i{ 1, 2, 1 };
    var v3i = Vector4i{ 2, 2, 2, 2 };

    vecmath.i_add(&v1i, &v2i);
    vecmath.i_add(&v2i, &v1i);

    try std.testing.expect(v1i[0] == 1);
    try std.testing.expect(v1i[1] == 2);

    try std.testing.expect(v2i[0] == 2);
    try std.testing.expect(v2i[1] == 4);
    try std.testing.expect(v2i[2] == 1);

    vecmath.i_add(&v3i, &v2i);

    try std.testing.expect(v3i[0] == 4);
    try std.testing.expect(v3i[1] == 6);
    try std.testing.expect(v3i[2] == 3);
    try std.testing.expect(v3i[3] == 2);
}

test "float add int scalar" {
    var v1 = Vector3f{ 1, 2, 3 };
    vecmath.f_addScalar(&v1, 2);

    try std.testing.expect(v1[0] == 3);
    try std.testing.expect(v1[1] == 4);
    try std.testing.expect(v1[2] == 5);
}
