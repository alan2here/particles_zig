#version 460 core

uniform vec4 circle_colour;

out vec4 colour;

void main()
{
    // Anti-aliased circle with transparent background
    const float dist = length(gl_PointCoord * 2 - 1);
    const float delta = fwidth(dist);
    const float alpha = smoothstep(1, 1 - delta, dist);
    colour = circle_colour * vec4(1, 1, 1, alpha);
}
