const std = @import("std");
const gl = @import("gl");
const vec = @import("vec.zig");
const GFX = @import("gfx.zig").GFX;
const Net = @import("net.zig").Net;
const CFG = @import("cfg.zig").CFG;

// TODO MCTS code from the python project

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var gfx = try GFX.init(alloc);
    defer gfx.kill();
    gfx.toggleVSync(CFG.vsync);

    var net = try Net.init(alloc);
    defer net.kill();
    try net.uploadLines(&gfx);

    while (gfx.window.ok()) {
        net.simulate(gfx.window.delta);
        try net.uploadPoints(&gfx);
        if (CFG.draw) net.draw(&gfx);
    }
}
