const std = @import("std");
const gl = @import("gl");
const vec = @import("vec.zig");
const CFG = @import("cfg.zig").CFG;
const GFX = @import("gfx.zig").GFX;

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

pub const Link = struct {
    length: f32,

    pub fn init(length: ?f32) Link {
        return .{
            .length = length orelse 0.2,
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
    link_indices: std.ArrayList(gl.GLuint),
    points: std.ArrayList(Point),
    point_positions: std.ArrayList(vec.Vec2),
    line_buffer: ?gl.GLuint,

    pub fn init(alloc: std.mem.Allocator) !Net {
        var net = Net{
            .links = undefined,
            .link_indices = undefined,
            .points = undefined,
            .point_positions = undefined,
            .line_buffer = null,
        };

        net.links = @TypeOf(net.links).init(alloc);
        errdefer net.links.deinit();
        net.link_indices = @TypeOf(net.link_indices).init(alloc);
        errdefer net.link_indices.deinit();
        net.points = @TypeOf(net.points).init(alloc);
        errdefer net.points.deinit();
        net.point_positions = @TypeOf(net.point_positions).init(alloc);
        errdefer net.point_positions.deinit();

        var line_buffer: gl.GLuint = undefined;
        gl.genBuffers(1, &line_buffer);
        net.line_buffer = line_buffer;
        errdefer gl.deleteBuffers(1, &line_buffer);

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
                    vec.splat2(@as(f32, @floatFromInt(row + col))) * vec.Vec2{ 0.1, -0.1 },
                    row + 1 == Net.HEIGHT,
                );
                // try net.addPoint(pos, null, row + 1 == Net.HEIGHT and (col == 0 or col + 1 == Net.WIDTH));
                // try net.addPoint(pos, null, (row == 0 or row + 1 == Net.HEIGHT) and (col == 0 or col + 1 == Net.WIDTH));
            }
        }

        return net;
    }

    pub fn kill(net: *Net) void {
        net.links.deinit();
        net.link_indices.deinit();
        net.points.deinit();
        net.point_positions.deinit();
        if (net.line_buffer) |line_buffer| {
            gl.deleteBuffers(1, &line_buffer);
            net.line_buffer = null;
        }
    }

    fn addLink(net: *Net, index_l: usize, index_r: usize, length: ?f32) !void {
        try net.links.append(Link.init(length));
        try net.link_indices.append(@intCast(index_l));
        try net.link_indices.append(@intCast(index_r));
    }

    fn addPoint(net: *Net, pos: vec.Vec2, vel: ?vec.Vec2, pin: ?bool) !void {
        try net.points.append(Point.init(vel orelse .{ 0, 0 }, pin));
        try net.point_positions.append(pos);
    }

    fn Pair(comptime T: type) type {
        return struct { l: T, r: T };
    }

    // Get the 2 link indices from the link ID
    fn getLinkIndices(net: *Net, link_id: usize) Pair(gl.GLuint) {
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
        // Calculate number of iterations to simulate this frame
        var iters = @ceil(_delta * CFG.min_iters_per_second);
        iters = @max(iters, CFG.min_iters_per_frame);
        // Calculate time step to simulate for each iteration
        const delta: f32 = CFG.timescale * _delta / iters;
        for (0..@intFromFloat(iters)) |_| {
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

    pub fn uploadPoints(net: *Net, gfx: *GFX) !void {
        try gfx.mesh.upload(.{net.point_positions.items});
    }

    pub fn uploadLines(net: *Net, gfx: *GFX) !void {
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, net.line_buffer.?);
        gl.bufferData(
            gl.SHADER_STORAGE_BUFFER,
            @intCast(@sizeOf(Link) * net.links.items.len),
            &net.links.items[0],
            gl.STATIC_DRAW,
        );
        gl.bindBuffer(gl.SHADER_STORAGE_BUFFER, 0);
        try gfx.mesh.uploadIndices(net.link_indices.items);
    }

    pub fn draw(net: *Net, gfx: *GFX) void {
        gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, net.line_buffer.?); // 0 is the index chosen in GFX.init
        gfx.draw();
    }

    pub fn clone(net: *Net, alloc: std.mem.Allocator) !Net {
        return .{
            .links = try net.links.clone(alloc),
            .link_indices = try net.link_indices.clone(alloc),
            .points = try net.points.clone(alloc),
            .point_positions = try net.point_positions.clone(alloc),
            .line_buffer = net.line_buffer, // No need to deep copy GPU data
        };
    }
};
