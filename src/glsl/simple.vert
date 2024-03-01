#version 460 core

uniform float aspect;

in vec2 position;

void main()
{
    gl_Position = vec4(position, 0.0, 1.0);
    gl_Position.x /= aspect;
}
