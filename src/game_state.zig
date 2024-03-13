const Net = @import("net.zig").Net;

pub const GameState = struct {
    net: Net.Net,

    pub fn init(net: Net.Net) GameState {
        return GameState{
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

    pub fn timeStep(self: GameState) void {
        _ = self;
    }

    fn timeStep_points(self: GameState) void {
        _ = self;
    }

    fn timeStep_links(self: GameState) void {
        _ = self;
    }

    pub fn copy(self: GameState) GameState {
        return GameState.init(self.net.copy());
    }

    pub fn draw(self: GameState) void {
        _ = self;
    }
};
