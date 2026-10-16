#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// A finger pressing into the sky: pixels near the touch are pulled toward it, strongest at the centre,
/// so the surface reads as dented. Pure feedback, no data.
[[ stitchable ]] float2 dent(float2 position, float2 touch, float radius, float strength) {
    float2 d = position - touch;
    float dist = length(d);
    if (dist > radius || dist < 0.001) { return position; }
    float t = 1.0 - dist / radius;          // 1 at the finger, 0 at the rim
    float pull = t * t * (1.0 - t) * 4.0;   // a ring of pull around the centre, like a pressed cushion
    return position - normalize(d) * pull * 18.0 * strength;
}
