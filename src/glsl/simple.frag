#version 460 core

out vec4 colour;

void main()
{
    // Anti-aliased white circle with black background
    float dist = length(gl_PointCoord * 2 - 1);
    float delta = fwidth(dist);
    float alpha = smoothstep(1 - delta, 1, dist);
    colour = vec4(mix(1, 0, alpha));
}
