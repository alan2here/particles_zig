const std = @import("std");
const math = @import("std").math;
const GameState = @import("game_state.zig").GameState;
const Net = @import("net.zig").Net;

pub const MCTSBranch = struct {
    parent: ?*MCTSBranch = null,
    visited_count: u32 = 1,
    win_count: u32 = 1,
    branches: [2]?*MCTSBranch = [2]?*MCTSBranch{ null, null },

    pub fn init() MCTSBranch {
        var branch = MCTSBranch{};
        // self.branches = [2]?*MCTSBranch{null, null};
        for (0..2) |b| {
            branch.branches[b] = null;
        }
        return branch;
    }

    pub fn success(self: *MCTSBranch) f32 {
        return f32(self.win_count) / f32(self.visited_count);
    }

    pub fn weightedRandom(task1_success: f32, task2_success: f32) i32 {
        const rand = math.random.uniform(0.0, task1_success + task2_success);
        return if (rand < task1_success) 0 else 1;
    }

    pub fn upwards_action(self: *MCTSBranch) i32 {
        return weightedRandom(self.branches[0].success(), self.branches[1].success());
    }
};

pub const MCTS = struct {
    root_branch: MCTSBranch,
    root_gameState: GameState,
    ongoing_branch: ?*MCTSBranch,
    ongoing_gameState: ?*GameState,
    wins_this_frame: usize,
    actions: usize,

    pub fn init(net: Net) MCTS {
        return .{
            .root_branch = MCTSBranch.init(),
            .root_gameState = GameState.init(net),
            .ongoing_branch = null,
            .ongoing_gameState = null,
            .wins_this_frame = 1,
            .actions = 2,
        };
    }

    fn run_reset(self: *MCTS) void {
        self.ongoing_branch = &self.root_branch;
        self.ongoing_gameState = &self.root_gameState;
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
};
