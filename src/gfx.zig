const std = @import("std");
const gl = @import("gl");
const zm = @import("zmath");
const Window = @import("window.zig").Window;
const Shader = @import("shader.zig").Shader;
const Camera = @import("camera.zig").Camera;
const Mesh = @import("mesh.zig").Mesh;

pub const GFX = struct {
    camera: Camera,
    window: Window,
    line_shader: Shader,
    circle_shader: Shader,
    mesh: Mesh(.{.{
        .{ .name = "position", .size = 2, .type = gl.FLOAT },
    }}),

    pub fn init(alloc: std.mem.Allocator) !GFX {
        const LINE_WIDTH = 0.02;
        const CIRCLE_SIZE = 0.04;
        const LINE_COLOUR = &[4]f32{ 0, 0, 1, 1 };
        const CIRCLE_COLOUR = &[4]f32{ 1, 1, 1, 1 };
        var gfx = GFX{
            .camera = Camera.init(),
            .window = undefined,
            .line_shader = undefined,
            .circle_shader = undefined,
            .mesh = undefined,
        };
        // Camera (unused) and window
        gfx.window = try Window.init(alloc, &gfx.camera);
        errdefer gfx.window.kill();
        // Shader to draw thick (triangle strip) lines from thin lines
        gfx.line_shader = try Shader.init("simple", "line", "line");
        errdefer gfx.line_shader.kill();
        gfx.line_shader.use();
        gfx.line_shader.set("line_colour", f32, LINE_COLOUR);
        gfx.line_shader.set("line_width", f32, LINE_WIDTH);
        gfx.line_shader.set("resolution", f32, &zm.vecToArr2(gfx.window.resolution));
        // Shader to draw circles from square points
        gfx.circle_shader = try Shader.init("simple", null, "circle");
        errdefer gfx.circle_shader.kill();
        gfx.circle_shader.use();
        gfx.circle_shader.set("circle_colour", f32, CIRCLE_COLOUR);
        // Configure OpenGL to support blending of large points
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.pointSize(gfx.window.resolution[1] * CIRCLE_SIZE);
        // A single mesh is used for both lines and circles
        gfx.mesh = try @TypeOf(gfx.mesh).init(gfx.circle_shader);
        errdefer gfx.mesh.kill();
        return gfx;
    }

    pub fn kill(gfx: *GFX) void {
        gfx.mesh.kill();
        gfx.circle_shader.kill();
        gfx.line_shader.kill();
        gfx.window.kill();
    }

    pub fn draw(gfx: GFX) void {
        gfx.window.clearColour(0.05, 0.04, 0.05, 1);
        gfx.line_shader.use();
        gfx.mesh.draw(gl.LINES, true, null);
        gfx.circle_shader.use();
        gfx.mesh.draw(gl.POINTS, false, null);
        gfx.window.swap();
    }
};
