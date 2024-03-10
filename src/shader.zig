//! A Shader uses GLSL source files at the provided paths to generate programs
//! that execute on the GPU. The function named set performs uniform assignment.

const std = @import("std");
const gl = @import("gl");

pub const Shader = struct {
    id: ?gl.GLuint,

    pub fn init(
        comptime vertex: []const u8,
        comptime geometry: ?[]const u8,
        comptime fragment: []const u8,
    ) !Shader {
        return initShader(
            &[_]?[]const u8{ vertex, geometry, fragment },
            &[_]gl.GLenum{ gl.VERTEX_SHADER, gl.GEOMETRY_SHADER, gl.FRAGMENT_SHADER },
        );
    }

    pub fn initComp(comptime compute: []const u8) !Shader {
        return initShader(
            &[_]?[]const u8{compute},
            &[_]gl.GLenum{gl.COMPUTE_SHADER},
        );
    }

    fn initShader(comptime srcs: []const ?[]const u8, comptime stages: []const gl.GLenum) !Shader {
        comptime std.debug.assert(srcs.len == stages.len);
        var ids: [srcs.len]?gl.GLuint = undefined;
        var zero = false;
        inline for (srcs, stages, &ids) |src, stage, *id| {
            id.* = compile(src, stage);
            zero = zero or id.* == 0;
        }

        var shader = Shader{
            .id = null,
        };

        if (!zero) {
            shader.id = gl.createProgram();
            if (shader.id) |program_id| {
                for (ids) |id| if (id) |i| gl.attachShader(program_id, i);
                gl.linkProgram(program_id);
            }
        }

        for (ids) |id| if (id) |i| gl.deleteShader(i);

        if (shader.id) |id| {
            var path: ?[]const u8 = null;
            inline for (srcs, stages) |src, stage| {
                if (src == null) continue;
                const tmp = makePath(src, stage);
                if (tmp != null) path = tmp;
            }
            if (compileError(id, true, path)) {
                shader.kill();
            }
        }

        return if (shader.id == null) error.ShaderInitFailure else shader;
    }

    pub fn kill(shader: *Shader) void {
        if (shader.id) |id| {
            gl.deleteProgram(id);
            shader.id = null;
        }
    }

    pub fn use(shader: Shader) void {
        if (shader.id) |id| gl.useProgram(id);
    }

    pub fn set(shader: Shader, name: [:0]const u8, comptime T: type, value: anytype) void {
        const id = shader.id.?;
        const location = gl.getUniformLocation(id, name);
        if (location == -1) {
            std.log.err("Failed to find uniform {s}", .{name});
            return;
        }
        switch (@typeInfo(@TypeOf(value))) {
            .Array, .Pointer => {
                const vec = @as([]const T, switch (@typeInfo(@TypeOf(value))) {
                    .Array => &value,
                    else => value,
                });
                const ptr: [*c]const T = &vec[0];
                switch (vec.len) {
                    1 => (switch (T) {
                        gl.GLfloat => gl.uniform1fv,
                        gl.GLdouble => gl.uniform1dv,
                        gl.GLint => gl.uniform1iv,
                        gl.GLuint => gl.uniform1uiv,
                        else => {
                            std.log.err("Invalid uniform type {}", .{T});
                            unreachable;
                        },
                    })(location, 1, ptr),
                    2 => (switch (T) {
                        gl.GLfloat => gl.uniform2fv,
                        gl.GLdouble => gl.uniform2dv,
                        gl.GLint => gl.uniform2iv,
                        gl.GLuint => gl.uniform2uiv,
                        else => {
                            std.log.err("Invalid uniform type {}", .{T});
                            unreachable;
                        },
                    })(location, 1, ptr),
                    3 => (switch (T) {
                        gl.GLfloat => gl.uniform3fv,
                        gl.GLdouble => gl.uniform3dv,
                        gl.GLint => gl.uniform3iv,
                        gl.GLuint => gl.uniform3uiv,
                        else => {
                            std.log.err("Invalid uniform type {}", .{T});
                            unreachable;
                        },
                    })(location, 1, ptr),
                    4 => (switch (T) {
                        gl.GLfloat => gl.uniform4fv,
                        gl.GLdouble => gl.uniform4dv,
                        gl.GLint => gl.uniform4iv,
                        gl.GLuint => gl.uniform4uiv,
                        else => {
                            std.log.err("Invalid uniform type {}", .{T});
                            unreachable;
                        },
                    })(location, 1, ptr),
                    9 => (switch (T) {
                        gl.GLfloat => gl.uniformMatrix3fv,
                        gl.GLdouble => gl.uniformMatrix3dv,
                        else => {
                            std.log.err("Invalid uniform type {}", .{T});
                            unreachable;
                        },
                    })(location, 1, gl.FALSE, ptr),
                    16 => (switch (T) {
                        gl.GLfloat => gl.uniformMatrix4fv,
                        gl.GLdouble => gl.uniformMatrix4dv,
                        else => {
                            std.log.err("Invalid uniform type {} for length {}", .{ T, vec.len });
                            unreachable;
                        },
                    })(location, 1, gl.FALSE, ptr),
                    else => {
                        std.log.err("Invalid uniform length {}", .{vec.len});
                        unreachable;
                    },
                }
            },
            else => {
                (switch (T) {
                    gl.GLfloat => gl.uniform1f,
                    gl.GLdouble => gl.uniform1d,
                    gl.GLint => gl.uniform1i,
                    gl.GLuint => gl.uniform1ui,
                    else => {
                        std.log.err("Invalid uniform type {}", .{T});
                        unreachable;
                    },
                })(location, @as(T, value));
            },
        }
    }

    pub fn bindBlock(shader: Shader, name: [:0]const u8, binding: gl.GLuint) void {
        if (shader.id) |id| {
            const index = gl.getProgramResourceIndex(id, gl.SHADER_STORAGE_BLOCK, name);
            gl.shaderStorageBlockBinding(id, index, binding);
        }
    }
};

fn compile(comptime name: ?[]const u8, comptime stage: gl.GLenum) ?gl.GLuint {
    if (name == null) return null;
    comptime std.debug.assert(std.mem.trim(
        u8,
        name.?,
        &std.ascii.whitespace,
    ).len > 0);
    const path = comptime makePath(name, stage) orelse {
        std.log.err("Invalid shader stage {}", .{stage});
        return 0;
    };
    const buffer: [*c]const [*c]const u8 = &&@embedFile(path)[0];
    const id = gl.createShader(stage);
    gl.shaderSource(id, 1, buffer, null);
    gl.compileShader(id);
    if (compileError(id, false, path)) return 0;
    return id;
}

fn compileError(id: gl.GLuint, comptime is_program: bool, path: ?[]const u8) bool {
    const max_length = 1024;
    var ok: gl.GLint = gl.FALSE;
    var log: [max_length]gl.GLchar = undefined;

    if (is_program) {
        gl.getProgramiv(id, gl.LINK_STATUS, &ok);
    } else {
        gl.getShaderiv(id, gl.COMPILE_STATUS, &ok);
    }

    if (ok == gl.FALSE) {
        var len: gl.GLsizei = undefined;
        (if (is_program) gl.getProgramInfoLog else gl.getShaderInfoLog)(id, max_length, &len, &log);
        std.log.err("Failed to {s} {s}\n{s}", .{
            if (is_program) "link shader program with shader file" else "compile shader file",
            path orelse "NO_PATH_GIVEN",
            log[0..@intCast(len)],
        });
    }
    return ok == gl.FALSE;
}

fn makePath(comptime name: ?[]const u8, comptime stage: gl.GLenum) ?[]const u8 {
    return "glsl/" ++ name.? ++ switch (stage) {
        gl.VERTEX_SHADER => ".vert",
        gl.GEOMETRY_SHADER => ".geom",
        gl.FRAGMENT_SHADER => ".frag",
        gl.COMPUTE_SHADER => ".comp",
        else => return null,
    };
}
