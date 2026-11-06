import SwiftUI

/// Menus look: the air outside as a hand-drawn little world, in ink, that you can turn (owner, Nov 6: "handmade,
/// less sterile… line art, but 3D"). The scene is 3D points projected on the fly; every line is drawn with a small
/// wobble that re-draws a few times a second (line boil), so it always looks drawn by hand.
///
/// Each part is one thing in the outdoor air:
/// - the cloud is pollution: just an outline when the air is clean, hatched more densely as it gets worse;
/// - the sun is temperature: longer, wavier rays when it's hot, a small plain circle when it's cold;
/// - the dots round the tree are tree pollen; the seed ticks on the grass are grass pollen;
/// - the flowers are weed pollen; the floating squiggles are humidity.
/// Drag sideways to turn it; tap a part to name it.
struct AirSketch: View {
    let air: AirCubeAir

    @State private var model = SketchModel()
    @State private var lastX: CGFloat = 0
    @State private var pokes = 0

    static let ink = Color(red: 0.19, green: 0.17, blue: 0.82)

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    model.step(tl.date.timeIntervalSinceReferenceDate)
                    model.draw(in: ctx, size: size)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { t in
                    if model.tap(at: t.location, size: geo.size) { pokes += 1 }
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { v in
                        if !model.dragging { lastX = 0 }
                        model.spin(by: Double(v.translation.width - lastX))
                        lastX = v.translation.width
                    }
                    .onEnded { v in model.release(velocity: Double(v.velocity.width)) }
            )
        }
        .overlay(alignment: .top) {
            if let s = model.selected {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.tip").foregroundStyle(Self.ink)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.title).font(.subheadline.weight(.semibold))
                        Text(s.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                .allowsHitTesting(false)
            }
        }
        .animation(.smooth(duration: 0.3), value: model.selected)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: pokes)
        .onAppear { model.setAir(air) }
        .onChange(of: air) { _, a in model.setAir(a) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Outdoor air, drawn")
        .accessibilityValue(model.summary)
    }
}

@MainActor @Observable
final class SketchModel {
    struct Info: Equatable { let title: String; let detail: String }
    enum Part: String { case cloud, sun, tree, grass, blooms, mist }

    private(set) var selected: Info?
    private(set) var summary = ""
    @ObservationIgnored private(set) var dragging = false

    // Targets from the air (0…1) and where the drawing is on its way there.
    private struct Levels { var pollution = 0.0, warmth = 0.5, humidity = 0.0, tree = 0.0, grass = 0.0, weed = 0.0 }
    @ObservationIgnored private var target = Levels()
    @ObservationIgnored private var now = Levels()
    @ObservationIgnored private var infos: [Part: Info] = [:]

    @ObservationIgnored private var time = 0.0
    @ObservationIgnored private var last: Double?
    @ObservationIgnored private var yaw = -0.6
    @ObservationIgnored private var yawVelocity = 0.0
    @ObservationIgnored private var idle = 10.0
    @ObservationIgnored private var springs: [Part: (x: Double, v: Double)] = [:]
    @ObservationIgnored private var anchors: [(Part, CGPoint)] = []
    @ObservationIgnored private var hide: Task<Void, Never>?

    // MARK: Air

    func setAir(_ a: AirCubeAir) {
        func share(_ v: Double, _ high: Double) -> Double { min(1, max(0, v / high)).squareRoot() }
        func level(_ n: Int) -> String { ["none reported", "low", "moderate", "high"][max(0, min(3, n))] }
        var dirt: [String] = []
        var worst = 0.0
        if a.pm25 > 0 { dirt.append("PM2.5 \(Int(a.pm25.rounded())) µg/m³"); worst = max(worst, share(a.pm25, 35)) }
        if a.pm10 > 0 { dirt.append("PM10 \(Int(a.pm10.rounded())) µg/m³"); worst = max(worst, share(a.pm10, 150)) }
        if a.ozone > 0 { dirt.append("Ozone \(Int(a.ozone.rounded())) ppb"); worst = max(worst, share(a.ozone, 70)) }
        if a.no2 > 0 { dirt.append("NO₂ \(Int(a.no2.rounded())) ppb"); worst = max(worst, share(a.no2, 100)) }
        target.pollution = worst
        target.warmth = a.tempF.map { min(1, max(0, ($0 - 35) / 60)) } ?? 0.5
        target.humidity = a.humidity > 0 ? min(1, max(0, (a.humidity - 30) / 60)) : 0
        target.tree = Double(a.tree) / 3
        target.grass = Double(a.grass) / 3
        target.weed = Double(a.weed) / 3
        let temp = a.tempF.map { t in "\(Int(t.rounded()))°F, " + (t < 45 ? "cold" : t < 60 ? "cool" : t < 75 ? "mild" : t < 85 ? "warm" : "hot") } ?? "No reading"
        infos = [
            .cloud: Info(title: "Cloud · pollution", detail: dirt.isEmpty ? "No reading" : dirt.joined(separator: " · ")),
            .sun: Info(title: "Sun · temperature", detail: temp),
            .tree: Info(title: "Dots · tree pollen", detail: "Tree pollen: \(level(a.tree))"),
            .grass: Info(title: "Grass · grass pollen", detail: "Grass pollen: \(level(a.grass))"),
            .blooms: Info(title: "Flowers · weed pollen", detail: "Weed pollen: \(level(a.weed))"),
            .mist: Info(title: "Squiggles · humidity", detail: a.humidity > 0 ? "\(Int(a.humidity.rounded()))% humidity" : "No reading"),
        ]
        summary = [Part.cloud, .sun, .tree, .grass, .blooms, .mist].compactMap { infos[$0] }.map { "\($0.title): \($0.detail)" }.joined(separator: ". ")
        if let s = selected, let fresh = infos.values.first(where: { $0.title == s.title }) { selected = fresh }
    }

    // MARK: Touch

    func spin(by dx: Double) { dragging = true; idle = 0; yaw += dx * 0.011; yawVelocity = 0 }
    func release(velocity: Double) { dragging = false; idle = 0; yawVelocity = max(-9, min(9, velocity * 0.011)) }

    func tap(at p: CGPoint, size: CGSize) -> Bool {
        guard let (part, _) = anchors.min(by: { hypot($0.1.x - p.x, $0.1.y - p.y) < hypot($1.1.x - p.x, $1.1.y - p.y) }),
              let a = anchors.first(where: { $0.0 == part }), hypot(a.1.x - p.x, a.1.y - p.y) < 90 else { return false }
        var s = springs[part] ?? (0, 0)
        s.v += 8
        springs[part] = s
        idle = 0
        selected = infos[part]
        hide?.cancel()
        hide = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.selected = nil
        }
        return true
    }

    // MARK: Frame

    func step(_ t: Double) {
        let dt = min(1 / 20, max(0, t - (last ?? t)))
        last = t
        time += dt
        idle += dt
        let k = 1 - exp(-dt * 2.2)
        now.pollution += (target.pollution - now.pollution) * k
        now.warmth += (target.warmth - now.warmth) * k
        now.humidity += (target.humidity - now.humidity) * k
        now.tree += (target.tree - now.tree) * k
        now.grass += (target.grass - now.grass) * k
        now.weed += (target.weed - now.weed) * k
        for (p, s) in springs {
            let v = s.v + (-160 * s.x - 9 * s.v) * dt
            springs[p] = (s.x + v * dt, v)
        }
        if !dragging {
            yawVelocity *= exp(-dt * 1.6)
            if idle > 3 { yawVelocity += (0.12 - yawVelocity) * (1 - exp(-dt * 0.5)) }
            yaw += yawVelocity * dt
        }
    }

    private func spring(_ p: Part) -> Double { springs[p]?.x ?? 0 }

    // MARK: Drawing

    /// Isometric-ish: turn round y, then tip toward the viewer.
    private struct View3D {
        let yaw: Double, scale: Double, origin: CGPoint
        let tilt = 0.52
        func rotated(_ p: SIMD3<Double>) -> SIMD3<Double> {
            let c = cos(yaw), s = sin(yaw)
            return [p.x * c - p.z * s, p.y, p.x * s + p.z * c]
        }
        func point(_ p: SIMD3<Double>) -> CGPoint {
            let r = rotated(p)
            return CGPoint(x: origin.x + r.x * scale, y: origin.y - (r.y * cos(tilt) - r.z * sin(tilt)) * scale)
        }
        func depth(_ p: SIMD3<Double>) -> Double { rotated(p).z }
    }

    /// A tiny repeatable noise in −1…1.
    private static func noise(_ a: Int, _ b: Int) -> Double {
        var h = UInt64(bitPattern: Int64(a &* 73_856_093 ^ b &* 19_349_663))
        h = (h ^ (h >> 31)) &* 0x9E37_79B9_7F4A_7C15
        h ^= h >> 29
        return Double(h >> 11) / Double(1 << 53) * 2 - 1
    }

    func draw(in ctx: GraphicsContext, size: CGSize) {
        let scale = min(size.width / 3.1, size.height / 2.6)
        let v = View3D(yaw: yaw, scale: scale, origin: CGPoint(x: size.width / 2, y: size.height * 0.66))
        let frame = Int(time * 7)   // line boil: a fresh wobble seven times a second
        let ink = AirSketch.ink
        let paper = Color(uiColor: .systemGroupedBackground)
        anchors = []

        /// Straight lines, drawn by hand: each edge split into short steps that wobble a little.
        func shaky(_ corners: [CGPoint], seed: Int, closed: Bool = false) -> Path {
            var pts: [CGPoint] = []
            let n = closed ? corners.count : corners.count - 1
            for i in 0..<n {
                let a = corners[i], b = corners[(i + 1) % corners.count]
                for k in 0..<6 { let t = Double(k) / 6; pts.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) }
            }
            pts.append(closed ? corners[0] : corners[corners.count - 1])
            let q = pts.enumerated().map { i, p in
                CGPoint(x: p.x + Self.noise(seed &+ i, frame) * 0.9, y: p.y + Self.noise(seed &+ i &+ 977, frame) * 0.9)
            }
            var path = Path()
            path.addLines(q)
            return path
        }
        func wobbly(_ pts: [CGPoint], seed: Int, closed: Bool = false, amount: Double = 1.1) -> Path {
            let q = pts.enumerated().map { i, p in
                CGPoint(x: p.x + Self.noise(seed &+ i, frame) * amount, y: p.y + Self.noise(seed &+ i &+ 977, frame) * amount)
            }
            var path = Path()
            guard q.count > 1 else { return path }
            path.move(to: q[0])
            if q.count == 2 { path.addLine(to: q[1]); return path }
            for i in 1..<q.count {
                let mid = CGPoint(x: (q[i - 1].x + q[i].x) / 2, y: (q[i - 1].y + q[i].y) / 2)
                path.addQuadCurve(to: mid, control: q[i - 1])
            }
            path.addLine(to: q[q.count - 1])
            if closed { path.addQuadCurve(to: q[0], control: q[q.count - 1]) }
            return path
        }
        func stroke(_ p: Path, _ w: Double = 2) {
            ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
        /// A local drawing (unit coordinates, y up) placed at a 3D point, facing you.
        func local(_ pts: [CGPoint], at base: CGPoint, size s: Double) -> [CGPoint] {
            pts.map { CGPoint(x: base.x + $0.x * s, y: base.y - $0.y * s) }
        }

        // Things to draw, back to front.
        var items: [(depth: Double, draw: () -> Void)] = []

        // Ground: the tile's top edge all round, and its sides where they face you.
        let half = 0.95, low = -0.22
        let corners: [SIMD3<Double>] = [[-half, 0, -half], [half, 0, -half], [half, 0, half], [-half, 0, half]]
        items.append((-10, {
            stroke(shaky(corners.map(v.point), seed: 11, closed: true), 2.2)
            for i in 0..<4 {
                let a = corners[i], b = corners[(i + 1) % 4]
                // A side faces you when its middle is nearer than the tile's centre.
                let mid = (a + b) / 2
                guard v.depth(mid) > 0.05 else { continue }
                let a2 = SIMD3<Double>(a.x, low, a.z), b2 = SIMD3<Double>(b.x, low, b.z)
                stroke(shaky([v.point(a), v.point(a2)], seed: 30 + i), 1.8)
                stroke(shaky([v.point(b), v.point(b2)], seed: 40 + i), 1.8)
                stroke(shaky([v.point(a2), v.point(b2)], seed: 50 + i), 1.8)
                // Earth: a few short strokes down the side.
                for j in 1..<5 {
                    let t = Double(j) / 5
                    let p = a + (b - a) * t
                    let top = v.point([p.x, -0.06, p.z]), bot = v.point([p.x, -0.13 - 0.04 * Self.noise(i, j), p.z])
                    stroke(wobbly([top, bot], seed: 60 + i * 9 + j, amount: 0.6), 1.2)
                }
            }
        }))

        // Grass: little squiggles on the ground, taller with grass pollen; seed ticks when there's pollen.
        let g = spring(.grass)
        for i in 0..<16 {
            let x = Self.noise(i, 1) * 0.78, z = Self.noise(i, 2) * 0.78
            let base = SIMD3<Double>(x, 0, z)
            items.append((v.depth(base), {
                let p = v.point(base)
                let h = 0.06 + 0.07 * self.now.grass
                let sway = sin(self.time * 1.4 + Double(i)) * (0.012 + g * 0.03)
                let droop = max(0, self.now.warmth - 0.6) * 0.04
                var pts: [CGPoint] = []
                for k in 0..<7 {
                    let xx = Double(k) * 0.03 - 0.09
                    let yy = k.isMultiple(of: 2) ? 0 : h - droop
                    pts.append(CGPoint(x: xx + (yy > 0 ? sway : 0), y: yy))
                }
                stroke(wobbly(local(pts, at: p, size: v.scale), seed: 200 + i * 7), 1.6)
                if self.now.grass > 0.05 {
                    for k in [1, 3, 5] {
                        let tip = local([CGPoint(x: Double(k) * 0.03 - 0.09 + sway, y: h - droop)], at: p, size: v.scale)[0]
                        let r = 2.2 * self.now.grass + 0.6
                        ctx.fill(Path(ellipseIn: CGRect(x: tip.x - r, y: tip.y - r * 1.6, width: r * 2, height: r * 2.4)), with: .color(ink))
                    }
                }
            }))
            if i == 0 { anchors.append((.grass, v.point(base))) }
        }

        // Rocks.
        for (i, r) in [SIMD3<Double>(-0.45, 0, -0.6), [0.65, 0, 0.2], [0.2, 0, 0.7]].enumerated() {
            items.append((v.depth(r), {
                let c = v.point(r)
                let pts = (0..<10).map { k -> CGPoint in
                    let a = Double(k) / 10 * 2 * .pi
                    return CGPoint(x: cos(a) * 0.07 * (1 + 0.15 * Self.noise(i, k)), y: max(0, sin(a)) * 0.05)
                }
                let path = wobbly(local(pts, at: c, size: v.scale), seed: 300 + i * 11, closed: true)
                ctx.fill(path, with: .color(paper))
                stroke(path, 1.6)
            }))
        }

        // Tree: trunk, a branch, and a bumpy canopy; tree pollen as dots drifting round it.
        let treeBase = SIMD3<Double>(-0.1, 0, 0.05)
        let tw = spring(.tree)
        items.append((v.depth(treeBase), {
            let b = v.point(treeBase)
            let s = v.scale
            stroke(wobbly(local([CGPoint(x: -0.035, y: 0), CGPoint(x: -0.03, y: 0.3), CGPoint(x: -0.025, y: 0.62)], at: b, size: s), seed: 400), 2)
            stroke(wobbly(local([CGPoint(x: 0.04, y: 0), CGPoint(x: 0.03, y: 0.3), CGPoint(x: 0.025, y: 0.62)], at: b, size: s), seed: 410), 2)
            stroke(wobbly(local([CGPoint(x: 0.03, y: 0.36), CGPoint(x: 0.14, y: 0.5), CGPoint(x: 0.2, y: 0.56)], at: b, size: s), seed: 420), 1.8)
            let wob = sin(self.time * 0.9) * 0.01 + tw * 0.03
            let canopy = (0..<44).map { k -> CGPoint in
                let a = Double(k) / 44 * 2 * .pi
                let r = 0.34 * (1 + 0.09 * sin(7 * a + 1.3) + 0.04 * sin(13 * a)) * (1 + tw * 0.06)
                return CGPoint(x: cos(a) * r * 1.08 + wob, y: 0.9 + sin(a) * r)
            }
            let path = wobbly(local(canopy, at: b, size: s), seed: 430, closed: true)
            ctx.fill(path, with: .color(paper))
            stroke(path, 2.2)
            // A few leaf marks inside.
            for k in 0..<5 {
                let cx = Self.noise(k, 9) * 0.18, cy = 0.9 + Self.noise(k, 10) * 0.14
                stroke(wobbly(local([CGPoint(x: cx - 0.03, y: cy), CGPoint(x: cx, y: cy + 0.025), CGPoint(x: cx + 0.03, y: cy)], at: b, size: s), seed: 440 + k * 5), 1.3)
            }
        }))
        anchors.append((.tree, v.point(treeBase + [0, 0.9, 0])))
        let pollenCount = Int((self.now.tree * 22).rounded())
        for i in 0..<pollenCount {
            let a = Double(i) * 2.399 + time * (0.18 + 0.05 * Self.noise(i, 3)) * (1 + tw * 2)
            let r = 0.42 + 0.2 * abs(Self.noise(i, 4))
            let p3 = treeBase + SIMD3<Double>(cos(a) * r, 0.75 + 0.35 * Self.noise(i, 5) + sin(time * 0.7 + Double(i)) * 0.05, sin(a) * r)
            items.append((v.depth(p3), {
                let p = v.point(p3)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(ink))
            }))
        }

        // Pines: stacked zigzag triangles.
        for (i, (p3, h)) in [(SIMD3<Double>(0.6, 0, -0.55), 0.8), ([-0.62, 0, -0.45], 0.6)].enumerated() {
            items.append((v.depth(p3), {
                let b = v.point(p3)
                stroke(wobbly(local([CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0.12 * h)], at: b, size: v.scale), seed: 500 + i), 1.8)
                for k in 0..<3 {
                    let kf = Double(k)
                    let w = (0.22 - kf * 0.05) * h, y0 = (0.12 + kf * 0.2) * h, y1 = y0 + 0.36 * h
                    let tri = [CGPoint(x: -w, y: y0), CGPoint(x: 0, y: y1), CGPoint(x: w, y: y0)]
                    let path = shaky(local(tri, at: b, size: v.scale), seed: 510 + i * 13 + k, closed: true)
                    ctx.fill(path, with: .color(paper))
                    stroke(path, 1.9)
                }
            }))
        }

        // Flowers: doodled daisies, opening as weed pollen rises.
        let w = spring(.blooms)
        let flowerCount = Int((now.weed * 7).rounded(.up))
        for i in 0..<flowerCount {
            let p3 = SIMD3<Double>(Self.noise(i, 21) * 0.7, 0, Self.noise(i, 22) * 0.7)
            items.append((v.depth(p3), {
                let b = v.point(p3)
                let s = v.scale * (0.9 + w * 0.15)
                let top = CGPoint(x: sin(self.time * 1.1 + Double(i)) * 0.01, y: 0.2)
                stroke(wobbly(local([CGPoint(x: 0, y: 0), CGPoint(x: 0.005, y: 0.1), top], at: b, size: s), seed: 600 + i * 7), 1.6)
                stroke(wobbly(local([CGPoint(x: 0.004, y: 0.07), CGPoint(x: 0.05, y: 0.1), CGPoint(x: 0.07, y: 0.12), CGPoint(x: 0.03, y: 0.08)], at: b, size: s), seed: 610 + i * 7, closed: true), 1.3)
                for k in 0..<5 {
                    let a = Double(k) / 5 * 2 * .pi + 0.3
                    let petal = (0..<8).map { j -> CGPoint in
                        let t = Double(j) / 7 * .pi
                        let rr = 0.045 * sin(t)
                        let ang = a + (t - .pi / 2) * 0.35
                        return CGPoint(x: top.x + cos(ang) * rr * 1.5 + cos(a) * 0.012, y: top.y + sin(ang) * rr * 1.5 + sin(a) * 0.012)
                    }
                    stroke(wobbly(local(petal, at: b, size: s), seed: 620 + i * 31 + k * 3), 1.4)
                }
                let c = local([top], at: b, size: s)[0]
                ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(ink), lineWidth: 1.4)
            }))
            if i == 0 { anchors.append((.blooms, v.point(p3 + [0, 0.2, 0]))) }
        }

        // Humidity: floating squiggles, drifting slowly through the air; more of them when it's humid.
        let ms = spring(.mist)
        let mistCount = Int((now.humidity * 9).rounded())
        for i in 0..<mistCount {
            let a = Double(i) * 1.7 + time * (0.05 + 0.02 * Self.noise(i, 6)) * (1 + abs(ms) * 3)
            let r = 0.5 + 0.45 * abs(Self.noise(i, 7))
            let p3 = SIMD3<Double>(cos(a) * r, 0.55 + 0.75 * abs(Self.noise(i, 8)) + sin(time * 0.4 + Double(i)) * 0.04, sin(a) * r)
            items.append((v.depth(p3), {
                let c = v.point(p3)
                let pts = (0..<9).map { k -> CGPoint in
                    let x = Double(k) / 8 * 0.26 - 0.13
                    return CGPoint(x: x, y: sin(Double(k) * 1.4 + self.time * 1.2 + Double(i)) * 0.018)
                }
                stroke(wobbly(local(pts, at: c, size: v.scale), seed: 700 + i * 13, amount: 0.8), 1.4)
            }))
            if i == 0 { anchors.append((.mist, v.point(p3))) }
        }

        // Cloud: bumpy on top, flat underneath with a small gap; hatched as pollution rises.
        let cl = spring(.cloud)
        let cloud3 = SIMD3<Double>(0.5 + sin(time * 0.11) * 0.1, 1.2 + sin(time * 0.37) * 0.04, -0.2)
        items.append((v.depth(cloud3) + 5, {
            let c = v.point(cloud3)
            let s = v.scale * 0.85 * (1 + cl * 0.08)
            let bumps: [(Double, Double, Double)] = [(-0.36, 0.1, 0.14), (-0.16, 0.22, 0.17), (0.08, 0.27, 0.2), (0.28, 0.18, 0.14), (0.4, 0.08, 0.1)]
            var top: [CGPoint] = []
            for k in 0...48 {
                let x = Double(k) / 48 * 1.0 - 0.5
                var y = 0.0
                for (cx, cy, r) in bumps where abs(x - cx) < r { y = max(y, cy + (r * r - (x - cx) * (x - cx)).squareRoot()) }
                top.append(CGPoint(x: x, y: max(y, 0.02)))
            }
            let outline = local(top + [CGPoint(x: 0.5, y: 0), CGPoint(x: -0.42, y: 0)], at: c, size: s)
            let path = wobbly(outline, seed: 800)
            var shape = path
            shape.closeSubpath()
            ctx.fill(shape, with: .color(paper))
            // Hatching: denser as pollution rises; crossed when it's high.
            let p = self.now.pollution
            if p > 0.04 {
                ctx.drawLayer { l in
                    l.clip(to: shape)
                    let rect = shape.boundingRect
                    let gap = 16 - 11 * p
                    var x = rect.minX - rect.height
                    var n = 0
                    while x < rect.maxX {
                        let line = wobbly([CGPoint(x: x, y: rect.maxY), CGPoint(x: x + rect.height, y: rect.minY)], seed: 900 + n, amount: 0.7)
                        l.stroke(line, with: .color(ink.opacity(0.75)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                        x += gap
                        n += 1
                    }
                    if p > 0.6 {
                        x = rect.minX
                        while x < rect.maxX + rect.height {
                            let line = wobbly([CGPoint(x: x, y: rect.maxY), CGPoint(x: x - rect.height, y: rect.minY)], seed: 1000 + n, amount: 0.7)
                            l.stroke(line, with: .color(ink.opacity(0.6)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                            x += gap * 1.3
                            n += 1
                        }
                    }
                }
            }
            stroke(path, 2.3)
        }))
        anchors.append((.cloud, v.point(cloud3 + [0, 0.12, 0])))

        // Sun: fixed in the sky; its rays are the temperature.
        let sw = spring(.sun)
        items.append((-100, {
            let c = CGPoint(x: size.width * 0.2, y: size.height * 0.16)
            let r = 15.0 * (1 + sw * 0.15)
            let circle = (0..<18).map { k -> CGPoint in
                let a = Double(k) / 18 * 2 * .pi
                return CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            }
            stroke(wobbly(circle, seed: 1100, closed: true), 2)
            let warm = self.now.warmth
            if warm > 0.25 {
                let len = 6 + 16 * (warm - 0.25) / 0.75
                for k in 0..<9 {
                    let a = Double(k) / 9 * 2 * .pi + self.time * 0.05
                    let pts = (0..<4).map { j -> CGPoint in
                        let d = r + 5 + len * Double(j) / 3
                        let wav = warm > 0.7 ? sin(Double(j) * 2 + self.time * 2) * 2.2 : 0
                        return CGPoint(x: c.x + cos(a) * d - sin(a) * wav, y: c.y + sin(a) * d + cos(a) * wav)
                    }
                    stroke(wobbly(pts, seed: 1200 + k * 5, amount: 0.6), 1.6)
                }
            }
        }))
        anchors.append((.sun, CGPoint(x: size.width * 0.2, y: size.height * 0.16)))

        for item in items.sorted(by: { $0.depth < $1.depth }) { item.draw() }
    }
}
