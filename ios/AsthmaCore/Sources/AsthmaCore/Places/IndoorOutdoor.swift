import Foundation

/// Motion at log time, from CoreMotion's activity classifier.
public enum MotionState: String, Sendable, Codable {
    case stationary, walking, running, cycling, automotive, unknown
}

public struct IndoorSignals: Sendable, Equatable {
    /// CLLocation.horizontalAccuracy in meters (GPS is sharp outside, blurry indoors).
    public var horizontalAccuracyM: Double?
    /// The log falls inside a confirmed place.
    public var atPlace: PlaceKind?
    public var motion: MotionState
    /// CLLocation.floor level, only present inside mapped buildings.
    public var floorLevel: Int?

    public init(horizontalAccuracyM: Double? = nil, atPlace: PlaceKind? = nil, motion: MotionState = .unknown, floorLevel: Int? = nil) {
        self.horizontalAccuracyM = horizontalAccuracyM
        self.atPlace = atPlace
        self.motion = motion
        self.floorLevel = floorLevel
    }
}

public struct IndoorGuess: Sendable, Equatable {
    public var value: IndoorOutdoor
    public var confidence: Confidence
    public var reasons: [String]
}

/// No iOS API says "indoors", so this is a scored guess the user can correct in one tap.
public enum IndoorOutdoorGuesser {
    public static func guess(_ s: IndoorSignals) -> IndoorGuess {
        var indoor = 0, outdoor = 0
        var reasons: [String] = []

        if s.floorLevel != nil {
            indoor += 2; reasons.append("inside a mapped building")
        }
        switch s.atPlace {
        case .home?, .work?:
            indoor += 2; reasons.append("at \(s.atPlace!.rawValue)")
        case .frequent?:
            indoor += 1; reasons.append("at a frequent place")
        default: break
        }
        switch s.motion {
        case .walking, .running, .cycling:
            outdoor += 2; reasons.append(s.motion.rawValue)
        case .automotive:
            indoor += 2; reasons.append("in a vehicle")
        case .stationary:
            indoor += 1; reasons.append("not moving")
        case .unknown: break
        }
        if let acc = s.horizontalAccuracyM {
            if acc > 30 { indoor += 1; reasons.append("weak GPS (±\(Int(acc)) m)") }
            else if acc <= 10 { outdoor += 1; reasons.append("sharp GPS (±\(Int(acc)) m)") }
        }

        let margin = abs(indoor - outdoor)
        guard margin > 0 else { return IndoorGuess(value: .unknown, confidence: .low, reasons: reasons) }
        let confidence: Confidence = margin >= 3 ? .high : (margin == 2 ? .medium : .low)
        return IndoorGuess(value: indoor > outdoor ? .indoor : .outdoor, confidence: confidence, reasons: reasons)
    }
}
