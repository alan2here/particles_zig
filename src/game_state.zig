const Net = @import("net.zig").Net;

pub const GameState = struct {
    pub fn init(net: Net) GameState {
        return GameState{
            .net = net,
        };
    }

    // pub fn score(self) -> float:
    //     s = 0
    //     for point in self.Net.points:
    //         s += point.pos.x
    //     return s / len(self.Net.points)

    // pub fn timeStep(self, input : int) -> None:
    //     self.timeStep_points()
    //     self.timeStep_links(input)

    // pub fn timeStep_points(self) -> None:
    //     for point in self.Net.points:
    //         point.timeStep()
    //         if point.pos.y > 0.7: # ground collision
    //             point.pos.y = 0.7
    //             point.vel.x *= 1 - const.ground_resistance
    //             point.vel.y *= 0.2

    // pub fn timeStep_links(self, input : int) -> None:
    //     if input == 0:
    //         muscle_active = self.Net.links[7]
    //         muscle_other = self.Net.links[9]
    //     else:
    //         muscle_active = self.Net.links[9]
    //         muscle_other = self.Net.links[7]
    //     # 75% to 150% default muscle length
    //     if muscle_active.length < 0.3: muscle_active.length += const.muscle_strength
    //     if muscle_other.length > 0.15: muscle_other.length -= const.muscle_strength
    //     for link in self.Net.links:
    //     # reads pos, affects acc
    //         self.Net.points[link.end1_index].accTowardsRadius(
    //             self.Net.points[link.end2_index], link.length, const.Net_link_attr)
    //         self.Net.points[link.end2_index].accTowardsRadius(
    //             self.Net.points[link.end1_index], link.length, const.Net_link_attr)

    //     # reads acc, affects acc
    //         self.Net.points[link.end1_index].matchVel(
    //             self.Net.points[link.end2_index], const.Net_link_cohesion)
    //         self.Net.points[link.end2_index].matchVel(
    //             self.Net.points[link.end1_index], const.Net_link_cohesion)
    //     for n in self.Net.points:
    //         n.matchVel_swap()

    // pub fn copy(self) -> gameState:
    //     return gameState(self.Net.copy())

    // pub fn draw(self) -> None:
    //     for point in self.Net.points:
    //         point.draw()
    //     for link in self.Net.links:
    //         pygame.draw.line(screen.disp, (128, 255, 128),
    //             (screen.size_halfWidth + self.Net.points[link.end1_index].pos.x * screen.size_halfLeast,
    //                 screen.size_halfHeight + self.Net.points[link.end1_index].pos.y * screen.size_halfLeast),
    //             (screen.size_halfWidth + self.Net.points[link.end2_index].pos.x * screen.size_halfLeast,
    //                 screen.size_halfHeight + self.Net.points[link.end2_index].pos.y * screen.size_halfLeast), 1)
};
