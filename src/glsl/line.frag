#version 460 core

uniform vec4 line_colour;

in float stretch;

out vec4 colour;

vec4 hueShift(vec4 colour, float hue_adjust) {
    const vec4 kRGBToYPrime = vec4(0.299,  0.587,  0.114, 0.0);
    const vec4 kRGBToI      = vec4(0.596, -0.275, -0.321, 0.0);
    const vec4 kRGBToQ      = vec4(0.212, -0.523,  0.311, 0.0);

    const vec4 kYIQToR = vec4(1.0,  0.956,  0.621, 0.0);
    const vec4 kYIQToG = vec4(1.0, -0.272, -0.647, 0.0);
    const vec4 kYIQToB = vec4(1.0, -1.107,  1.704, 0.0);

    float YPrime = dot(colour, kRGBToYPrime);
    float I      = dot(colour, kRGBToI);
    float Q      = dot(colour, kRGBToQ);
    float hue    = atan(Q, I);
    float chroma = sqrt(I * I + Q * Q);

    hue += hue_adjust;

    Q = chroma * sin(hue);
    I = chroma * cos(hue);

    vec4 yIQ = vec4(YPrime, I, Q, 0.0);
    colour.r = dot(yIQ, kYIQToR);
    colour.g = dot(yIQ, kYIQToG);
    colour.b = dot(yIQ, kYIQToB);
    return colour;
}

void main()
{
    colour = hueShift(line_colour, clamp(stretch, -1, 1) * 1.7);
}
