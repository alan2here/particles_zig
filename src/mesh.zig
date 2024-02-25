//! A Mesh holds information about vertices and indices sent to the GPU

const std = @import("std");
const gl = @import("gl");
const Shader = @import("shader.zig").Shader;

pub fn Mesh(comptime attrs: anytype) type {
    return struct {
        vao: ?gl.GLuint,
        vbos: ?[attrs.len]gl.GLuint,
        ebo: ?gl.GLuint,
        strides: [attrs.len]usize,
        vert_count: ?usize,
        index_count: ?usize,
        index_type: ?gl.GLenum,

        const Attr = struct {
            name: ?[]const u8,
            size: usize,
            type: gl.GLenum,
        };

        pub fn init(shader: ?Shader) !@This() {
            var vao: gl.GLuint = undefined;
            var vbos: [attrs.len]gl.GLuint = undefined;
            gl.genVertexArrays(1, &vao);
            gl.genBuffers(@intCast(attrs.len), &vbos);
            gl.bindVertexArray(vao);
            defer gl.bindVertexArray(0);

            var mesh = @This(){
                .vao = vao,
                .vbos = vbos,
                .ebo = null,
                .strides = undefined,
                .vert_count = null,
                .index_count = null,
                .index_type = null,
            };
            errdefer mesh.kill();

            inline for (0..attrs.len) |i| {
                gl.bindBuffer(gl.ARRAY_BUFFER, vbos[i]);
                try initAttrs(attrs[i], &mesh.strides[i], shader);
                gl.bindBuffer(gl.ARRAY_BUFFER, 0);
            }

            try glOk();
            return mesh;
        }

        pub fn kill(mesh: *@This()) void {
            mesh.vert_count = null;
            mesh.index_count = null;
            mesh.index_type = null;
            if (mesh.ebo) |ebo| {
                gl.deleteBuffers(1, &ebo);
                mesh.ebo = null;
            }
            if (mesh.vbos) |vbos| {
                gl.deleteBuffers(attrs.len, &vbos);
                mesh.vbos = null;
            }
            if (mesh.vao) |vao| {
                gl.deleteVertexArrays(1, &vao);
                mesh.vao = null;
            }
        }

        pub fn draw(mesh: @This(), mode: gl.GLenum) void {
            gl.bindVertexArray(mesh.vao.?);
            defer gl.bindVertexArray(0);
            if (mesh.ebo == null) {
                if (mesh.vert_count orelse 0 == 0) return;
                gl.drawArrays(
                    mode,
                    0,
                    @intCast(mesh.vert_count.?),
                );
            } else {
                if (mesh.index_count orelse 0 == 0) return;
                gl.drawElements(
                    mode,
                    @intCast(mesh.index_count.?),
                    mesh.index_type.?,
                    null,
                );
            }
        }

        // Resize the VBOs to hold a given capacity of vertices
        pub fn resizeVBOs(mesh: *@This(), vert_num: usize) !void {
            try _upload(mesh, .{}, vert_num);
        }

        // Expects an empty 1D array or a 2D array
        pub fn upload(mesh: *@This(), verts: anytype) !void {
            try _upload(mesh, verts, null);
        }

        // Expects an empty 1D array or a 2D array
        fn _upload(mesh: *@This(), verts: anytype, num_verts: ?usize) !void {
            if (verts.len != attrs.len and verts.len != 0) {
                std.log.err("Mismatch between verts.len({}) and vbos.len ({})\n", .{ verts.len, attrs.len });
                return error.BadVertArrCount;
            }
            const vbos = mesh.vbos.?;

            // Create a nested function without language support
            const bufferSize = struct {
                fn f(m: @TypeOf(mesh), arr: anytype, comptime i: usize, n: ?usize) !usize {
                    if (n) |num| {
                        return num * m.strides[i];
                    } else if (arr.len > 0 and arr[i].len > 0) {
                        return arr[i].len * @sizeOf(@TypeOf(arr[i][0]));
                    }
                    return 0;
                }
            }.f;

            // Get the current buffer size
            var signed_size: gl.GLint64 = undefined;
            gl.bindBuffer(gl.ARRAY_BUFFER, vbos[0]);
            defer gl.bindBuffer(gl.ARRAY_BUFFER, 0);
            gl.getBufferParameteri64v(gl.ARRAY_BUFFER, gl.BUFFER_SIZE, &signed_size);
            const size: usize = @intCast(signed_size);
            const size_needed: usize = try bufferSize(mesh, verts, 0, num_verts);

            // If we already have enough size then avoid reallocation
            // Reallocate if we have much more than we need
            const reuse = size >= size_needed and
                (size < size_needed * 2 or size - size_needed < 64);

            inline for (0.., vbos) |i, vbo| {
                gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
                const vert_size: gl.GLsizeiptr = @intCast(try bufferSize(mesh, verts, i, num_verts));
                const data = if (vert_size > 0 and verts.len > 0 and verts[0].len > 0) &verts[i][0] else null;
                if (reuse) {
                    gl.bufferSubData(gl.ARRAY_BUFFER, 0, vert_size, data);
                } else {
                    // TODO allocate a little extra to reduce resize frequency?
                    gl.bufferData(gl.ARRAY_BUFFER, vert_size, data, gl.STATIC_DRAW);
                }
            }

            mesh.vert_count = size_needed / mesh.strides[0];
            try glOk();
        }

        // Expects an empty 1D array or a 2D array, or null
        pub fn uploadIndices(mesh: *@This(), indices: anytype) !void {
            // Use null to delete the element buffer
            if (@TypeOf(indices) == @TypeOf(null)) {
                if (mesh.ebo) |ebo| {
                    gl.deleteBuffers(1, &ebo);
                    mesh.ebo = null;
                    gl.bindVertexArray(mesh.vao orelse return);
                    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
                    gl.bindVertexArray(0);
                    mesh.index_count = null;
                    mesh.index_type = null;
                }
                return;
            }
            if (mesh.ebo == null) {
                var ebo: gl.GLuint = undefined;
                gl.genBuffers(1, &ebo);
                mesh.ebo = ebo;
                gl.bindVertexArray(mesh.vao orelse return);
                gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
                gl.bindVertexArray(0);
            }
            const ebo = mesh.ebo.?;

            // Get the current buffer size
            var signed_size: gl.GLint64 = undefined;
            gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
            defer gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
            gl.getBufferParameteri64v(gl.ELEMENT_ARRAY_BUFFER, gl.BUFFER_SIZE, &signed_size);
            const size: usize = @intCast(signed_size);
            const size_needed: usize = if (indices.len > 0) indices.len * @sizeOf(@TypeOf(indices[0])) else 0;

            // If we already have enough size then avoid reallocation
            // Reallocate if we have much more than we need
            const reuse = size >= size_needed and
                (size < size_needed * 2 or size - size_needed < 64);

            const ids_size: gl.GLsizeiptr = if (indices.len > 0) @intCast(indices.len * @sizeOf(@TypeOf(indices[0]))) else 0;
            if (reuse) {
                gl.bufferSubData(gl.ELEMENT_ARRAY_BUFFER, 0, ids_size, if (indices.len > 0) indices else null);
            } else {
                // TODO allocate a little extra to reduce resize frequency?
                gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, ids_size, if (indices.len > 0) indices else null, gl.STATIC_DRAW);
            }

            mesh.index_count = indices.len;
            mesh.index_type = if (indices.len > 0) try glIndexTypeEnum(@TypeOf(indices[0])) else null;
            try glOk();
        }

        fn initAttrs(attrs_slice: anytype, stride: *usize, shader: ?Shader) !void {
            stride.* = 0;
            inline for (attrs_slice) |attr| stride.* += attr.size * try glSizeOf(attr.type);

            var first: usize = 0;
            var location_index: gl.GLuint = 0;

            inline for (attrs_slice) |attr| {
                // Skip nameless attributes, allowing them to act as gaps
                if (@TypeOf(attr.name) != @TypeOf(null)) {
                    comptime std.debug.assert(std.mem.trim(u8, attr.name, &std.ascii.whitespace).len > 0);
                    // If shader is null then use location indices instead
                    var index = location_index;
                    location_index += 1;

                    if (shader) |s| {
                        const id = s.id orelse return error.ShaderWithoutId;
                        const name_index = gl.getAttribLocation(
                            id,
                            attr.name,
                        );
                        if (name_index == -1) {
                            std.log.err("Failed to find {s} in shader\n", .{attr.name});
                            return error.AttrNotFound;
                        } else {
                            index = @intCast(name_index);
                        }
                    }

                    initAttr(index, attr, @intCast(stride.*), first);
                }
                first += attr.size * try glSizeOf(attr.type);
            }
        }

        fn initAttr(index: gl.GLuint, attr: Attr, stride: gl.GLsizei, first: usize) void {
            gl.enableVertexAttribArray(index);

            const force_cast_to_float = false;
            const normalise_fixed_point_values = gl.FALSE;
            const size: gl.GLint = @intCast(attr.size);
            const f: ?*const anyopaque = if (first == 0) null else @ptrFromInt(first);

            if (!force_cast_to_float) switch (attr.type) {
                gl.BYTE, gl.UNSIGNED_BYTE, gl.SHORT, gl.UNSIGNED_SHORT, gl.INT, gl.UNSIGNED_INT => {
                    gl.vertexAttribIPointer(index, size, attr.type, stride, f);
                    return;
                },
                gl.DOUBLE => {
                    gl.vertexAttribLPointer(index, size, attr.type, stride, f);
                    return;
                },
                else => {},
            };

            gl.vertexAttribPointer(
                index,
                size,
                attr.type,
                normalise_fixed_point_values,
                stride,
                f,
            );
        }
    };
}

pub fn glOk() !void {
    while (true) {
        const error_code = gl.getError();
        if (error_code == gl.NO_ERROR) break;
        const error_str = switch (error_code) {
            gl.INVALID_ENUM => "INVALID_ENUM",
            gl.INVALID_VALUE => "INVALID_VALUE",
            gl.INVALID_OPERATION => "INVALID_OPERATION",
            gl.OUT_OF_MEMORY => "OUT_OF_MEMORY",
            gl.INVALID_FRAMEBUFFER_OPERATION => "INVALID_FRAMEBUFFER_OPERATION",
            else => {
                std.log.err("OpenGL error code {} missing from glOk\n", .{error_code});
                return error.OpenglOk;
            },
        };
        std.log.err("OpenGL error {s}\n", .{error_str});
        return error.OpenGlError;
    }
}

fn glSizeOf(T: gl.GLenum) !usize {
    return switch (T) {
        gl.BYTE, gl.UNSIGNED_BYTE => @sizeOf(gl.GLbyte),
        gl.SHORT, gl.UNSIGNED_SHORT => @sizeOf(gl.GLshort),
        gl.INT_2_10_10_10_REV, gl.INT, gl.UNSIGNED_INT_2_10_10_10_REV, gl.UNSIGNED_INT => @sizeOf(gl.GLint),
        gl.FLOAT => @sizeOf(gl.GLfloat),
        gl.DOUBLE => @sizeOf(gl.GLdouble),
        gl.FIXED => @sizeOf(gl.GLfixed),
        gl.HALF_FLOAT => @sizeOf(gl.GLhalf),
        else => error.UnknownOpenGlEnum,
    };
}

fn glIndexTypeEnum(comptime T: type) !gl.GLenum {
    return switch (T) {
        gl.GLubyte => gl.UNSIGNED_BYTE,
        gl.GLushort => gl.UNSIGNED_SHORT,
        gl.GLuint => gl.UNSIGNED_INT,
        else => error.InvalidOpenGlIndexType,
    };
}
