const std = @import("std");
const vec = @import("vec.zig");
const GFX = @import("gfx.zig").GFX;

pub const Link = struct {
    length: f32,

    pub fn init(length: ?f32) Link {
        return .{
            .length = length orelse 0.1,
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

        try net.link_indices.appendSlice(&[_]c_uint{
            1, 2,
            2, 3,
            3, 4,
            4, 5,
        });

        try net.point_positions.appendSlice(&[_]vec.Vec2{
            .{ -0.5, 0.5 },
            .{ -0.3, -0.1 },
            .{ -0.2, -0.4 },
            .{ 0.0, -0.5 },
            .{ 0.2, -0.4 },
            .{ 0.3, -0.1 },
            .{ 0.5, 0.5 },
        });

        try net.links.appendNTimes(Link.init(null), net.link_indices.items.len / 2);
        try net.points.appendNTimes(Point.init(null, null), net.point_positions.items.len);
        net.points.items[1].pin = true;
        net.points.items[5].pin = true;

        return net;
    }

    pub fn kill(net: *Net) void {
        net.links.deinit();
        net.link_indices.deinit();
        net.points.deinit();
        net.point_positions.deinit();
    }

    // Get the 2 link indices from the link ID
    fn getLinkIndices(net: *Net, link_id: usize) struct { l: usize, r: usize } {
        const l = net.link_indices.items[link_id * 2];
        const r = net.link_indices.items[link_id * 2 + 1];
        return .{ .l = l, .r = r };
    }

    // Get the 2 link vertex positions from the link ID
    fn getLinkPos(net: *Net, link_id: usize) struct { l: *vec.Vec2, r: *vec.Vec2 } {
        const indices = net.getLinkIndices(link_id);
        const positions = net.point_positions.items;
        return .{ .l = &positions[indices.l], .r = &positions[indices.r] };
    }

    // Get the 2 link vertex velocities from the link ID
    fn getLinkVel(net: *Net, link_id: usize) struct { l: *vec.Vec2, r: *vec.Vec2 } {
        const indices = net.getLinkIndices(link_id);
        const velocities = net.points.items;
        return .{
            .l = &velocities[indices.l].vel,
            .r = &velocities[indices.r].vel,
        };
    }

    pub fn simulate(net: *Net, delta: f32) void {
        const proportion = 0.5; // TODO decide
        for (net.links.items, 0..) |link, i| {
            const positions = net.getLinkPos(i);
            const diff = positions.l.* - positions.r.*;
            const force = vec.len2(diff)[0] - link.length;
            const acc = vec.norm2(diff) * vec.splat2(force * proportion * delta);

            const velocities = net.getLinkVel(i);
            velocities.l.* -= acc;
            velocities.r.* += acc;
        }
        for (net.points.items, net.point_positions.items) |*point, *pos| {
            if (!point.pin) pos.* += vec.splat2(delta) * point.vel;
        }
    }
};

// setup – the net
// pub var particles = []
// pub var links = []
// for y in range(net.height):
// for x in range(net.width):
// particles.append(particle(vec2(x * net.cellSize + net.offsetX, y * net.cellSize + net.offsetY)))
// for x in range(net.width - 1):
// links.append(link(y * net.height + x, y * net.height + x + 1, net.cellSize))
// links.append(link(x * net.width + y, (x + 1) * net.width + y, net.cellSize))

// ---

// setup – physics constants, display, and timing

pub const Phys: type = struct {
    coherence: f32 = 0.4, // 0 to (soft 0.5)
    gravity: f32 = 0.2,
    air_resistance: f32 = 0.01,

    // physics – links between particles
    // reads pos, affects vel
    // in a separate function for ease of profiling
    pub fn links() void {}
};

pub const Disp: type = struct {
    width: u16 = 1200,
    height: u16 = 600,
    cap: bool = false,
    active: bool = true,
};

// ---

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var gfx = try GFX.init(alloc);
    defer gfx.kill();

    var net = try Net.init(alloc);
    defer net.kill();
    try gfx.mesh.uploadIndices(net.link_indices.items);

    // main loop
    while (try gfx.window.ok()) {
        net.simulate(gfx.window.delta);
        try gfx.mesh.upload(.{net.point_positions.items});

        // physics – links between particles
        // reads pos, affects vel
        // for link in links:
        //     particles[link.end1_index].accTowardsRadius(
        //         particles[link.end2_index], link.length, phys.coherence)
        //     particles[link.end2_index].accTowardsRadius(
        //         particles[link.end1_index], link.length, phys.coherence)

        // physics – gravity, momentum, and air resistance

        // physics – pin the top of the net

        gfx.draw();
    }
}
