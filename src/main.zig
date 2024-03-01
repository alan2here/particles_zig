const std = @import("std");
const vec = @import("vec.zig");
const GFX = @import("gfx.zig").GFX;

const CFG = .{
    .air_resistance = 1,
    .draw = true,
    .gravity = 0.1,
    .tension = 10,
    .timescale = 10,
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
    // the net contains points and links between them
    // in this example they are arranged in a grid
    width: u16 = 20,
    height: u16 = 20,
    cellSize: u16 = 20,
    offsetX: u16 = 40,
    offsetY: u16 = 50,

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

        // setup – the net
        // particles = []
        // links = []
        // for y in range(net.height):
        //     for x in range(net.width):
        //         particles.append(particle(vec2(x * net.cellSize + net.offsetX, y * net.cellSize + net.offsetY)))
        //     for x in range(net.width - 1):
        //         links.append(link(y * net.height + x, y * net.height + x + 1, net.cellSize))
        //         links.append(link(x * net.width + y, (x + 1) * net.width + y, net.cellSize))

        try net.link_indices.appendSlice(&[_]c_uint{
            1, 2,
            2, 3,
            3, 4,
            4, 5,
        });

        try net.point_positions.appendSlice(&[_]vec.Vec2{
            .{ -0.8, 0.5 },
            .{ -0.7, -0.2 },
            .{ -0.4, -0.5 },
            .{ 0.0, -0.6 },
            .{ 0.4, -0.5 },
            .{ 0.7, -0.2 },
            .{ 0.8, 0.5 },
        });

        try net.links.appendNTimes(
            Link.init(null),
            net.link_indices.items.len / 2,
        );
        try net.points.appendNTimes(
            Point.init(null, null),
            net.point_positions.items.len,
        );
        net.points.items[0].pin = true;
        net.points.items[1].pin = true;
        net.points.items[5].pin = true;
        net.points.items[6].pin = true;

        return net;
    }

    pub fn kill(net: *Net) void {
        net.links.deinit();
        net.link_indices.deinit();
        net.points.deinit();
        net.point_positions.deinit();
    }

    fn Pair(comptime T: type) type {
        return struct { l: T, r: T };
    }

    // Get the 2 link indices from the link ID
    fn getLinkIndices(net: *Net, link_id: usize) Pair(usize) {
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
        const delta = CFG.timescale * _delta;
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

    // main loop
    while (gfx.window.ok()) {
        net.simulate(gfx.window.delta);
        try gfx.mesh.upload(.{net.point_positions.items});
        if (CFG.draw) gfx.draw();
    }
}
