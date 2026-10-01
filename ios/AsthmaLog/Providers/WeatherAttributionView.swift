import SwiftUI
import WeatherKit

/// Required wherever Apple Weather data appears: the Apple Weather mark and a link to its data sources.
struct WeatherAttributionView: View {
    @State private var attribution: WeatherAttribution?

    var body: some View {
        HStack(spacing: 6) {
            if let a = attribution {
                AsyncImage(url: a.combinedMarkDarkURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(a.serviceName)
                }
                .frame(height: 12)
                Link("Other data sources", destination: a.legalPageURL)
            }
        }
        .font(.caption2)
        .task { attribution = try? await WeatherService.shared.attribution }
    }
}
