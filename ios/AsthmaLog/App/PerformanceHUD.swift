#if DEBUG
import QuartzCore
import SwiftUI

/// Design crit › Performance readout: frames per second and dropped frames, measured on the device
/// with a display link. A frame "drops" when it takes more than 1.5× the display's frame time.
@Observable
final class FrameMeter: NSObject {
    private(set) var fps = 0
    private(set) var dropped = 0
    private(set) var worstMs = 0.0
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var last: CFTimeInterval = 0
    @ObservationIgnored private var frames = 0
    @ObservationIgnored private var windowStart: CFTimeInterval = 0

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() { link?.invalidate(); link = nil }

    func reset() { dropped = 0; worstMs = 0 }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        if last > 0 {
            let dt = now - last
            let target = l.targetTimestamp - l.timestamp
            if target > 0, dt > target * 1.5 {
                dropped += 1
                worstMs = max(worstMs, dt * 1000)
            }
        }
        last = now
        frames += 1
        if windowStart == 0 { windowStart = now }
        if now - windowStart >= 0.5 {
            fps = Int((Double(frames) / (now - windowStart)).rounded())
            frames = 0
            windowStart = now
        }
    }
}

struct PerformanceHUD: View {
    @State private var meter = FrameMeter()

    var body: some View {
        HStack(spacing: 8) {
            Text("\(meter.fps) fps").monospacedDigit()
            Text("\(meter.dropped) dropped").monospacedDigit()
                .foregroundStyle(meter.dropped == 0 ? .green : .orange)
            if meter.worstMs > 0 { Text("worst \(Int(meter.worstMs)) ms").monospacedDigit() }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.black.opacity(0.7), in: Capsule())
        .foregroundStyle(.white)
        .onTapGesture { meter.reset() }
        .onAppear { meter.start() }
        .onDisappear { meter.stop() }
        .accessibilityHidden(true)
    }
}
#endif
