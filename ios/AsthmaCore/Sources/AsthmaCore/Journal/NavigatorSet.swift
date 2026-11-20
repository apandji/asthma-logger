import Foundation

/// Real hourly outdoor air for the cities a made-up person moved through, pulled by
/// `ios/scripts/pull-navigator-air.py` into `navigator-air.json`: Open-Meteo for the six weeks (PM2.5, ozone,
/// temperature, humidity, wind), Ambee for the last two days in the city they're in now (with pollen).
public struct NavigatorAir: Codable, Sendable {
    public struct Hour: Codable, Sendable {
        public var t: Double
        public var pm25: Double?
        public var ozone: Double?
        public var tempF: Double?
        public var humidity: Double?
        public var wind: Double?
        /// Sea-level pressure, hPa.
        public var pressure: Double?
        public var tree: Double?
        public var grass: Double?
        public var weed: Double?
        public var species: Species?
        public var date: Date { Date(timeIntervalSince1970: t) }
    }

    public struct Species: Codable, Sendable {
        public var tree: [String: Double]?
        public var grass: [String: Double]?
        public var weed: [String: Double]?
        public var others: Double?
    }

    public struct City: Codable, Sendable {
        public var name: String
        public var latitude: Double
        public var longitude: Double
        public var timeZone: String
        public var hours: [Hour]
    }

    public var pulledAt: Double
    public var cities: [City]
    public var ambeeCity: String?
    public var ambee: [Hour]
}

/// The navigator (Settings › Demo and development): a travel nurse between contracts. Two weeks finishing in
/// Fresno, twelve days at her sister's in Denver, two weeks into a new contract in St. Louis. Every move
/// resets "usual": new air, new home, no regular doctor. Her moments are made up; the air on each one is the
/// real reading for that city and hour (`NavigatorAir`), labelled with the source it came from.
///
/// What's true of her: she reaches for the inhaler when fine particles are up, in every city. Nothing is
/// forced. Rescue moments are placed mostly on hours when the real PM2.5 was 12 µg/m³ or more, baselines three
/// times a day whatever the air, and the pattern comes out of the same lift table as real data.
public enum NavigatorSet {
    public static let title = "The navigator · travel nurse"
    public static let openMeteo = "Open-Meteo"

    public struct Place: Sendable {
        public let name: String
        public let latitude: Double
        public let longitude: Double
        public let outdoor: Bool
    }

    public struct Moment: Sendable {
        public let kind: MomentKind
        public let at: Date
        public let conditions: Conditions
        public let city: String
        public let place: Place
        public let tags: Set<JournalTag>
        public let tagsReviewed: Bool
        /// What she said into the phone, on a few moments.
        public let note: String?
        public let puffs: Int
    }

    /// Home, work and somewhere outdoors in each city. Denver has no work: she's between contracts.
    static func places(_ city: String) -> (home: Place, work: Place?, out: Place) {
        switch city {
        case "Fresno":
            (Place(name: "Tower District, Fresno", latitude: 36.7570, longitude: -119.8010, outdoor: false),
             Place(name: "Downtown Fresno", latitude: 36.7420, longitude: -119.7850, outdoor: false),
             Place(name: "Woodward Park, Fresno", latitude: 36.8640, longitude: -119.7830, outdoor: true))
        case "Denver":
            (Place(name: "Capitol Hill, Denver", latitude: 39.7340, longitude: -104.9790, outdoor: false), nil,
             Place(name: "Washington Park, Denver", latitude: 39.7000, longitude: -104.9710, outdoor: true))
        default:
            (Place(name: "Tower Grove South", latitude: 38.5958, longitude: -90.2552, outdoor: false),
             Place(name: "Central West End", latitude: 38.6360, longitude: -90.2630, outdoor: false),
             Place(name: "Forest Park", latitude: 38.6372, longitude: -90.2930, outdoor: true))
        }
    }

    static func place(in city: String, hour: Int, weekend: Bool) -> Place {
        let p = places(city)
        switch hour {
        case ..<8, 20...: return p.home
        case 17..<20: return p.out
        default: return weekend ? p.out : (p.work ?? p.out)
        }
    }

    /// Rescue moments per city, and how many of them fall on hours with fine particles up.
    static let plan: [String: (rescues: Int, onParticles: Int)] = ["Fresno": (6, 5), "Denver": (4, 3), "St. Louis": (6, 4)]

    /// Notes for some rescue moments, in order, by whether particles were up. Short, the way people talk.
    static let particleNotes: [(String, Set<JournalTag>)] = [
        ("Walking to the car after my shift. The sky was brown and my chest got tight.", [.chestTightness]),
        ("Smelled smoke from the fields on the drive in. Started coughing at the light.", [.smoke, .coughing]),
        ("Took the stairs at work and couldn't catch my breath at the top.", [.exercise, .shortOfBreath]),
        ("Hazy out. Wheezy since lunch. One puff helped.", [.wheezing, .betterAfter]),
        ("Walked to the pharmacy by the highway. Tight chest by the time I got back.", [.chestTightness]),
    ]
    static let otherNotes: [(String, Set<JournalTag>)] = [
        ("Woke up coughing. New apartment, the heat was on all night.", [.wokeAtNight, .coughing]),
        ("Ran for the bus in the cold.", [.exercise, .coldAir]),
    ]

    public static func moments(air: NavigatorAir, seed: UInt64 = 29) -> [Moment] {
        var rng = SeededRandom(seed: seed)
        let recent = Dictionary(air.ambee.map { ($0.t, $0) }, uniquingKeysWith: { a, _ in a })
        var out: [Moment] = []
        var particleNote = 0, otherNote = 0

        for city in air.cities {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: city.timeZone) ?? .current
            let usable = city.hours.filter { $0.pm25 != nil && $0.tempF != nil }
            let waking = usable.filter { (6...22).contains(cal.component(.hour, from: $0.date)) }

            func conditions(_ h: NavigatorAir.Hour, at: Date) -> Conditions {
                var obs: [EnvObservation] = []
                func add(_ s: Signal, _ v: Double?, _ unit: String, _ source: String, category: String? = nil) {
                    guard let v else { return }
                    obs.append(EnvObservation(signal: s, value: v, unit: unit, asOf: h.date, source: source,
                                              spatialScale: .modelGrid, confidence: .medium, category: category))
                }
                // The last two days in the current city: Ambee's air and pollen first, so they're what's shown.
                if city.name == air.ambeeCity, let a = recent[h.t] {
                    add(.pm25, a.pm25, "µg/m³", Ambee.source)
                    add(.ozone, a.ozone, "ppb", Ambee.source)
                    add(.pollenTree, a.tree, "particles/m³", Ambee.source)
                    add(.pollenGrass, a.grass, "particles/m³", Ambee.source)
                    add(.pollenWeed, a.weed, "particles/m³", Ambee.source,
                        category: a.weed.map { $0 < 20 ? "Low" : $0 < 77 ? "Moderate" : "High" })
                }
                add(.pm25, h.pm25, "µg/m³", openMeteo)
                add(.ozone, h.ozone, "ppb", openMeteo)
                add(.temperature, h.tempF, "°F", openMeteo)
                add(.humidity, h.humidity, "%", openMeteo)
                add(.windSpeed, h.wind, "mph", openMeteo)
                var c = Conditions(observations: obs, fetchedAt: at)
                if city.name == air.ambeeCity, let s = recent[h.t]?.species {
                    c.pollenSpecies = PollenSpecies(tree: s.tree ?? [:], grass: s.grass ?? [:], weed: s.weed ?? [:], others: s.others,
                                                    source: Ambee.source, asOf: h.date)
                }
                // The pressure and how far it moved in the three hours before, from the same real series.
                if let p = h.pressure {
                    c.observations.append(EnvObservation(signal: .pressure, value: p, unit: "hPa", asOf: h.date, source: openMeteo,
                                                         spatialScale: .modelGrid, confidence: .medium))
                    c.pressureChangeHpa = PressureChange.change(at: h.date, in: city.hours.compactMap { x in x.pressure.map { PressurePoint(date: x.date, hPa: $0) } })
                }
                // °F fallen over the three hours before, from the same real series.
                if let now = h.tempF {
                    let before = city.hours.filter { $0.t >= h.t - 3 * 3600 && $0.t < h.t }.compactMap(\.tempF)
                    if let high = before.max() { c.tempFallF = max(0, high - now) }
                }
                return c
            }

            func moment(_ kind: MomentKind, _ h: NavigatorAir.Hour, note: (String, Set<JournalTag>)? = nil, puffs: Int = 1) -> Moment {
                let at = h.date.addingTimeInterval(Double(rng.int(2, 56)) * 60)
                let hour = cal.component(.hour, from: at)
                let p = place(in: city.name, hour: hour, weekend: cal.isDateInWeekend(at))
                return Moment(kind: kind, at: at, conditions: conditions(h, at: at), city: city.name, place: p,
                              tags: note?.1 ?? [], tagsReviewed: note != nil, note: note?.0, puffs: puffs)
            }

            // Rescues: mostly on hours when fine particles were up, at most one a day.
            let (n, onParticles) = plan[city.name] ?? (4, 3)
            var days: Set<Date> = []
            var rescues: [Moment] = []
            func pick(_ pool: [NavigatorAir.Hour], _ count: Int, particles: Bool) {
                var pool = pool
                var taken = 0
                while taken < count, !pool.isEmpty {
                    let h = pool.remove(at: rng.int(0, pool.count - 1))
                    let day = cal.startOfDay(for: h.date)
                    guard !days.contains(day) else { continue }
                    days.insert(day)
                    var note: (String, Set<JournalTag>)?
                    // About two in three have a note; the rest are a press and nothing more.
                    if rng.chance(0.65) {
                        if particles, particleNote < particleNotes.count { note = particleNotes[particleNote]; particleNote += 1 }
                        if !particles, otherNote < otherNotes.count { note = otherNotes[otherNote]; otherNote += 1 }
                    }
                    rescues.append(moment(.rescue, h, note: note, puffs: rng.chance(0.6) ? 2 : 1))
                    taken += 1
                }
            }
            pick(waking.filter { ($0.pm25 ?? 0) >= Banding.smokePM25 }, onParticles, particles: true)
            pick(waking.filter { ($0.pm25 ?? 0) < Banding.smokePM25 }, n - onParticles, particles: false)

            // Baselines: morning, afternoon and evening of every day, clear of inhaler use by two hours.
            var baselines: [Moment] = []
            for h in usable where [9, 14, 19].contains(cal.component(.hour, from: h.date)) {
                let m = moment(.okay, h)
                if rescues.allSatisfy({ abs($0.at.timeIntervalSince(m.at)) > 2 * 3600 }) { baselines.append(m) }
            }
            out += rescues + baselines
        }
        return out.sorted { $0.at < $1.at }
    }
}
