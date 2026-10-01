import Foundation

/// Raw value → band. Edges match `web/src/lib/insights/frames-from-logs.ts` (checked by `fixtures/bands-v1.json`).
/// Numbers never go through a model to become a band.
public enum Banding {
    /// PM2.5 at or above this (µg/m³), or AQI at or above `smokeAQI`, counts as smoke-like air.
    public static let smokePM25: Double = 12
    public static let smokeAQI: Int = 51

    public static func pm25(_ ug: Double?) -> PollutantBand {
        guard let v = ug, v.isFinite else { return .unknown }
        if v < 12 { return .low }
        if v < 35 { return .moderate }
        return .high
    }

    public static func ozone(ppb: Double?) -> PollutantBand {
        guard let v = ppb, v.isFinite else { return .unknown }
        if v < 55 { return .low }
        if v < 70 { return .moderate }
        return .high
    }

    public static func temp(_ f: Double?, isExtreme: Bool) -> TempBand {
        guard let v = f, v.isFinite else { return .unknown }
        if isExtreme || v >= 90 { return .hot }
        if v <= 32 { return .cold }
        return .mild
    }

    /// Extreme outdoor temperature (°F), same as the web prototype's NWS rule.
    public static func isExtremeTemp(_ f: Double?) -> Bool {
        guard let v = f, v.isFinite else { return false }
        return v <= 20 || v >= 95
    }

    public static func humidity(_ pct: Double?) -> HumidityBand {
        guard let v = pct, v.isFinite else { return .unknown }
        if v < 35 { return .dry }
        if v > 65 { return .humid }
        return .ok
    }

    public static func pollen(risk: String?) -> PollenLevel {
        guard let risk, !risk.isEmpty else { return .unknown }
        let r = risk.lowercased()
        if r.contains("very") || r.contains("vh") || r.contains("high") { return .high }
        if r.contains("moderate") || r.contains("mod") { return .moderate }
        if r.contains("low") { return .low }
        if r.contains("none") || r == "0" { return .none }
        return .unknown
    }

    /// `month` is 1–12.
    public static func season(month: Int) -> Season {
        switch month {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        default: return .fall
        }
    }

    public static func smokeAtPoint(pm25: Double?, aqi: Int?) -> Bool {
        if let v = pm25, v.isFinite, v >= smokePM25 { return true }
        if let a = aqi, a >= smokeAQI { return true }
        return false
    }

    public static func heatAlert(isExtremeTemp: Bool, alertNames: [String]) -> Bool {
        if isExtremeTemp { return true }
        return alertNames.contains { name in
            let n = name.lowercased()
            return n.contains("heat") || n.contains("excessive")
        }
    }

    /// For AQ forecasts that only give an AQI category (AirNow). Ozone maps exactly onto our edges;
    /// PM2.5 is approximate because EPA's PM breakpoints differ from our 12/35 edges.
    public static func pollutant(aqiCategoryNumber: Int?) -> PollutantBand {
        guard let n = aqiCategoryNumber, n >= 1 else { return .unknown }
        switch n {
        case 1: return .low
        case 2: return .moderate
        default: return .high
        }
    }
}

/// Plain numbers for one moment, already chosen from the best source per signal.
public struct ConditionsInput: Sendable, Equatable {
    public var pm25: Double?
    public var ozonePpb: Double?
    public var temperatureF: Double?
    public var humidityPct: Double?
    public var pollenWeedRisk: String?
    public var aqi: Int?
    public var isExtremeTemp: Bool
    public var alertNames: [String]

    public init(
        pm25: Double? = nil,
        ozonePpb: Double? = nil,
        temperatureF: Double? = nil,
        humidityPct: Double? = nil,
        pollenWeedRisk: String? = nil,
        aqi: Int? = nil,
        isExtremeTemp: Bool? = nil,
        alertNames: [String] = []
    ) {
        self.pm25 = pm25
        self.ozonePpb = ozonePpb
        self.temperatureF = temperatureF
        self.humidityPct = humidityPct
        self.pollenWeedRisk = pollenWeedRisk
        self.aqi = aqi
        self.isExtremeTemp = isExtremeTemp ?? Banding.isExtremeTemp(temperatureF)
        self.alertNames = alertNames
    }

    /// The web prototype skips logs with no usable outdoor value.
    public var hasAnyValue: Bool {
        pm25 != nil || ozonePpb != nil || temperatureF != nil || humidityPct != nil || pollenWeedRisk != nil || aqi != nil
    }
}

public enum FrameBuilder {
    /// Builds a frame from local wall-clock hour and month (1–12).
    public static func frame(
        id: String,
        kind: FrameKind,
        hourOfDay: Int,
        month: Int,
        conditions c: ConditionsInput,
        place: PlaceKind? = nil,
        indoorOutdoor: IndoorOutdoor? = nil,
        tags: Set<JournalTag> = []
    ) -> FeatureFrame {
        FeatureFrame(
            id: id,
            kind: kind,
            hourOfDay: hourOfDay,
            season: Banding.season(month: month),
            tempBand: Banding.temp(c.temperatureF, isExtreme: c.isExtremeTemp),
            humidityBand: Banding.humidity(c.humidityPct),
            pm25Band: Banding.pm25(c.pm25),
            ozoneBand: Banding.ozone(ppb: c.ozonePpb),
            pollenWeed: Banding.pollen(risk: c.pollenWeedRisk),
            smokeAtPoint: Banding.smokeAtPoint(pm25: c.pm25, aqi: c.aqi),
            heatAlert: Banding.heatAlert(isExtremeTemp: c.isExtremeTemp, alertNames: c.alertNames),
            place: place,
            indoorOutdoor: indoorOutdoor == .unknown ? nil : indoorOutdoor,
            tags: tags
        )
    }

    /// Same as above, reading hour and month from `date` in `calendar` (its time zone decides "local").
    public static func frame(
        id: String,
        kind: FrameKind,
        date: Date,
        calendar: Calendar = .current,
        conditions: ConditionsInput,
        place: PlaceKind? = nil,
        indoorOutdoor: IndoorOutdoor? = nil,
        tags: Set<JournalTag> = []
    ) -> FeatureFrame {
        let parts = calendar.dateComponents([.hour, .month], from: date)
        return frame(
            id: id, kind: kind, hourOfDay: parts.hour ?? 12, month: parts.month ?? 1,
            conditions: conditions, place: place, indoorOutdoor: indoorOutdoor, tags: tags
        )
    }
}

/// What a forecast hour gives us: weather values, and AQ only as AQI categories (AirNow forecast).
public struct ForecastConditions: Sendable, Equatable {
    public var temperatureF: Double?
    public var humidityPct: Double?
    /// AirNow category number 1–6 (1 = Good).
    public var pm25Category: Int?
    public var ozoneCategory: Int?
    public var alertNames: [String]

    public init(temperatureF: Double? = nil, humidityPct: Double? = nil, pm25Category: Int? = nil,
                ozoneCategory: Int? = nil, alertNames: [String] = []) {
        self.temperatureF = temperatureF
        self.humidityPct = humidityPct
        self.pm25Category = pm25Category
        self.ozoneCategory = ozoneCategory
        self.alertNames = alertNames
    }

    /// AQ forecast missing → score with what we have and mark the window partial.
    public var isPartial: Bool { pm25Category == nil && ozoneCategory == nil }
}

extension FrameBuilder {
    /// Forecast hour → frame with the same bins as past logs. Smoke-like air uses the past rule's
    /// AQI ≥ 51 half (any pollutant category ≥ 2), since forecasts carry no PM2.5 concentration.
    public static func forecastFrame(id: String, hourOfDay: Int, month: Int, _ c: ForecastConditions,
                                     place: PlaceKind? = nil) -> FeatureFrame {
        let extreme = Banding.isExtremeTemp(c.temperatureF)
        let worstCategory = max(c.pm25Category ?? 0, c.ozoneCategory ?? 0)
        return FeatureFrame(
            id: id,
            kind: .baseline,
            hourOfDay: hourOfDay,
            season: Banding.season(month: month),
            tempBand: Banding.temp(c.temperatureF, isExtreme: extreme),
            humidityBand: Banding.humidity(c.humidityPct),
            pm25Band: Banding.pollutant(aqiCategoryNumber: c.pm25Category),
            ozoneBand: Banding.pollutant(aqiCategoryNumber: c.ozoneCategory),
            pollenWeed: .unknown,
            smokeAtPoint: worstCategory >= 2,
            heatAlert: Banding.heatAlert(isExtremeTemp: extreme, alertNames: c.alertNames),
            place: place
        )
    }
}
