const std = @import("std");
const math = @import("std").math;
const GameState = @import("game_state.zig").GameState;
const Net = @import("net.zig").Net;

pub fn blam() void {}

pub const MCTSBranch = struct {
    parent: ?*MCTSBranch = null,
    visited_count: u32 = 1,
    win_count: u32 = 1,
    // branches: [MCTS.actions]?*MCTSBranch,

    pub fn init() MCTSBranch {
        var branch = MCTSBranch{
            .branches = undefined,
        };
        // self.branches = [2]?*MCTSBranch{null, null};
        for (0..branch.branches.len) |b| {
            branch.branches[b] = null;
        }
        return branch;
    }

    pub fn init2() void { //self: *MCTSBranch) void {
        // self.branches = branch[actions]; // left leg lengthen, right leg lengthen
        // for (0..MCTS.actions) |n| {
        // branch = MCTSBranch();
        // branch.parent = self;
        // self.branches[n] = branch;
        // }
    }

    pub fn success(self: *MCTSBranch) f32 {
        return f32(self.win_count) / f32(self.visited_count);
    }

    pub fn weightedRandom(task1_success: f32, task2_success: f32) i32 {
        const rand = math.random.uniform(0.0, task1_success + task2_success);
        return if (rand < task1_success) 0 else 1;
    }

    pub fn upwards_action(self: *MCTSBranch) i32 {
        return weightedRandom(
            self.branches[0].success(),
            self.branches[1].success(),
        );
    }
};

pub const MCTS = struct {
    root_branch: MCTSBranch,
    root_gameState: GameState,
    ongoing_branch: ?*MCTSBranch,
    ongoing_gameState: ?*GameState,
    wins_this_frame: usize,
    actions: usize,

    pub fn init() void { // net: Net, gameState2: GameState) MCTS {
        return .{
            .root_branch = MCTSBranch.init().init2(),
            // .root_gameState = GameState2,
            .ongoing_branch = null,
            .ongoing_gameState = null,
            .wins_this_frame = 1,
            .actions = 2,
        }.run_reset();
    }

    fn run_reset(self: *MCTS) void {
        self.ongoing_branch = &self.root_branch;
        self.ongoing_gameState = &self.root_gameState.copy();
    }

    fn run(self: *MCTS) void {
        _ = self;
        _ = MCTS;
    }

    fn run_visit(self: *MCTS, action: usize) void {
        _ = self;
        _ = MCTS;
        _ = action;
    }

    //     def run(self) -> None:
    //         self.wins_this_frame = 0
    //         for run in range(const.MCTS_runs):
    //             self.run_reset()
    //             root_score = self.root_gameState.score()
    //             for n in range(const.MCTS_look_ahead):
    //                 self.run_visit(self.ongoing_branch.upwards_action())
    //             if self.ongoing_gameState.score() > root_score + const.MCTS_expectation: # if we have made some/enough progress
    //                 self.wins_this_frame += 1
    //                 while not (self.ongoing_branch is self.root_branch): # working back to the root
    //                     self.ongoing_branch.win_count += 1
    //                     self.ongoing_branch = self.ongoing_branch.parent
    //             self.run_reset()
    //         root_action_index = self.root_branch.upwards_action()
    //         self.root_branch = self.root_branch.branches[root_action_index]
    //         self.root_branch.init2()
    //         self.root_gameState.timeStep(root_action_index)

    //     def run_visit(self, action : int): # private
    //         self.ongoing_branch = self.ongoing_branch.branches[action]
    //         self.ongoing_branch.init2()
    //         self.ongoing_branch.visited_count += 1
    //         self.ongoing_gameState.timeStep(action)
};

// pub const MCTSBranch = struct {
//     def __init__(self):
//         self.parent = None
//         self.visited_count = 1
//         self.win_count = 1
//         self.branches = None

//     def success(self) -> float:
//         return self.win_count / self.visited_count # 0 to 1

//     def weightedRandom(self, task1_success: float, task2_success: float) -> int:
//         rand = random.uniform(0, task1_success + task2_success)
//         return 0 if rand < task1_success else 1

//     def upwards_action(self) -> int:
//         return self.weightedRandom(self.branches[0].success(), self.branches[1].success())
// };
