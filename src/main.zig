const std = @import("std");
const vec = @import("vec.zig");
const GFX = @import("gfx.zig").GFX;

// TODO If timescale / iterations >= FPS / 120 then this goes crazy
const CFG = .{
    .air_resistance = 2,
    .draw = true,
    .gravity = 4,
    .min_iters = 1,
    .max_step = 0.005, // 1 / 200
    .tension = 10000,
    .timescale = 1,
    .vsync = true,
};

pub const Link = struct {
    length: f32,

    pub fn init(length: ?f32) Link {
        return .{
            .length = length orelse 0.2,
        };
    }
};

pub const Point = struct {
    vel: vec.Vec2,
    pin: bool,

    pub fn init(vel: ?vec.Vec2, pin: ?bool) Point {
        return .{
            .vel = vel orelse .{ 0, 0 },
            .pin = pin orelse false,
        };
    }
};

pub const Net = struct {
    // The net contains points and links between them
    // In this example they are arranged in a grid
    const WIDTH = 20;
    const HEIGHT = 20;
    const GAP = 1.0 / 13.0;
    const OFFSET = vec.Vec2{ 0, GAP * 2.3 };

    links: std.ArrayList(Link),
    link_indices: std.ArrayList(c_uint),
    points: std.ArrayList(Point),
    point_positions: std.ArrayList(vec.Vec2),

    pub fn init(alloc: std.mem.Allocator) !Net {
        var net = Net{
            .links = undefined,
            .link_indices = undefined,
            .points = undefined,
            .point_positions = undefined,
        };

        net.links = @TypeOf(net.links).init(alloc);
        errdefer net.links.deinit();
        net.link_indices = @TypeOf(net.link_indices).init(alloc);
        errdefer net.link_indices.deinit();
        net.points = @TypeOf(net.points).init(alloc);
        errdefer net.points.deinit();
        net.point_positions = @TypeOf(net.point_positions).init(alloc);
        errdefer net.point_positions.deinit();

        // Create links and points
        for (0..Net.HEIGHT) |row| {
            for (0..Net.WIDTH) |col| {
                // Create links
                if (col + 1 < Net.WIDTH) try net.addLink(
                    row * Net.WIDTH + col,
                    row * Net.WIDTH + col + 1,
                    GAP,
                );
                if (row + 1 < Net.HEIGHT) try net.addLink(
                    col + Net.WIDTH * row,
                    col + Net.WIDTH * (row + 1),
                    GAP,
                );
                // Create points
                var pos = vec.Vec2{
                    @floatFromInt(col),
                    @floatFromInt(row),
                };
                pos -= vec.Vec2{
                    @floatFromInt(Net.WIDTH - 1),
                    @floatFromInt(Net.HEIGHT - 1),
                } / vec.splat2(2);
                pos = pos * vec.splat2(Net.GAP) + Net.OFFSET;
                try net.addPoint(
                    pos,
                    .{
                        @as(f32, @floatFromInt(row + col)) * 0.1,
                        -@as(f32, @floatFromInt(row + col)) * 0.1,
                    },
                    row + 1 == Net.HEIGHT,
                );
                // try net.addPoint(pos, row + 1 == Net.HEIGHT and (col == 0 or col + 1 == Net.WIDTH));
            }
        }

        return net;
    }

    pub fn kill(net: *Net) void {
        net.links.deinit();
        net.link_indices.deinit();
        net.points.deinit();
        net.point_positions.deinit();
    }

    fn addLink(net: *Net, index_l: usize, index_r: usize, length: ?f32) !void {
        try net.links.append(Link.init(length));
        try net.link_indices.append(@intCast(index_l));
        try net.link_indices.append(@intCast(index_r));
    }

    fn addPoint(net: *Net, pos: vec.Vec2, vel: vec.Vec2, pin: ?bool) !void {
        try net.points.append(Point.init(vel, pin));
        try net.point_positions.append(pos);
    }

    fn Pair(comptime T: type) type {
        return struct { l: T, r: T };
    }

    // Get the 2 link indices from the link ID
    fn getLinkIndices(net: *Net, link_id: usize) Pair(c_uint) {
        const l = net.link_indices.items[link_id * 2];
        const r = net.link_indices.items[link_id * 2 + 1];
        return .{ .l = l, .r = r };
    }

    // Get the 2 link vertex positions from the link ID
    fn getLinkPositions(net: *Net, link_id: usize) Pair(*vec.Vec2) {
        const ids = net.getLinkIndices(link_id);
        const positions = net.point_positions.items;
        return .{ .l = &positions[ids.l], .r = &positions[ids.r] };
    }

    // Get the 2 link vertex velocities from the link ID
    fn getLinkPoints(net: *Net, link_id: usize) Pair(*Point) {
        const ids = net.getLinkIndices(link_id);
        const points = net.points.items;
        return .{ .l = &points[ids.l], .r = &points[ids.r] };
    }

    pub fn simulate(net: *Net, _delta: f32) void {
        // Calculate time step to simulate
        var iters: usize = CFG.min_iters; // usize because it gives us the largest fast int
        var delta: f32 = CFG.max_step;
        while (delta >= CFG.max_step) {
            iters *= 2;
            delta = CFG.timescale * _delta / @as(f32, @floatFromInt(iters));
        }
        for (0..iters) |_| {
            // Use links to update velocities
            for (net.links.items, 0..) |link, i| {
                const positions = net.getLinkPositions(i);
                const diff = positions.l.* - positions.r.*;
                const force = vec.len2(diff)[0] - link.length;
                const acc = vec.norm2(diff) * vec.splat2(force * delta * CFG.tension);
                const points = net.getLinkPoints(i);
                if (!points.l.pin) points.l.vel -= acc;
                if (!points.r.pin) points.r.vel += acc;
            }
            // Calculate friction from air resistance
            const power = -delta * CFG.air_resistance;
            const friction = vec.splat2(std.math.pow(f32, 2, power));
            // Update velocities and positions
            for (net.points.items, net.point_positions.items) |*point, *pos| {
                if (point.pin) {
                    point.vel = vec.splat2(0);
                } else {
                    point.vel[1] -= CFG.gravity * delta;
                    point.vel *= friction;
                    pos.* += point.vel * vec.splat2(delta);
                }
            }
        }
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var gfx = try GFX.init(alloc);
    defer gfx.kill();
    gfx.toggleVSync(CFG.vsync);

    var net = try Net.init(alloc);
    defer net.kill();
    try gfx.mesh.uploadIndices(net.link_indices.items);

    while (gfx.window.ok()) {
        net.simulate(gfx.window.delta);
        try gfx.mesh.upload(.{net.point_positions.items});
        if (CFG.draw) gfx.draw();
    }
}
