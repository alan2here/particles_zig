#version 460 core

uniform vec4 line_colour;

out vec4 colour;

void main()
{
    colour = vec4(line_colour);
}
