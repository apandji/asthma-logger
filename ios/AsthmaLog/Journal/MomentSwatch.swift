import AsthmaCore
import SwiftUI

/// A moment, small: a dot of its own sky (temperature hue under the light of the hour, tinted by its
/// strongest air or pollen layer) with an orange (rescue) or blue (standard) ring. The same visual word
/// wherever a moment appears at small size: the calendar, the Days rows, the timeline.
struct MomentSwatch: View {
    let event: LogEvent
    var size: CGFloat = 10
    var ringWidth: CGFloat? = nil

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
            .overlay(Circle().strokeBorder(ring, lineWidth: ringWidth ?? max(1.5, size * 0.16)))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var sky: Color {
        let t = event.conditions?.best(.temperature)?.value ?? WeatherColor.fallbackTemp(event.weave)
        return WeatherColor.light(WeatherColor.temperature(t), at: event.loggedAt)
    }

    private var top: Color { sky }

    /// The strongest layer tints the lower half; dirtier air also greys it.
    private var bottom: Color {
        let layers = AirLayers(conditions: event.conditions, weave: event.weave, pollen: nil)
        guard let strongest = layers.all.max(by: { $0.level < $1.level }) else { return sky.mix(with: .black, by: 0.25) }
        return sky.mix(with: strongest.color, by: 0.25 + 0.2 * Double(strongest.level.rawValue))
    }

    private var ring: Color {
        switch event.moment {
        case .rescue: Theme.rescue
        case .maintenance: Theme.standard
        case .okay: .white.opacity(0.5)
        }
    }
}
