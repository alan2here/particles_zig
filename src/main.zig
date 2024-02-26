const std = @import("std");
const GFX = @import("gfx.zig").GFX;

const Vec2 = @Vector(2, f32);

pub const Particle = struct {
    pos: Vec2,
    vel: Vec2,

    pub fn accTowardsRadius(self: Particle, other: Particle, other_radius: f64, proportion: f64) void {
        _ = self;
        _ = other;
        _ = other_radius;
        _ = proportion;
        // dif = other.pos - self.pos
        // self.vel += dif.normalise() * (math.sqrt(dif.x ** 2 + dif.y ** 2) - other_radius) * proportion
    }
};

pub const Link = struct {
    end1_index: usize,
    end2_index: usize,
    length: f32,
};

pub const Net = struct {
    // the net contains particles and links between them
    // in this example they are arranged in a grid
    // width: u16 = 20,
    // height: u16 = 20,
    // cellSize: u16 = 20,
    // offsetX: u16 = 40,
    // offsetY: u16 = 50
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
    // coherence: f32 = 0.4, # 0 to (soft 0.5)
    // gravity: f32 = 0.2,
    // air_resistance: f32 = 0.01

    // physics – links between particles
    // reads pos, affects vel
    // in a separate function for ease of profiling
    pub fn links() void {}
};

pub const Disp: type = struct {
    // width: u16 = 1200,
    // height: u16 = 600,
    // cap: bool = False,
    // active: bool = True
};

pub fn draw_circle(pos: Vec2) void {
    _ = pos;
}

// ---

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var gfx = try GFX.init(alloc);
    defer gfx.kill();

    const line_indices = [_]c_uint{
        1, 2,
        2, 3,
        3, 4,
        4, 5,
    };
    try gfx.mesh.uploadIndices(&line_indices);
    const circle_verts = [_]f32{
        -0.5, 0.5,
        -0.3, -0.1,
        -0.2, -0.4,
        0.0,  -0.5,
        0.2,  -0.4,
        0.3,  -0.1,
        0.5,  0.5,
    };
    try gfx.mesh.upload(.{&circle_verts});

    // main loop
    while (try gfx.window.ok()) {
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
