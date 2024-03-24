const std = @import("std");
const gl = @import("gl");
const vec = @import("vec.zig");
const GFX = @import("gfx.zig").GFX;
const Grid = @import("net.zig").Grid;
const CFG = @import("cfg.zig").CFG;
const mcts = @import("MCTS.zig");

// TODO MCTS code from the python project

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var gfx = try GFX.init(alloc);
    defer gfx.kill();
    gfx.toggleVSync(CFG.vsync);

    var grid = try Grid.init(alloc);
    defer grid.kill();
    try grid.uploadLines(&gfx);

    const mcts2 = mcts.MCTS.init(grid);
    std.debug.print("{}\n", .{mcts2.wins_this_frame});

    while (gfx.window.ok()) {
        grid.simulate(gfx.window.delta);
        try grid.uploadPoints(&gfx);
        if (CFG.draw) grid.draw(&gfx);
    }
}
