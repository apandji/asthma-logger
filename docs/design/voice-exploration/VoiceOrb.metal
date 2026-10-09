// Voice effect prototype (docs/design/voice-exploration.md).
// A soft ink orb whose edge wobbles and glows with the voice level, for SwiftUI's `.colorEffect`.
// Reference only: not in the build. Compiling .metal files needs the Metal Toolchain
// (Xcode → Settings → Components, or `xcodebuild -downloadComponent MetalToolchain`). The prototype
// in ios/AsthmaLog/Voice/ draws the same idea with plain SwiftUI. Use from Swift:
//   Rectangle().colorEffect(ShaderLibrary.voiceOrb(.float2(size), .float(t), .float(level),
//                                                  .color(Theme.weaveAir), .color(Theme.weaveHumidity), .color(Theme.weaveTemperature)))
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

namespace voiceorb {
    float hash(float2 p) { return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }

    // Smooth value noise in 0...1.
    float noise(float2 p) {
        float2 i = floor(p), f = fract(p);
        float2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + float2(1, 0)), u.x),
                   mix(hash(i + float2(0, 1)), hash(i + float2(1, 1)), u.x), u.y);
    }
}

/// - size: the view's size in points.
/// - time: seconds, for the slow drift.
/// - level: voice level 0...1 (simulated in the prototype; an AVAudioEngine tap in the real feature).
/// - inkA/B/C: three weave inks (today's conditions), opaque.
[[ stitchable ]] half4 voiceOrb(float2 position, half4 color, float2 size, float time, float level,
                                half4 inkA, half4 inkB, half4 inkC) {
    float2 uv = (position - size * 0.5) / min(size.x, size.y);   // centred, -0.5...0.5 on the short side
    float r = length(uv);
    float a = atan2(uv.y, uv.x);

    // Edge: noise sampled around the circle, so the outline stays closed. Louder = bigger and wobblier.
    float wob = voiceorb::noise(float2(cos(a), sin(a)) * 1.8 + float2(time * 0.6, -time * 0.45)) - 0.5;
    float radius = 0.24 + 0.06 * level + wob * (0.025 + 0.11 * level);
    float inside = smoothstep(radius + 0.006, radius - 0.012, r);

    // Halo outside the edge, stronger and wider when speaking.
    float glow = exp(-max(r - radius, 0.0) * (16.0 - 8.0 * level)) * (0.18 + 0.55 * level);

    // Interior: inks drift into each other, faster when speaking.
    float speed = 0.25 + 0.6 * level;
    float n1 = voiceorb::noise(uv * 3.2 + float2(time * speed, -time * speed * 0.7));
    float n2 = voiceorb::noise(uv * 4.1 - float2(time * speed * 0.8, time * speed) + 7.0);
    half3 c = mix(inkA.rgb, inkB.rgb, half(smoothstep(0.2, 0.8, n1)));
    c = mix(c, inkC.rgb, half(smoothstep(0.5, 0.9, n2)));

    // A soft highlight near the top-left, like light on glass.
    float hl = smoothstep(0.22, 0.0, length(uv - float2(-0.07, -0.09))) * 0.18 * inside;
    c = mix(c, half3(1.0), half(hl));

    float alpha = clamp(inside * 0.9 + glow * (1.0 - inside), 0.0, 1.0);
    return half4(c * half(alpha), half(alpha));   // premultiplied
}
