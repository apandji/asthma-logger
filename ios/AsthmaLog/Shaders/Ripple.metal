#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Apple Health look: a water ripple through the sky (the effect Apple shows for SwiftUI shaders, WWDC24).
/// A wave runs out from `origin`, displacing the image along it and lightening the crests, fading as it goes.
[[ stitchable ]] half4 ripple(float2 position, SwiftUI::Layer layer, float2 origin, float time,
                              float amplitude, float frequency, float decay, float speed) {
    float distance = length(position - origin);
    // The wave reaches each point a little later the further it is from the origin.
    float t = max(0.0, time - distance / speed);
    float amount = amplitude * sin(frequency * t) * exp(-decay * t);
    float2 direction = distance > 0.0 ? normalize(position - origin) : float2(0.0);
    half4 color = layer.sample(position + amount * direction);
    // Crests catch a little light.
    color.rgb += 0.3 * (amount / amplitude) * color.a;
    return color;
}
