import Foundation

/// API keys injected from Config/Secrets.xcconfig through Info.plist. Missing → that source is skipped.
/// Keys ship inside the TestFlight build — accepted for the proof of concept; move behind a proxy before release.
enum Secrets {
    static var openAQ: String? { value("OPENAQ_API_KEY") }
    static var airNow: String? { value("AIRNOW_API_KEY") }

    private static func value(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let v = raw.trimmingCharacters(in: .whitespaces)
        return v.isEmpty || v.hasPrefix("$(") ? nil : v
    }
}

enum HTTP {
    static func get<T: Decodable>(_ url: URL, headers: [String: String] = [:], as: T.Type = T.self) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 15)
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let body = String(data: data.prefix(160), encoding: .utf8) ?? ""
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "\(url.host() ?? "") \(http.statusCode): \(body)"])
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
