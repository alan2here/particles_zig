#version 460 core

layout (lines) in;
layout (triangle_strip, max_vertices = 4) out;

uniform float line_width;
uniform vec2 resolution;

void main()
{
    const vec2 dir = (gl_in[1].gl_Position - gl_in[0].gl_Position).xy;
    vec2 norm = vec2(dir.y, -dir.x);
    // Correct for aspect ratio
    norm.y *= resolution.x / resolution.y;
    norm = normalize(norm);
    norm.x /= resolution.x / resolution.y;

    for (int vert = 0; vert < 4; ++vert)
    {
        gl_Position = gl_in[vert & 1].gl_Position;
        gl_Position.xy += norm * line_width * (1 - (vert & 2));
        EmitVertex();
    }
}
