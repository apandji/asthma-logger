import Testing
@testable import AsthmaCore

@Suite struct AirAdviceTests {
    private var allCopy: [String] {
        let events = AirAdvice.Event.allCases.flatMap { e -> [String] in
            let w = AirAdvice.warning(e, fallF: 16)
            return [w.headline, w.stayingPut, w.goingOut, AirAdvice.afterFlare(e, fallF: 16), AirAdvice.afterFlare(e)]
        }
        let factors = AirAdvice.Factor.allCases.flatMap { f -> [String] in
            let w = AirAdvice.warning(f)
            return [w.headline, w.stayingPut, w.goingOut, f.whatItIs]
        }
        return events + factors + [AirAdvice.disclaimer]
    }

    @Test func neverNamesACause() {
        for line in allCopy {
            for word in AirAdvice.bannedWords {
                #expect(!line.lowercased().contains(word), "“\(line)” uses “\(word)”")
            }
        }
    }

    @Test func noSemicolonsInUIText() {
        #expect(allCopy.allSatisfy { !$0.contains(";") })
    }

    @Test func homeIsStayingPutElseGoingOut() {
        #expect(AirAdvice.Context.at(home: true) == .stayingPut)
        #expect(AirAdvice.Context.at(home: false) == .goingOut)
        let w = AirAdvice.warning(.smoke)
        #expect(w.advice(.goingOut).contains("N95"))
    }

    @Test func temperatureDropUsesTheNumber() {
        #expect(AirAdvice.warning(.tempDrop, fallF: 15.6).headline == "It's 16° colder than three hours ago.")
        #expect(AirAdvice.afterFlare(.tempDrop, fallF: 12) == "It was 12° colder than three hours before.")
    }

    @Test func moldNeedsRainHumidityAndWarmth() {
        #expect(AirAdvice.isMoldWeather(condition: "Rain", humidity: 80, temperatureF: 72))
        #expect(!AirAdvice.isMoldWeather(condition: "Rain", humidity: 50, temperatureF: 72))
        #expect(!AirAdvice.isMoldWeather(condition: "Clear", humidity: 80, temperatureF: 72))
        #expect(!AirAdvice.isMoldWeather(condition: "Drizzle", humidity: 80, temperatureF: 50))
    }
}
