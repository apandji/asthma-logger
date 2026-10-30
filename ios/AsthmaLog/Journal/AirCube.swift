import RealityKit
import SwiftUI
import UIKit

/// What's in the outdoor air at this time, for the sphere. The readings set how many particles of each kind
/// there are; the counts follow the reading but are capped and not to scale.
struct AirCubeAir: Equatable {
    var pm25: Double = 0      // µg/m³
    var pm10: Double = 0      // µg/m³
    var ozone: Double = 0     // ppb
    var no2: Double = 0       // ppb
    var tree = 0, grass = 0, weed = 0   // pollen, 0…3 (none, low, moderate, high)
    var humidity: Double = 0  // %
    var tempF: Double?
    /// What you felt then, for the label on the sphere in the middle ("Rescue at 11:45 AM").
    var feltLabel: String = "Nothing logged"
}

/// Design crit › Menus sky: the air as a clear, softly rounded glass cube holding what's in it as abstract low-poly particles
/// with physics (RealityKit). Drag to spin it: gravity stays down on screen, so the contents fall and drift to the
/// new bottom. Each kind has its own weight: PM10 pebbles settle, PM2.5 and NO₂ motes shimmer and sink slowly,
/// ozone shards hang, pollen floats as dandelion seeds, humidity is water pooling at the bottom. You are the sphere in the middle (rescue
/// orange, standard blue, clear when nothing was logged); the particles bounce off you. The glass is clear, its
/// edges and corners rounded, tinted by the temperature.
/// Tap it to open it full screen; there, tap a particle and a fine line names it, scientific-figure style.
struct AirCube: View {
    let air: AirCubeAir
    let felt: MenusFelt
    @State private var expanded = false

    var body: some View {
        AirCubeStage(air: air, felt: felt, full: false)
            .contentShape(Rectangle())
            .onTapGesture { expanded = true }
            .fullScreenCover(isPresented: $expanded) {
                AirCubeFull(air: air, felt: felt, close: { expanded = false })
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the cube full screen")
    }
}

/// Full screen: a bigger cube, and tap-to-annotate.
private struct AirCubeFull: View {
    let air: AirCubeAir
    let felt: MenusFelt
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 6) {
                Text("The air, then").font(.title2.weight(.bold))
                Text("Drag to spin. Tap a particle to see what it is.").font(.subheadline).foregroundStyle(.secondary)
                AirCubeStage(air: air, felt: felt, full: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("Outdoor air, regional readings. Drawn, not to scale.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 20)
            Button(action: close) {
                Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 22, height: 22)
            }
            .buttonStyle(.glass).buttonBorderShape(.circle)
            .padding(.trailing, 20).padding(.top, 8)
            .accessibilityLabel("Close")
        }
    }
}

/// The cube itself: the 3D layer, the drag to spin, and, full screen, the annotation.
private struct AirCubeStage: View {
    let air: AirCubeAir
    let felt: MenusFelt
    let full: Bool
    @State private var world = CubeWorld()

    var body: some View {
        GeometryReader { g in
            let size = g.size
            let r = world.screenRadius(in: size)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            ZStack {
                // A soft shadow on the page, so it sits there.
                Ellipse().fill(Color.black.opacity(0.07)).frame(width: r * 1.7, height: r * 0.2).blur(radius: 12)
                    .position(x: center.x, y: center.y + r * 1.25)
                RealityView { content in
                    content.camera = .virtual
                    world.build(into: content, air: air, felt: felt)
                }
                if full, let a = world.annotation { annotation(a, size: size, sphere: r) }
            }
            .onAppear { world.viewSize = size }
            .onChange(of: size) { _, s in world.viewSize = s }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { v in world.drag(v.translation) }
                    .onEnded { v in world.release(velocity: v.velocity) }
            )
            .simultaneousGesture(full ? SpatialTapGesture().onEnded { t in world.select(at: t.location) } : nil)
        }
        .accessibilityElement()
        .accessibilityLabel("A glass cube of outdoor air")
        .accessibilityValue(world.summary(air))
    }

    /// Scientific-figure annotation: a small ring on the particle, a hairline out to the side the particle isn't
    /// on, a short horizontal run, and the label set against it. No card.
    @ViewBuilder private func annotation(_ a: CubeWorld.Annotation, size: CGSize, sphere r: CGFloat) -> some View {
        let p = a.point
        let right = p.x < size.width / 2
        let elbow = CGPoint(x: right ? size.width / 2 + r * 0.9 : size.width / 2 - r * 0.9, y: max(40, min(size.height - 70, p.y - 50)))
        let end = CGPoint(x: right ? size.width - 8 : 8, y: elbow.y)
        Path { path in path.move(to: p); path.addLine(to: elbow); path.addLine(to: end) }
            .stroke(Color.primary.opacity(0.8), lineWidth: 0.75)
        Circle().stroke(Color.primary, lineWidth: 0.75).frame(width: 18, height: 18).position(p)
        Circle().fill(Color.primary).frame(width: 3, height: 3).position(elbow)
        VStack(alignment: right ? .trailing : .leading, spacing: 2) {
            Text(a.title.uppercased()).font(.caption2.weight(.semibold)).tracking(0.8)
            if let v = a.value { Text(v).font(.title3.weight(.semibold).monospacedDigit()) }
            Text(a.detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(right ? .trailing : .leading)
        }
        .frame(width: 150, alignment: right ? .trailing : .leading)
        .position(x: right ? end.x - 75 : end.x + 75, y: elbow.y + 34)
        .allowsHitTesting(false)
    }
}

/// The sphere's scene and its bit of physics bookkeeping.
@MainActor @Observable
final class CubeWorld {
    struct Info {
        let title: String
        let value: String?
        let detail: String
    }
    struct Annotation {
        let title: String
        let value: String?
        let detail: String
        var point: CGPoint
    }
    private struct Floater {
        let body: ModelEntity
        let lift: Float
        let jitter: Float
        let r: Float
        let info: Info
    }

    var viewSize: CGSize = .zero
    private(set) var annotation: Annotation?
    @ObservationIgnored private let root = Entity()
    @ObservationIgnored private var floaters: [Floater] = []
    /// Each floater's drift direction, turning slowly.
    @ObservationIgnored private var wander: [SIMD3<Float>] = []
    @ObservationIgnored private var selected: Int?
    @ObservationIgnored private var spin = SIMD2<Float>(0, 0)
    @ObservationIgnored private var lastDrag = CGSize.zero
    @ObservationIgnored private var dragging = false
    @ObservationIgnored private var update: EventSubscription?
    // Water: one body, the cube's inside below a surface that tries to stay level and sloshes on the way.
    @ObservationIgnored private var water: ModelEntity?
    @ObservationIgnored private var waterFill: Float = 0
    @ObservationIgnored private var surfaceUp = SIMD3<Float>(0, 1, 0)
    @ObservationIgnored private var surfaceVel = SIMD3<Float>(0, 0, 0)
    @ObservationIgnored private var surfaceH: Float = 0
    @ObservationIgnored private var drawnUp = SIMD3<Float>(0, 0, 0)
    @ObservationIgnored private var waterInfo = Info(title: "Humidity", value: nil, detail: "")
    @ObservationIgnored private var youInfo = Info(title: "You", value: nil, detail: "")
    @ObservationIgnored private var youEntity = Entity()

    /// The sphere's radius and the camera, so the glass drawn on screen matches the 3D bounds.
    /// Half the cube's side, and how round its edges are.
    private let half: Float = 0.21
    private let corner: Float = 0.06
    private var radius: Float { half }
    private let distance: Float = 1.25
    private let fov: Float = 40
    private static let gravity: Float = 9.8

    private let solidG = CollisionGroup(rawValue: 1 << 1)
    private let gasG = CollisionGroup(rawValue: 1 << 2)   // water
    private let pebbleG = CollisionGroup(rawValue: 1 << 4)
    private let youG = CollisionGroup(rawValue: 1 << 3)

    func screenRadius(in size: CGSize) -> CGFloat {
        let tanHalf = tan(fov / 2 * .pi / 180)
        let k = tan(asin(radius / distance)) / tanHalf
        return CGFloat(k) * size.height / 2
    }

    func build(into content: RealityViewCameraContent, air: AirCubeAir, felt: MenusFelt) {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = fov
        camera.position = [0, 0, distance]
        camera.look(at: .zero, from: [0, 0, distance], relativeTo: nil)
        content.add(camera)
        for (dir, intensity) in [(SIMD3<Float>(-0.6, -1, -0.5), Float(2800)), (SIMD3<Float>(0.8, -0.2, 0.6), Float(1000))] {
            let light = DirectionalLight()
            light.light.intensity = intensity
            light.look(at: dir, from: .zero, relativeTo: nil)
            content.add(light)
        }
        var sim = PhysicsSimulationComponent()
        sim.gravity = [0, -Self.gravity, 0]
        root.components.set(sim)
        root.orientation = simd_quatf(angle: -0.55, axis: [0, 1, 0]) * simd_quatf(angle: 0.38, axis: [1, 0, 0])
        content.add(root)
        addGlass(tint: air.tempF.map(Self.tempColor) ?? UIColor(white: 0.85, alpha: 1))
        // The orb for you in the middle is off for now (April, Oct 30): it read wrong.

        addWater(humidity: air.humidity)
        var rng = SystemRandomNumberGenerator()
        func count(_ v: Double, per: Double, cap: Int) -> Int { min(cap, Int((v / per).rounded())) }
        func level(_ l: Int) -> String { ["none", "low", "moderate", "high"][max(0, min(3, l))] }
        add(.pebble, n: count(air.pm10, per: 1.5, cap: 30), color: UIColor(red: 0.78, green: 0.66, blue: 0.46, alpha: 1),
            info: Info(title: "PM10 · coarse particles", value: "\(Int(air.pm10.rounded())) µg/m³", detail: "Dust and grit. The heaviest here, they settle."), rng: &rng)
        add(.mote, n: count(air.pm25, per: 0.5, cap: 46), color: UIColor(red: 0.36, green: 0.42, blue: 0.55, alpha: 1),
            info: Info(title: "PM2.5 · fine particles", value: "\(Int(air.pm25.rounded())) µg/m³", detail: "Smoke and exhaust. Small enough to reach deep in the lungs; they hang and drift."), rng: &rng)
        add(.mote, n: count(air.no2, per: 1.0, cap: 24), color: UIColor(red: 0.72, green: 0.33, blue: 0.22, alpha: 1),
            info: Info(title: "NO₂ · nitrogen dioxide", value: "\(Int(air.no2.rounded())) ppb", detail: "A gas from traffic and burning, drawn as specks."), rng: &rng)
        add(.shard, n: count(air.ozone, per: 2.0, cap: 26), color: UIColor(red: 0.65, green: 0.36, blue: 0.89, alpha: 1),
            info: Info(title: "Ozone", value: "\(Int(air.ozone.rounded())) ppb", detail: "A gas that forms in sun and heat, drawn as shards. It barely falls."), rng: &rng)
        for (name, l, color) in [("Tree", air.tree, UIColor(red: 0.55, green: 0.75, blue: 0.35, alpha: 1)),
                                 ("Grass", air.grass, UIColor(red: 0.95, green: 0.76, blue: 0.19, alpha: 1)),
                                 ("Weed", air.weed, UIColor(red: 0.79, green: 0.59, blue: 0.23, alpha: 1))] where l > 0 {
            add(.dandelion, n: l * 4, color: color,
                info: Info(title: "\(name) pollen", value: level(l).capitalized, detail: "Light grains that ride the air, drawn as seeds. They float."), rng: &rng)
        }

        update = content.subscribe(to: SceneEvents.Update.self) { [weak self] (e: SceneEvents.Update) in
            MainActor.assumeIsolated { self?.tick(Float(e.deltaTime)) }
        }
    }

    // MARK: Pieces

    /// Clear glass, softly rounded: rounded rods with round corners for the edges, in the temperature's tint.
    /// No frost, no panes.
    private func addGlass(tint: UIColor) {
        let s = 2 * half
        // No face panes: RealityKit drew them opaque white over the contents. The rounded edges carry the cube.
        _ = s
        var edge = PhysicallyBasedMaterial()
        edge.baseColor = .init(tint: tint.blended(with: .white, 0.15))
        edge.roughness = 0.3
        edge.blending = .transparent(opacity: .init(floatLiteral: 0.85))
        let w: Float = 0.008, b = half - corner * 0.3
        for a in [-b, b] { for c in [-b, b] {
            for (pos, size) in [(SIMD3<Float>(0, a, c), SIMD3<Float>(2 * b, w, w)), (SIMD3<Float>(a, 0, c), SIMD3<Float>(w, 2 * b, w)), (SIMD3<Float>(a, c, 0), SIMD3<Float>(w, w, 2 * b))] {
                let e = ModelEntity(mesh: .generateBox(size: size, cornerRadius: w / 2), materials: [edge])
                e.position = pos
                root.addChild(e)
            }
        } }
        for x in [-b, b] { for y in [-b, b] { for z in [-b, b] {
            let c = ModelEntity(mesh: .generateSphere(radius: w * 0.75), materials: [edge])
            c.position = [x, y, z]
            root.addChild(c)
        } } }
    }

    private func addYou(_ felt: MenusFelt, label: String) {
        let r: Float = 0.075
        var m = PhysicallyBasedMaterial()
        switch felt {
        case .rescue: m.baseColor = .init(tint: UIColor(red: 0.91, green: 0.44, blue: 0.12, alpha: 1))
        case .standard: m.baseColor = .init(tint: UIColor(red: 0.61, green: 0.80, blue: 0.92, alpha: 1))
        case .nothing:
            m.baseColor = .init(tint: .white)
            m.blending = .transparent(opacity: .init(floatLiteral: 0.5))
        }
        m.roughness = 0.5
        let you = Entity()
        you.components.set(CollisionComponent(shapes: [.generateSphere(radius: r)], filter: .init(group: youG, mask: .all)))
        you.components.set(PhysicsBodyComponent(massProperties: .default, material: .generate(friction: 0.2, restitution: 0.6), mode: .static))
        let look = ModelEntity(mesh: Self.lowPoly(subdivisions: 1), materials: [m])
        look.scale = [r, r, r]
        you.addChild(look)
        root.addChild(you)
        youEntity = you
        youInfo = Info(title: "You", value: label, detail: felt == .nothing ? "No inhaler use at this time." : "What you felt, in the middle of the air you were in.")
    }

    /// The abstract particle kinds, by weight. Motion is kept slow: lots of air drag, small nudges.
    enum Kind {
        /// PM10: low-poly pebbles, heavy, they settle.
        case pebble
        /// PM2.5 and NO₂: fine motes, light, drifting, slow to settle.
        case mote
        /// Ozone: small sharp shards, nearly weightless.
        case shard
        /// Pollen: dandelion seeds, a core and a fan of fluff, all but weightless, wandering slowly.
        case dandelion
        /// Humidity: water, drops that pool at the bottom and slosh as you turn the sphere.
        case water

        var radius: ClosedRange<Float> {
            switch self { case .pebble: 0.013...0.019; case .mote: 0.006...0.009; case .shard: 0.008...0.012; case .dandelion: 0.028...0.034; case .water: 0.017...0.021 }
        }
        var mass: Float { switch self { case .pebble: 0.02; case .mote: 0.004; case .shard: 0.003; case .dandelion: 0.002; case .water: 0.012 } }
        var damping: Float { switch self { case .pebble: 3; case .mote: 3.5; case .shard: 4; case .dandelion: 5; case .water: 0.9 } }
        /// The share of gravity cancelled: 1 is weightless. Everything in the air floats, like dust or dandelion
        /// fluff in still air (owner, Oct 30); only the water falls.
        var lift: Float { switch self { case .water: 0; default: 1 } }
        /// How hard it wanders (m/s²): a slow, smooth drift that turns little by little, not a jitter.
        var jitter: Float { switch self { case .pebble: 0.04; case .mote: 0.07; case .shard: 0.05; case .dandelion: 0.08; case .water: 0 } }
    }

    private func add(_ kind: Kind, n: Int, color: UIColor, info: Info, rng: inout SystemRandomNumberGenerator) {
        guard n > 0 else { return }
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.roughness = 0.7
        if kind == .water { m.blending = .transparent(opacity: .init(floatLiteral: 0.55)); m.roughness = 0.05 }
        for _ in 0..<n {
            let r = Float.random(in: kind.radius, using: &rng)
            let body = ModelEntity()   // no mesh of its own: a physics body that can take forces
            // Somewhere inside the sphere, clear of you.
            // Anywhere in the air: inside the cube and above the water's surface.
            let room = half - r - 0.02
            var p = SIMD3<Float>.random(in: -room...room, using: &rng)
            for _ in 0..<40 where water != nil && simd_dot(p, surfaceUp) < surfaceH + r + 0.02 {
                p = SIMD3<Float>.random(in: -room...room, using: &rng)
            }
            body.position = p
            body.orientation = simd_quatf(angle: .random(in: 0...(2 * .pi), using: &rng), axis: simd_normalize(SIMD3<Float>.random(in: -1...1, using: &rng) + 0.001))
            // Fewer collisions: particles only meet you (and the glass); water drops also meet each other and the
            // pebbles, so they pool and the grit sinks into them.
            let group: CollisionGroup = kind == .water ? gasG : solidG
            let mask: CollisionGroup = kind == .water ? [gasG, youG, pebbleG] : kind == .pebble ? [youG, gasG] : [youG]
            body.components.set(CollisionComponent(shapes: [.generateSphere(radius: kind == .dandelion ? r * 0.6 : r)],
                                                   filter: .init(group: kind == .pebble ? pebbleG : group, mask: mask)))
            var phys = PhysicsBodyComponent(massProperties: .init(mass: kind.mass),
                                            material: .generate(friction: kind == .water ? 0 : 0.4, restitution: kind == .water ? 0.02 : 0.1), mode: .dynamic)
            phys.linearDamping = kind.damping
            phys.isAffectedByGravity = kind.lift < 1   // weightless in the air
            phys.angularDamping = kind == .dandelion ? 1.5 : 0.6
            body.components.set(phys)
            body.components.set(PhysicsMotionComponent())
            body.addChild(Self.look(kind, r: r, material: m))
            root.addChild(body)
            floaters.append(Floater(body: body, lift: kind.lift, jitter: kind.jitter, r: r, info: info))
            wander.append(simd_normalize(SIMD3<Float>.random(in: -1...1, using: &rng) + 0.001))
        }
    }

    /// The visible shape for a kind, at its size (the physics body stays unscaled).
    private static func look(_ kind: Kind, r: Float, material: PhysicallyBasedMaterial) -> Entity {
        switch kind {
        case .dandelion:
            // A seed: a small core, a short stalk, and a fan of fine spokes with soft tips, like a dandelion's pappus.
            let seed = Entity()
            let core = ModelEntity(mesh: lowPoly(subdivisions: 0), materials: [material])
            core.scale = .init(repeating: r * 0.16)
            core.position = [0, -r * 0.55, 0]
            seed.addChild(core)
            var fluff = PhysicallyBasedMaterial()
            fluff.baseColor = material.baseColor
            fluff.roughness = 1.0
            fluff.blending = .transparent(opacity: .init(floatLiteral: 0.75))
            let stalk = ModelEntity(mesh: .generateBox(size: [r * 0.04, r * 0.55, r * 0.04]), materials: [fluff])
            stalk.position = [0, -r * 0.27, 0]
            seed.addChild(stalk)
            let spokes = 14
            for i in 0..<spokes {
                let yaw = Float(i) / Float(spokes) * 2 * .pi
                let tilt = Float(i % 2 == 0 ? 0.55 : 0.9)
                let dir = simd_normalize(SIMD3<Float>(cos(yaw) * sin(tilt), cos(tilt), sin(yaw) * sin(tilt)))
                let spoke = ModelEntity(mesh: .generateBox(size: [r * 0.025, r * 0.8, r * 0.025]), materials: [fluff])
                spoke.orientation = simd_quatf(from: [0, 1, 0], to: dir)
                spoke.position = dir * r * 0.4
                seed.addChild(spoke)
                let tip = ModelEntity(mesh: lowPoly(subdivisions: 0), materials: [fluff])
                tip.scale = .init(repeating: r * 0.07)
                tip.position = dir * r * 0.82
                seed.addChild(tip)
            }
            return seed
        case .shard:
            let e = ModelEntity(mesh: lowPoly(subdivisions: 0), materials: [material])
            e.scale = [r * 0.45, r * 1.4, r * 0.45]   // a thin, sharp shard
            return e
        case .pebble:
            let e = ModelEntity(mesh: lowPoly(subdivisions: 0), materials: [material])
            e.scale = [r, r * 0.75, r * 0.9]
            return e
        case .mote:
            let e = ModelEntity(mesh: lowPoly(subdivisions: 0), materials: [material])
            e.scale = .init(repeating: r)
            return e
        case .water:
            let e = ModelEntity(mesh: lowPoly(subdivisions: 1), materials: [material])
            e.scale = .init(repeating: r * 1.15)   // a little larger than its body, so drops merge into a pool
            return e
        }
    }

    // MARK: Water

    /// Humidity as a body of water: more humid, fuller (about 5% of the cube when dry, 45% at 100%).
    private func addWater(humidity: Double) {
        guard humidity > 0 else { return }
        waterFill = Float(min(0.45, max(0.05, humidity / 100 * 0.45)))
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 0.36, green: 0.64, blue: 0.93, alpha: 1))
        m.roughness = 0.04
        m.specular = 1.0
        m.blending = .transparent(opacity: .init(floatLiteral: 0.42))
        let w = ModelEntity()
        w.model = ModelComponent(mesh: .generateBox(size: 0.001), materials: [m])
        root.addChild(w)
        water = w
        waterInfo = Info(title: "Humidity", value: "\(Int(humidity.rounded()))%", detail: "Water in the air, drawn as water. More humid, fuller.")
        surfaceUp = -gravityInCube() / Self.gravity
        updateWater(target: surfaceUp, dt: 0)
    }

    /// The surface leans toward level on a spring, so it lags and wobbles as the cube turns, then settles.
    private func updateWater(target: SIMD3<Float>, dt: Float) {
        guard let water else { return }
        if dt > 0 {
            surfaceVel += (target - surfaceUp) * 70 * dt - surfaceVel * 5 * dt
            surfaceUp = simd_normalize(surfaceUp + surfaceVel * dt)
        }
        guard simd_length(surfaceUp - drawnUp) > 0.0015 else { return }
        drawnUp = surfaceUp
        let box = half - 0.022   // just inside the glass
        surfaceH = Self.level(for: waterFill, n: surfaceUp, half: box)
        let faces = Self.clippedBox(half: box, n: surfaceUp, h: surfaceH)
        if let mesh = Self.mesh(faces) { water.model?.mesh = mesh }
    }

    /// The faces of a cube (half-side `half`) cut by the plane p·n = h, keeping p·n ≤ h: each face clipped, plus the
    /// cap where the cut is. Outward winding.
    static func clippedBox(half b: Float, n: SIMD3<Float>, h: Float) -> [[SIMD3<Float>]] {
        var faces: [[SIMD3<Float>]] = []
        var cut: [SIMD3<Float>] = []
        for axis in 0..<3 { for sign: Float in [-1, 1] {
            let u = (axis + 1) % 3, v = (axis + 2) % 3
            var quad: [SIMD3<Float>] = []
            for (a, c) in [(-b, -b), (b, -b), (b, b), (-b, b)] {
                var p = SIMD3<Float>(repeating: 0); p[axis] = sign * b; p[u] = a; p[v] = c; quad.append(p)
            }
            var outward = SIMD3<Float>(repeating: 0); outward[axis] = sign
            if simd_dot(simd_cross(quad[1] - quad[0], quad[2] - quad[0]), outward) < 0 { quad.reverse() }
            // Sutherland–Hodgman against the plane.
            var out: [SIMD3<Float>] = []
            for i in 0..<quad.count {
                let a = quad[i], c = quad[(i + 1) % quad.count]
                let da = simd_dot(a, n) - h, dc = simd_dot(c, n) - h
                if da <= 0 { out.append(a) }
                if (da < 0 && dc > 0) || (da > 0 && dc < 0) {
                    let p = a + (c - a) * (da / (da - dc)); out.append(p); cut.append(p)
                }
            }
            if out.count >= 3 { faces.append(out) }
        } }
        // The cap: the cut points, in order around the surface's normal.
        var cap: [SIMD3<Float>] = []
        for p in cut where !cap.contains(where: { simd_distance($0, p) < 1e-5 }) { cap.append(p) }
        if cap.count >= 3 {
            let c = cap.reduce(.zero, +) / Float(cap.count)
            let e1 = simd_normalize(simd_cross(n, abs(n.x) < 0.9 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)))
            let e2 = simd_cross(n, e1)
            cap.sort { atan2(simd_dot($0 - c, e2), simd_dot($0 - c, e1)) < atan2(simd_dot($1 - c, e2), simd_dot($1 - c, e1)) }
            if simd_dot(simd_cross(cap[1] - cap[0], cap[2] - cap[0]), n) < 0 { cap.reverse() }
            faces.append(cap)
        }
        return faces
    }

    static func volume(_ faces: [[SIMD3<Float>]]) -> Float {
        var v: Float = 0
        for f in faces where f.count >= 3 { for i in 1..<(f.count - 1) { v += simd_dot(f[0], simd_cross(f[i], f[i + 1])) / 6 } }
        return v
    }

    /// The height of the surface along n that holds `fill` of the cube.
    static func level(for fill: Float, n: SIMD3<Float>, half b: Float) -> Float {
        let target = fill * pow(2 * b, 3)
        let reach = b * (abs(n.x) + abs(n.y) + abs(n.z))
        var lo = -reach, hi = reach
        for _ in 0..<22 {
            let mid = (lo + hi) / 2
            if volume(clippedBox(half: b, n: n, h: mid)) < target { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    /// Flat-shaded mesh for the water's faces.
    static func mesh(_ faces: [[SIMD3<Float>]]) -> MeshResource? {
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], indices: [UInt32] = []
        for f in faces where f.count >= 3 {
            let nrm = simd_normalize(simd_cross(f[1] - f[0], f[2] - f[0]))
            for i in 1..<(f.count - 1) {
                for p in [f[0], f[i], f[i + 1]] { positions.append(p); normals.append(nrm); indices.append(UInt32(indices.count)) }
            }
        }
        guard !positions.isEmpty else { return nil }
        var d = MeshDescriptor(name: "water")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [d])
    }

    // MARK: Motion

    private func tick(_ dt: Float) {
        if !dragging, simd_length(spin) > 0.01 {
            rotate(by: spin * dt)
            spin *= max(0, 1 - 2.2 * dt)
        }
        let up = -gravityInCube() / Self.gravity
        updateWater(target: up, dt: dt)
        guard wander.count == floaters.count else { return }
        for (i, f) in floaters.enumerated() {
            // The glass: a rounded box. Past it, back to the inside surface, and the outward part of the velocity
            // comes back softly.
            let pos = f.body.position
            let inner = half - corner
            let q = SIMD3<Float>(abs(pos.x), abs(pos.y), abs(pos.z)) - SIMD3<Float>(repeating: inner)
            let o = simd_max(q, .zero), d = simd_length(o), limit = corner - f.r
            if d > limit, d > 0 {
                let sign = SIMD3<Float>(pos.x < 0 ? -1 : 1, pos.y < 0 ? -1 : 1, pos.z < 0 ? -1 : 1)
                let n = sign * o / d
                var fixed = pos
                for k in 0..<3 where q[k] > 0 { fixed[k] = sign[k] * (inner + o[k] / d * limit) }
                f.body.position = fixed
                if var motion = f.body.components[PhysicsMotionComponent.self] {
                    let out = simd_dot(motion.linearVelocity, n)
                    if out > 0 { motion.linearVelocity -= (1.0 + 0.15) * out * n }
                    f.body.components.set(motion)
                }
            }
            guard let mass = f.body.components[PhysicsBodyComponent.self]?.massProperties.mass else { continue }
            var force = SIMD3<Float>.zero   // weightless: no gravity to cancel (isAffectedByGravity is off)
            _ = up
            // Touching the water: it slows and rises back into the air (the particles live in the air, above it).
            if water != nil, simd_dot(f.body.position, surfaceUp) < surfaceH + f.r, var motion = f.body.components[PhysicsMotionComponent.self] {
                motion.linearVelocity *= max(0, 1 - 4 * dt)
                f.body.components.set(motion)
                force += surfaceUp * mass * 0.6
                wander[i] = simd_normalize(wander[i] + surfaceUp * 0.5)
            }
            if f.jitter > 0 {
                wander[i] = simd_normalize(wander[i] + SIMD3<Float>.random(in: -1...1) * 0.8 * dt)
                force += wander[i] * f.jitter * mass
            }
            f.body.addForce(force, relativeTo: root)
        }
        // Keep the annotation on its particle as it moves.
        if let i = selected, annotation != nil {
            let target = i < 0 ? youEntity : floaters[i].body
            annotation?.point = project(target.position(relativeTo: nil))
        }
    }

    func drag(_ translation: CGSize) {
        dragging = true
        let d = SIMD2<Float>(Float(translation.width - lastDrag.width), Float(translation.height - lastDrag.height))
        lastDrag = translation
        rotate(by: d * 0.008)
    }

    func release(velocity: CGSize) {
        dragging = false
        lastDrag = .zero
        spin = SIMD2<Float>(Float(velocity.width), Float(velocity.height)) * 0.008
    }

    private func rotate(by d: SIMD2<Float>) {
        root.orientation = simd_quatf(angle: d.x, axis: [0, 1, 0]) * simd_quatf(angle: d.y, axis: [1, 0, 0]) * root.orientation
        if var sim = root.components[PhysicsSimulationComponent.self] {
            sim.gravity = gravityInCube()
            root.components.set(sim)
        }
        for f in floaters { f.body.addForce([0, 0, 0], relativeTo: root) }
    }

    private func gravityInCube() -> SIMD3<Float> { root.orientation.inverse.act([0, -Self.gravity, 0]) }

    // MARK: Picking

    /// Where a point in the scene lands on screen (the camera looks straight down −z from `distance`).
    private func project(_ w: SIMD3<Float>) -> CGPoint {
        let tanHalf = tan(fov / 2 * .pi / 180)
        let depth = max(0.01, distance - w.z)
        let h = Float(viewSize.height) / 2
        return CGPoint(x: CGFloat(Float(viewSize.width) / 2 + w.x / (depth * tanHalf) * h),
                       y: CGFloat(h - w.y / (depth * tanHalf) * h))
    }

    /// The particle nearest a tap (within reach), or you; a tap on nothing clears the label.
    func select(at point: CGPoint) {
        var best: (Int, CGFloat)?
        for (i, f) in floaters.enumerated() {
            let p = project(f.body.position(relativeTo: nil))
            let d = hypot(p.x - point.x, p.y - point.y)
            if d < 28, d < (best?.1 ?? .infinity) { best = (i, d) }
        }
        if best == nil, water != nil {
            // Nothing small under the finger: if it's on the water, name the water.
            let surfaceWorld = root.convert(position: surfaceUp * surfaceH, to: nil)
            let sp = project(surfaceWorld)
            if point.y > sp.y - 10, abs(point.x - viewSize.width / 2) < screenRadius(in: viewSize) * 1.2 {
                selected = nil
                annotation = Annotation(title: waterInfo.title, value: waterInfo.value, detail: waterInfo.detail, point: point)
                UISelectionFeedbackGenerator().selectionChanged()
                return
            }
        }
        guard let (i, _) = best else { selected = nil; annotation = nil; return }
        selected = i
        let info = i < 0 ? youInfo : floaters[i].info
        annotation = Annotation(title: info.title, value: info.value, detail: info.detail,
                                point: project((i < 0 ? youEntity : floaters[i].body).position(relativeTo: nil)))
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func summary(_ air: AirCubeAir) -> String {
        var parts: [String] = []
        if air.pm25 > 0 { parts.append("PM2.5 \(Int(air.pm25)) µg/m³") }
        if air.pm10 > 0 { parts.append("PM10 \(Int(air.pm10)) µg/m³") }
        if air.ozone > 0 { parts.append("ozone \(Int(air.ozone)) ppb") }
        if air.tree + air.grass + air.weed > 0 { parts.append("pollen") }
        if air.humidity > 0 { parts.append("humidity \(Int(air.humidity))%") }
        return parts.isEmpty ? "No readings" : parts.joined(separator: ", ")
    }

    // MARK: Mesh and colour

    /// A low-poly sphere (icosahedron, optionally subdivided once), flat shaded: each face has its own normal.
    private static var meshCache: [Int: MeshResource] = [:]
    static func lowPoly(subdivisions: Int) -> MeshResource {
        if let m = meshCache[subdivisions] { return m }
        let t: Float = (1 + 5.0.squareRoot().float) / 2
        var v: [SIMD3<Float>] = [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
                                 [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]].map { simd_normalize($0) }
        var f: [(Int, Int, Int)] = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
                                    (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
        for _ in 0..<subdivisions {
            var next: [(Int, Int, Int)] = []
            var mids: [Int: Int] = [:]
            func mid(_ a: Int, _ b: Int) -> Int {
                let key = min(a, b) * 1000 + max(a, b)
                if let i = mids[key] { return i }
                v.append(simd_normalize((v[a] + v[b]) / 2)); mids[key] = v.count - 1; return v.count - 1
            }
            for (a, b, c) in f { let ab = mid(a, b), bc = mid(b, c), ca = mid(c, a); next += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)] }
            f = next
        }
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], indices: [UInt32] = []
        for (a, b, c) in f {
            let n = simd_normalize(simd_cross(v[b] - v[a], v[c] - v[a]))
            for i in [a, b, c] { positions.append(v[i]); normals.append(n); indices.append(UInt32(indices.count)) }
        }
        var d = MeshDescriptor(name: "lowpoly\(subdivisions)")
        d.positions = MeshBuffers.Positions(positions)
        d.normals = MeshBuffers.Normals(normals)
        d.primitives = .triangles(indices)
        let mesh = (try? MeshResource.generate(from: [d])) ?? .generateSphere(radius: 1)
        meshCache[subdivisions] = mesh
        return mesh
    }

    static func tempColor(_ t: Double) -> UIColor {
        let stops: [(Double, (CGFloat, CGFloat, CGFloat))] = [(10, (62, 100, 200)), (35, (127, 178, 229)), (55, (207, 230, 200)),
                                                             (72, (246, 211, 107)), (85, (242, 154, 74)), (98, (217, 87, 59))]
        let x = min(98, max(10, t))
        for i in 1..<stops.count where x <= stops[i].0 {
            let (t0, c0) = stops[i - 1], (t1, c1) = stops[i], k = CGFloat((x - t0) / (t1 - t0))
            return UIColor(red: (c0.0 + (c1.0 - c0.0) * k) / 255, green: (c0.1 + (c1.1 - c0.1) * k) / 255, blue: (c0.2 + (c1.2 - c0.2) * k) / 255, alpha: 1)
        }
        return .gray
    }
}

private extension Double { var float: Float { Float(self) } }

private extension UIColor {
    func blended(with other: UIColor, _ t: CGFloat) -> UIColor {
        var (r1, g1, b1, a1, r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0, 0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1); other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
    }
}
