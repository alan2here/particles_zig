const std = @import("std");
const gl = @import("gl");
const vec = @import("vec.zig");
const GFX = @import("gfx.zig").GFX;
const Net = @import("net.zig").Net;
const CFG = @import("cfg.zig").CFG;
const mcts = @import("MCTS.zig");

// TODO MCTS code from the python project

pub fn main() !void {
    mcts.blam(); // ZIG not-compile defeating do-nothing function

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var gfx = try GFX.init(alloc);
    defer gfx.kill();
    gfx.toggleVSync(CFG.vsync);

    var net = try Net.init(alloc);
    defer net.kill();
    try net.addLinkedPoints(
        @constCast(&[_]f32{ 0.0, 0.1, -0.1, -0.1, 0.1, -0.1 }),
        @constCast(&[_]gl.GLuint{ 0, 1, 1, 2, 2, 0 }),
        @constCast(&[_]f32{ 0.2, 0.2, 0.2 }),
    );
    try net.uploadLines(&gfx);

    // const mcts2 = mcts.MCTS.init(net);
    // std.debug.print("{}\n", .{mcts2.wins_this_frame});

    while (gfx.window.ok()) {
        net.simulate(gfx.window.delta);
        try net.uploadPoints(&gfx);
        if (CFG.draw) net.draw(&gfx);
    }
}
