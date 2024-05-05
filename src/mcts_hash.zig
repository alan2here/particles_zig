const GameState = @import("game_state.zig").GameState;

const JOBS = 2000;
const MAX_DEPTH = 500;
const HASH_MAP_BUCKETS = 2 << 20; // 1M

// TODO Fill this in
const Decision = enum {
    Undecided,
    Extend,
    Contract,
};

const MapNodeData = struct {
    games: u32 = 0,
    wins: u32 = 0,
};

// Globals (shared between all jobs)
const global_map: [HASH_MAP_BUCKETS]MapNodeData = undefined;

// Copied from std
pub fn hash(input: u32) u32 {
    var x: u32 = input;
    x ^= x >> 16;
    x *%= 0x7feb352d;
    x ^= x >> 15;
    x *%= 0x846ca68b;
    x ^= x >> 16;
    return x;
}

// Copied from boost
pub fn hashCombine(l: u32, r: u32) u32 {
    l ^= hash(r) + 0x9e3779b9 + (l << 6) + (l >> 2);
    return l;
}

fn hashDecisions(decisions: []Decision) u32 {
    var h: u32 = 0;
    for (decisions) |decision| {
        if (decision == .Undecided) break; // Optional
        h = hashCombine(h, @intFromEnum(decision));
    }
    return h % HASH_MAP_BUCKETS; // TODO rehash necessary to balance distro
}

fn mcts(root: GameState) void {
    @memset(global_map, .{}); // Set all to 0

    for (0..JOBS) |job_id| {
        var decisions: [MAX_DEPTH]Decision = undefined;
        var node = root.copy();
        for (0..MAX_DEPTH) |depth| {
            const decision = decide(job_id, decisions, depth);
            decisions[depth] = decision;
            step(&node, decision);
        }
    }
}

fn step(node: *GameState, decision: Decision) void {
    _ = node;
    _ = decision;
    // TODO use a switch statement to simulate the decision's effect on the game state
}

fn decide(job_id: u32, decisions: [MAX_DEPTH]Decision, depth: u32) Decision {
    _ = job_id;
    _ = decisions;
    _ = depth;
    // var h = hash(node);
    // var global_data = global_map[h];
    return .undecided; // TODO

    // rng using job_id and node and depth
    // OR
    // seed initially with job_id
    // then use same rng

    //     maybe we dont need node

    //     weight using ratio
}

// fn decide(job_id, node, depth) {
//     h = hash(node)
//     wins = all_wins[h]
//     games = all_games[h]
//     ratio = wins/games

//     rng using job_id and node and depth
//     OR
//     seed initially with job_id
//     then use same rng

//     maybe we dont need node

//     weight using ratio
// }

// fn hash(node) { // Maybe take depth, depending on duplicate node policy
//     use some hash
// }

// fn step(*node, decision) {
//     // apply decision to node (using switch statement)
// }

// root = current game state
// for (0..JOBS) |job_id| {
//     branches = array of decision enums, DEPTH items +- 1
//     node = copy_of(root)
//     var decisions = [DEPTH]Decision;
//     for 0..DEPTH |depth| {
//         decision = decide(job_id, node, depth)
//         decisions[depth] = decision
//         step(node, decision)
//     }
// }
