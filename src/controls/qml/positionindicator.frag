#version 440

// PositionIndicator: Wear OS's curved scroll indicator, a track and a thumb
// drawn as two capsules bent along the screen edge. Everything in pixels of
// the item; the arc is centred on `center` (the middle of the screen).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 center;
    float midRadius;      // radius of the middle of the stroke
    float halfThickness;
    float halfLength;     // half the track length along the arc
    float thumbStart;     // along the arc, -halfLength .. halfLength
    float thumbEnd;
    vec4 trackColor;      // premultiplied
    vec4 thumbColor;      // premultiplied
};

float capsule(float s, float dr, float s0, float s1)
{
    float ds = max(s0 - s, 0.0) + max(s - s1, 0.0);
    float d = length(vec2(ds, dr)) - halfThickness;
    return clamp(0.5 - d, 0.0, 1.0);
}

void main()
{
    vec2 p = qt_TexCoord0 * itemSize - center;
    float r = length(p);
    // angle 0 points right, positive downwards (y grows down)
    float s = atan(p.y, p.x) * midRadius;
    float dr = r - midRadius;
    float track = capsule(s, dr, -halfLength + halfThickness, halfLength - halfThickness);
    float thumb = capsule(s, dr, thumbStart + halfThickness, thumbEnd - halfThickness);
    vec4 c = mix(trackColor * track, thumbColor, thumb);
    fragColor = c * qt_Opacity;
}
