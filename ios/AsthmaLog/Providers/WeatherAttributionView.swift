import SwiftUI
import WeatherKit

/// Required wherever Apple Weather data appears: the Apple Weather mark and a link to its data sources.
struct WeatherAttributionView: View {
    @State private var attribution: WeatherAttribution?
    @State private var showSources = false

    var body: some View {
        HStack(spacing: 6) {
            if let a = attribution {
                AsyncImage(url: a.combinedMarkDarkURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(a.serviceName)
                }
                .frame(height: 12)
                // Apple's legal page, as required; and every source felt air uses, in one place.
                Link("Legal", destination: a.legalPageURL)
                Button("All sources") { showSources = true }
            }
        }
        .font(.caption2)
        .task { attribution = try? await WeatherService.shared.attribution }
        .sheet(isPresented: $showSources) { NavigationStack { SourcesView() }.presentationDragIndicator(.visible) }
    }
}
