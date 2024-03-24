const Net = @import("net.zig").Net;
const GFX = @import("gfx.zig").GFX;

pub const GameState = struct {
    net: Net,

    pub fn init(net: Net) GameState {
        return .{
            .net = net,
        };
    }

    pub fn score(self: GameState) f32 {
        var s: f32 = 0;
        for (self.net.points) |point| {
            s += point.pos.x;
        }
        return s / @as(f32, @floatFromInt(self.net.points.len));
    }

    pub fn timeStep(self: GameState, delta: f32) void {
        self.net.simulate(self.net, delta);
    }

    pub fn copy(self: GameState) GameState {
        return GameState.init(self.net.copy());
    }

    pub fn draw(self: GameState, gfx: *GFX) void {
        self.net.draw(self.net, gfx);
    }
};
