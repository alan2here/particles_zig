//! The Window manages the viewport and accumulates user input

const std = @import("std");
const glfw = @import("glfw");
const gl = @import("gl");
const zm = @import("zmath");
const Camera = @import("camera.zig").Camera;

pub const Window = struct {
    var windows: usize = 0;

    window: glfw.Window,
    clear_mask: gl.GLbitfield,
    resolution: zm.Vec,
    new_viewport: ?glfw.Window.Size,
    time: ?f32,
    delta: f32,
    mouse_pos: ?zm.Vec,
    mouse_delta: zm.Vec,
    scroll_delta: zm.Vec,
    binds: std.AutoHashMap(glfw.Key, Action),
    actionState: [@typeInfo(Action).Enum.fields.len]bool,
    input: zm.Vec,
    camera: *Camera,

    const Action = enum {
        left,
        right,
        ascend,
        descend,
        forward,
        backward,
        attack1,
        attack2,
    };

    pub fn init(alloc: std.mem.Allocator, camera: *Camera) !Window {
        // Ensure GLFW errors are logged
        glfw.setErrorCallback(errorCallback);

        const windowed = true;
        const resizable = false;
        const show_cursor = true;
        const raw_input = false;
        const cull_faces = false;
        const test_depth = false;
        const wireframe = false; // This won't change anything
        const vertical_sync = true;
        const msaa_samples = 16;
        const clear_buffers = true;

        // If we currently have no windows then initialise GLFW
        if (windows == 0 and !glfw.init(.{})) {
            std.log.err("Failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
            return error.GlfwInitFailure;
        }
        errdefer if (windows == 0) glfw.terminate();

        // Obtain primary monitor
        const monitor = glfw.Monitor.getPrimary() orelse {
            std.log.err("Failed to get primary monitor: {?s}", .{glfw.getErrorString()});
            return error.MonitorUnobtainable;
        };

        const resolution = try calcResolution(windowed, camera);

        // Create our window
        const window = glfw.Window.create(
            @intFromFloat(resolution[0]),
            @intFromFloat(resolution[1]),
            "particles_zig",
            if (windowed) null else monitor,
            null,
            .{
                .opengl_profile = .opengl_core_profile,
                .context_version_major = 4,
                .context_version_minor = 6,
                .resizable = resizable,
                .samples = msaa_samples,
                .position_x = @intFromFloat(resolution[2]),
                .position_y = @intFromFloat(resolution[3]),
            },
        ) orelse {
            std.log.err("Failed to create GLFW window: {?s}", .{glfw.getErrorString()});
            return error.WindowCreationFailure;
        };
        errdefer window.destroy();

        // Listen to window input
        window.setKeyCallback(keyCallback);
        window.setMouseButtonCallback(mouseButtonCallback);
        window.setCursorPosCallback(cursorPosCallback);
        window.setScrollCallback(scrollCallback);
        glfw.makeContextCurrent(window);

        // Configure input
        if (!show_cursor) {
            window.setInputModeCursor(glfw.Window.InputModeCursor.disabled);
        }
        if (raw_input and glfw.rawMouseMotionSupported()) {
            // Disable mouse motion acceleration and scaling
            window.setInputModeRawMouseMotion(true);
        }

        const proc: glfw.GLProc = undefined;
        gl.load(proc, glGetProcAddress) catch |err| {
            std.log.err("Failed to load OpenGL: {}", .{err});
            return err;
        };

        // Configure triangle visibility
        if (cull_faces) gl.enable(gl.CULL_FACE);
        if (test_depth) gl.enable(gl.DEPTH_TEST);
        if (wireframe) gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);

        // Configure additional window properties
        if (!vertical_sync) glfw.swapInterval(0);
        if (msaa_samples > 1) gl.enable(gl.MULTISAMPLE);

        // Determine which buffers get cleared
        var clear_mask: gl.GLbitfield = 0;
        if (clear_buffers) {
            clear_mask |= gl.COLOR_BUFFER_BIT;
            if (test_depth) {
                clear_mask |= gl.DEPTH_BUFFER_BIT;
            }
        }

        // Update window count
        windows += 1;

        var binds = std.AutoHashMap(glfw.Key, Action).init(alloc);
        errdefer binds.deinit();
        try binds.put(.w, .forward);
        try binds.put(.s, .backward);
        try binds.put(.a, .left);
        try binds.put(.d, .right);
        try binds.put(.space, .ascend);
        try binds.put(.caps_lock, .descend);
        try binds.put(.left_shift, .descend);
        try binds.put(.left_control, .descend);

        return .{
            .window = window,
            .clear_mask = clear_mask,
            .resolution = resolution,
            .new_viewport = null,
            .time = null,
            .delta = 0,
            .mouse_pos = null,
            .mouse_delta = @splat(0),
            .scroll_delta = @splat(0),
            .binds = binds,
            .actionState = undefined,
            .input = @splat(0),
            .camera = camera,
        };
    }

    pub fn kill(win: *Window) void {
        win.binds.deinit();
        win.window.destroy();
        windows -= 1;
        // When we have no windows we have no use for GLFW
        if (windows == 0) glfw.terminate();
    }

    pub fn ok(win: *Window) bool {
        // Clear mouse delta
        win.mouse_delta = @splat(0);
        win.scroll_delta = @splat(0);

        // Update deltaTime
        const new_time: f32 = @floatCast(glfw.getTime());
        if (win.time) |time| {
            // Limit delta to 100 ms to avoid massive jumps
            win.delta = @min(new_time - time, 0.1);
            if (@floor(time) != @floor(new_time)) {
                const fps: usize = @intFromFloat(@min(1 / win.delta, 999999));
                var b: [10:0]u8 = undefined;
                const slice = std.fmt.bufPrint(&b, "{} FPS", .{fps}) catch unreachable;
                std.debug.print("{s}\n", .{slice});
                b[slice.len] = 0;
                win.window.setTitle(&b);
            }
        } else {
            // Set the user pointer if we are about to poll the first events
            win.window.setUserPointer(win);
            win.actionState = std.mem.zeroes(@TypeOf(win.actionState));
        }
        win.time = new_time;

        // Create a closure without language support
        const action = struct {
            state: @TypeOf(win.actionState),
            fn active(self: @This(), a: Action) bool {
                return self.state[@intFromEnum(a)];
            }
        }{ .state = win.actionState };

        glfw.pollEvents();
        win.input = @splat(0);
        if (action.active(.left)) win.input[0] -= 1;
        if (action.active(.right)) win.input[0] += 1;
        if (action.active(.descend)) win.input[1] -= 1;
        if (action.active(.ascend)) win.input[1] += 1;
        if (action.active(.backward)) win.input[2] -= 1;
        if (action.active(.forward)) win.input[2] += 1;
        if (win.new_viewport) |size| {
            gl.viewport(0, 0, @intCast(size.width), @intCast(size.height));
            win.mouse_pos = null;
        }
        return !win.window.shouldClose();
    }

    pub fn clear(win: Window) void {
        gl.clear(win.clear_mask);
    }

    pub fn clearColour(win: Window, r: f32, g: f32, b: f32, a: f32) void {
        gl.clearColor(r, g, b, a);
        win.clear();
    }

    pub fn swap(win: Window) void {
        win.window.swapBuffers();
    }

    fn toggleWindowed(win: *Window) !void {
        const windowed = win.window.getMonitor() == null;
        const resolution = try calcResolution(!windowed, win.camera);

        const monitor = if (windowed) (glfw.Monitor.getPrimary() orelse {
            std.log.err("Failed to get primary monitor: {?s}", .{glfw.getErrorString()});
            return error.MonitorUnobtainable;
        }) else null;

        win.resolution = resolution;
        win.window.setMonitor(
            monitor,
            @intFromFloat(resolution[2]),
            @intFromFloat(resolution[3]),
            @intFromFloat(resolution[0]),
            @intFromFloat(resolution[1]),
            null,
        );

        const size = win.window.getFramebufferSize();
        if (size.width == 0 or size.height == 0) {
            std.log.err("Failed to get primary monitor: {?s}", .{glfw.getErrorString()});
            return error.FramebufferUnobtainable;
        }
        win.new_viewport = size;
    }

    fn calcResolution(windowed: bool, camera: *Camera) !zm.Vec {
        // Obtain primary monitor
        const monitor = glfw.Monitor.getPrimary() orelse {
            std.log.err("Failed to get primary monitor: {?s}", .{glfw.getErrorString()});
            return error.MonitorUnobtainable;
        };

        // Obtain video mode of monitor
        const mode = glfw.Monitor.getVideoMode(monitor) orelse {
            std.log.err("Failed to get video mode of primary monitor: {?s}", .{glfw.getErrorString()});
            return error.VideoModeUnobtainable;
        };

        // Use scale to make window smaller than primary monitor
        const scale: f32 = if (windowed) 900.0 / 1080.0 else 1;
        const scale_gap = (1 - scale) / 2;
        const size = zm.f32x4(
            @floatFromInt(mode.getWidth()),
            @floatFromInt(mode.getHeight()),
            @floatFromInt(mode.getWidth()),
            @floatFromInt(mode.getHeight()),
        ) * zm.f32x4(scale, scale, scale_gap, scale_gap);
        camera.calcAspect(size);
        return size;
    }

    fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
        _ = p;
        return glfw.getProcAddress(proc);
    }

    fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
        std.log.err("GLFW: {}: {s}", .{ error_code, description });
    }

    fn keyCallback(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
        _ = scancode;
        if (key == .escape) window.setShouldClose(true);
        const win = window.getUserPointer(Window).?;
        if ((key == .enter or key == .kp_enter) and action == .press and mods.alt) {
            win.toggleWindowed() catch unreachable;
        }
        const target = win.binds.get(key) orelse return;
        win.actionState[@intFromEnum(target)] = action != .release;
    }

    fn mouseButtonCallback(window: glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) void {
        _ = mods;
        _ = action;
        _ = button;
        _ = window;
    }

    fn cursorPosCallback(window: glfw.Window, xpos: f64, ypos: f64) void {
        const win = window.getUserPointer(Window).?;
        const new_pos = zm.loadArr2([2]f32{
            @floatCast(xpos),
            @floatCast(win.resolution[1] - ypos - 1),
        });
        if (win.mouse_pos) |pos| win.mouse_delta += new_pos - pos;
        win.mouse_pos = new_pos;
    }

    fn scrollCallback(window: glfw.Window, xoffset: f64, yoffset: f64) void {
        const win = window.getUserPointer(Window).?;
        win.scroll_delta += zm.loadArr2([2]f32{ @floatCast(xoffset), @floatCast(yoffset) });
    }
};
