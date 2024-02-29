pub const Vec2 = @Vector(2, f32);

pub inline fn splat2(s: f32) Vec2 {
    return .{ s, s };
}

pub inline fn lenSq2(v: Vec2) Vec2 {
    return dot2(v, v);
}

pub inline fn len2(v: Vec2) Vec2 {
    return @sqrt(lenSq2(v));
}

pub inline fn dot2(v0: Vec2, v1: Vec2) Vec2 {
    var xmm0 = v0 * v1;
    // | x0*x1 | y0*y1 |
    const xmm1 = swizzle2(xmm0, .y, .x);
    // | y0*y1 | -- |
    xmm0 = .{ xmm0[0] + xmm1[0], xmm0[1] };
    // | x0*x1 + y0*y1 | -- |
    return swizzle2(xmm0, .x, .x);
}

pub inline fn norm2(v: Vec2) Vec2 {
    return v / len2(v);
}

const Vec2Comp = enum { x, y };

inline fn swizzle2(v: Vec2, comptime x: Vec2Comp, comptime y: Vec2Comp) Vec2 {
    return @shuffle(f32, v, undefined, [2]i32{
        @intFromEnum(x),
        @intFromEnum(y),
    });
}
