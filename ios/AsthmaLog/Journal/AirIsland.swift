import Combine
import RealityKit
import SwiftUI

/// Menus look: the air outside as a small low-poly island you can spin (owner, Nov 6: "low poly 3D, smooth
/// animation, satisfying to play with, calming ambience"). Each part is one thing in the outdoor air:
/// the cloud is pollution (white → pink → coral), the sun's light is temperature, the drifting motes are tree
/// pollen, the grass's seed heads are grass pollen, the blooms are weed pollen, the mist is humidity.
/// Drag sideways to spin it (it keeps turning and slows down); tap a part to name it and give it a nudge.
struct AirIsland: View {
    let air: AirCubeAir

    @State private var world = IslandWorld.shared
    @State private var holder = Entity()
    @State private var pokes = 0
    @State private var lastX: CGFloat = 0

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            // Each view its own camera: a camera handed over with the scene later isn't picked up.
            content.add(IslandWorld.makeCamera())
            content.add(holder)
            world.attach(content, holder: holder)
        }
        .onAppear { world.setAir(air); world.appeared(holder) }
        .onDisappear { world.disappeared(holder) }
        .onChange(of: air) { _, a in world.setAir(a) }
        .gesture(
            SpatialTapGesture().targetedToAnyEntity().onEnded { v in
                if world.poke(v.entity) { pokes += 1 }
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in
                    if !world.dragging { lastX = 0 }
                    world.spin(by: Float(v.translation.width - lastX))
                    lastX = v.translation.width
                }
                .onEnded { v in world.release(velocity: Float(v.velocity.width)) }
        )
        .overlay(alignment: .top) {
            if let s = world.selected {
                label(s)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.smooth(duration: 0.3), value: world.selected)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: pokes)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Outdoor air island")
        .accessibilityValue(world.summary)
    }

    private func label(_ s: IslandWorld.Info) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color(uiColor: s.color)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(s.title).font(.subheadline.weight(.semibold))
                Text(s.detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

/// The island's scene, kept for the life of the app so it never rebuilds as you move between moments: new air
/// only moves its targets, and every part eases toward them.
@MainActor @Observable
final class IslandWorld {
    static let shared = IslandWorld()

    struct Info: Equatable {
        let title: String
        let detail: String
        let color: UIColor
    }

    private(set) var selected: Info?
    private(set) var summary = ""
    @ObservationIgnored private(set) var dragging = false

    // MARK: Scene

    @ObservationIgnored private let scene = Entity()
    @ObservationIgnored private let root = Entity()    // spins
    @ObservationIgnored private let body = Entity()    // bobs, bounces when poked
    @ObservationIgnored private var built = false
    @ObservationIgnored private var stopTick: (() -> Void)?
    @ObservationIgnored private var sunLight = DirectionalLight()
    @ObservationIgnored private var sunBall = ModelEntity()
    @ObservationIgnored private var tree = Entity()
    @ObservationIgnored private var cloud = Entity()
    @ObservationIgnored private var cloudPuffs: [ModelEntity] = []
    @ObservationIgnored private var blades: [Blade] = []
    @ObservationIgnored private var flowers: [Pop] = []
    @ObservationIgnored private var motes: [Mote] = []
    @ObservationIgnored private var fog: [Veil] = []
    @ObservationIgnored private var tileTop = ModelEntity()
    @ObservationIgnored private var appliedGrass: Float = -1
    private struct Veil { let e: ModelEntity; let angle: Float; let radius: Float; let y: Float; let speed: Float; let phase: Float }

    private struct Blade { let e: ModelEntity; let seed: Entity; let shade: Int; let phase: Float; let lean: SIMD2<Float> }
    private struct Pop { let e: Entity; var s: Float = 0; var v: Float = 0; let order: Float }
    private struct Mote { let e: ModelEntity; let phase: Float; let radius: Float; let speed: Float; let height: Float; let order: Float; var s: Float = 0 }

    // MARK: State

    /// What each part stands for now.
    private enum Part: String { case cloud, sun, tree, grass, blooms, mist, island }
    @ObservationIgnored private var infos: [Part: Info] = [:]
    /// Targets from the air (0…1) and where each part is on its way there.
    @ObservationIgnored private var target = Levels()
    @ObservationIgnored private var now = Levels()
    private struct Levels { var pollution: Float = 0; var warmth: Float = 0.5; var humidity: Float = 0; var tree: Float = 0; var grass: Float = 0; var weed: Float = 0 }

    @ObservationIgnored private var time: Float = 0
    @ObservationIgnored private var yaw: Float = -0.5
    @ObservationIgnored private var yawVelocity: Float = 0
    @ObservationIgnored private var idle: Float = 10
    /// A nudge per part: a damped spring kicked by a tap.
    @ObservationIgnored private var springs: [Part: (x: Float, v: Float)] = [:]
    @ObservationIgnored private var moteRush: Float = 0
    @ObservationIgnored private var hide: Task<Void, Never>?
    @ObservationIgnored private var appliedCloud: Float = -1
    @ObservationIgnored private var appliedWarmth: Float = -1

    // MARK: Attach

    /// The sky is rebuilt for each moment, so several island views can be alive for a moment (one fading in,
    /// one fading out). Each has its own holder; the scene lives in the newest one still on screen.
    @ObservationIgnored private var holders: [Entity] = []

    func attach(_ content: RealityViewCameraContent, holder: Entity) {
        if !built { build() }
        appeared(holder)
        stopTick?()
        let sub = content.subscribe(to: SceneEvents.Update.self) { [weak self] (e: SceneEvents.Update) in
            MainActor.assumeIsolated { self?.tick(Float(e.deltaTime)) }
        }
        stopTick = { sub.cancel() }
    }

    func appeared(_ holder: Entity) {
        holders.removeAll { $0 === holder }
        holders.append(holder)
        claim(holder)
    }

    func disappeared(_ holder: Entity) {
        holders.removeAll { $0 === holder }
        if let live = holders.last { claim(live) }
    }

    private func claim(_ holder: Entity) {
        guard scene.parent !== holder else { return }
        holder.addChild(scene)
        // Follow the scene into its new view, so the frame tick keeps running.
        if let s = holder.scene {
            stopTick?()
            let sub = s.subscribe(to: SceneEvents.Update.self) { [weak self] (e: SceneEvents.Update) in
                MainActor.assumeIsolated { self?.tick(Float(e.deltaTime)) }
            }
            stopTick = { sub.cancel() }
        }
    }

    // MARK: Air

    func setAir(_ a: AirCubeAir) {
        func share(_ v: Double, _ high: Double) -> Float { Float(min(1, max(0, v / high)).squareRoot()) }
        func level(_ n: Int) -> String { ["None reported", "Low", "Moderate", "High"][max(0, min(3, n))] }

        var dirt: [String] = []
        var worst: Float = 0
        if a.pm25 > 0 { dirt.append("PM2.5 \(Int(a.pm25.rounded())) µg/m³"); worst = max(worst, share(a.pm25, 35)) }
        if a.pm10 > 0 { dirt.append("PM10 \(Int(a.pm10.rounded())) µg/m³"); worst = max(worst, share(a.pm10, 150)) }
        if a.ozone > 0 { dirt.append("Ozone \(Int(a.ozone.rounded())) ppb"); worst = max(worst, share(a.ozone, 70)) }
        if a.no2 > 0 { dirt.append("NO₂ \(Int(a.no2.rounded())) ppb"); worst = max(worst, share(a.no2, 100)) }
        target.pollution = worst

        let warmth: Float = a.tempF.map { Float(min(1, max(0, ($0 - 35) / 60))) } ?? 0.5
        target.warmth = warmth
        let humid: Float = a.humidity > 0 ? Float(min(1, max(0, (a.humidity - 30) / 60))) : 0
        target.humidity = humid
        target.tree = Float(a.tree) / 3
        target.grass = Float(a.grass) / 3
        target.weed = Float(a.weed) / 3

        let tempWord: String = a.tempF.map { t in
            let word = t < 45 ? "cold" : t < 60 ? "cool" : t < 75 ? "mild" : t < 85 ? "warm" : "hot"
            return "\(Int(t.rounded()))°F, \(word)"
        } ?? "No reading"
        infos = [
            .cloud: Info(title: "Cloud · pollution", detail: dirt.isEmpty ? "No reading" : dirt.joined(separator: " · "), color: Self.cloudColor(worst)),
            .sun: Info(title: "Sunlight · temperature", detail: tempWord, color: Self.sunColor(warmth)),
            .tree: Info(title: "Drifting pollen · trees", detail: "Tree pollen: \(level(a.tree).lowercased())", color: Self.pollenYellow),
            .grass: Info(title: "Grass · grass pollen", detail: "Grass pollen: \(level(a.grass).lowercased())", color: Self.grassGreen),
            .blooms: Info(title: "Blooms · weed pollen", detail: "Weed pollen: \(level(a.weed).lowercased())", color: Self.bloomPink),
            .mist: Info(title: "Fog · humidity", detail: a.humidity > 0 ? "\(Int(a.humidity.rounded()))% humidity" : "No reading", color: .white),
            .island: Info(title: "Fog · humidity",
                          detail: a.humidity > 0 ? "\(Int(a.humidity.rounded()))% humidity, foggier when it's muggy" : "No reading",
                          color: Self.hex(0xD4E6FF)),
        ]
        summary = [Part.cloud, .sun, .tree, .grass, .blooms, .mist].compactMap { infos[$0] }
            .map { "\($0.title): \($0.detail)" }.joined(separator: ". ")
        if let s = selected, let fresh = infos.values.first(where: { $0.title == s.title }) { selected = fresh }
    }

    // MARK: Touch

    var isDragging: Bool { dragging }

    func spin(by dx: Float) {
        dragging = true
        idle = 0
        yaw += dx * 0.011
        yawVelocity = 0
    }

    func release(velocity: Float) {
        dragging = false
        idle = 0
        yawVelocity = max(-9, min(9, velocity * 0.011))
    }

    /// A tap on a part: name it, and give it a nudge.
    func poke(_ entity: Entity) -> Bool {
        var e: Entity? = entity
        while let x = e, !x.name.hasPrefix("part:") { e = x.parent }
        guard let name = e?.name.dropFirst(5), let part = Part(rawValue: String(name)) else { return false }
        var s = springs[part] ?? (0, 0)
        s.v += 7
        springs[part] = s
        if part == .tree { moteRush = 1 }
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

    private func tick(_ dt: Float) {
        let dt = min(dt, 1 / 20)
        time += dt
        idle += dt

        // Ease toward the air.
        let k = 1 - exp(-dt * 2.2)
        now.pollution += (target.pollution - now.pollution) * k
        now.warmth += (target.warmth - now.warmth) * k
        now.humidity += (target.humidity - now.humidity) * k
        now.tree += (target.tree - now.tree) * k
        now.grass += (target.grass - now.grass) * k
        now.weed += (target.weed - now.weed) * k

        // Springs.
        for (p, s) in springs {
            let a = -170 * s.x - 9 * s.v
            let v = s.v + a * dt
            springs[p] = (s.x + v * dt, v)
        }
        func spring(_ p: Part) -> Float { springs[p]?.x ?? 0 }

        // Spin: coasts and slows; after a while alone, a slow drift of its own.
        if !dragging {
            yawVelocity *= exp(-dt * 1.6)
            if idle > 3 { yawVelocity += (0.12 - yawVelocity) * (1 - exp(-dt * 0.5)) }
            yaw += yawVelocity * dt
        }
        root.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])

        // The island floats, and bounces when poked.
        let bounce = spring(.island)
        body.position.y = sin(time * 0.8) * 0.03 + bounce * 0.05
        body.scale = [1 + bounce * 0.03, 1 - bounce * 0.04, 1 + bounce * 0.03]

        // Tree: squash and wobble.
        let t = spring(.tree)
        tree.scale = [1 + t * 0.06, 1 - t * 0.07, 1 + t * 0.06]
        tree.orientation = simd_quatf(angle: t * 0.06 + sin(time * 0.9) * 0.012, axis: [0, 0, 1])

        // Cloud: bobs, drifts, puffs when poked; its colour is the pollution.
        let c = spring(.cloud)
        // Floaty: a slow drift and rise, a gentle tilt, and each puff breathing on its own.
        cloud.position = [0.55 + sin(time * 0.11) * 0.16, 1.5 + sin(time * 0.37) * 0.07 + sin(time * 0.9) * 0.012, -0.15 + cos(time * 0.08) * 0.1]
        cloud.orientation = simd_quatf(angle: sin(time * 0.23) * 0.05, axis: [0, 0, 1]) * simd_quatf(angle: time * 0.05, axis: [0, 1, 0])
        cloud.scale = SIMD3<Float>(repeating: 1 + c * 0.1)
        for (i, puff) in cloudPuffs.enumerated() {
            let b = 1 + sin(time * 0.6 + Float(i) * 1.3) * 0.03
            puff.scale = [b, b * 0.97, b]
        }
        if abs(now.pollution - appliedCloud) > 0.003 {
            appliedCloud = now.pollution
            let m = Self.cloudMaterial(Self.cloudColor(now.pollution))
            for p in cloudPuffs { p.model?.materials = [m] }
        }

        // Sun: its colour and the light's are the temperature.
        let s = spring(.sun)
        sunBall.scale = SIMD3<Float>(repeating: 1 + s * 0.3 + sin(time * 1.4) * 0.03)
        if abs(now.warmth - appliedWarmth) > 0.003 {
            appliedWarmth = now.warmth
            sunLight.light.color = Self.lightColor(now.warmth)
            sunBall.model?.materials = [Self.sunMaterial(Self.sunColor(now.warmth), opacity: 1)]
        }

        // Grass: sways in a breeze; taller, with seed heads, when there's grass pollen.
        let g = spring(.grass)
        let height = 0.75 + now.grass * 0.6
        for b in blades {
            let droop = max(0, now.warmth - 0.6) * 0.6   // heat: blades flop a little
            let sway = sin(time * (1.1 + now.warmth * 0.6) + b.phase) * (0.1 + g * 0.35) + b.lean.x * (1 + droop * 2)
            let sway2 = cos(time * 0.9 + b.phase * 1.7) * 0.05 + b.lean.y
            b.e.orientation = simd_quatf(angle: sway, axis: [0, 0, 1]) * simd_quatf(angle: sway2, axis: [1, 0, 0])
            b.e.scale = [1, height, 1]
            b.seed.scale = SIMD3<Float>(repeating: now.grass) * [1, 1 / height, 1]
        }
        // Temperature in the grass: cool sage when cold, fresh green when mild, dry straw when hot.
        if abs(now.warmth - appliedGrass) > 0.02 {
            appliedGrass = now.warmth
            let mats = (0..<3).map { Self.matte(Self.grassColor(now.warmth, shade: $0)) }
            for b in blades { b.e.model?.materials = [mats[b.shade]] }
            tileTop.model?.materials = [Self.matte(Self.groundColor(now.warmth))]
        }

        // Blooms: pop open one by one with a little overshoot.
        let w = spring(.blooms)
        for i in flowers.indices {
            let want: Float = flowers[i].order < now.weed - 0.001 ? 1 : 0
            let a = -120 * (flowers[i].s - want) - 8 * flowers[i].v
            flowers[i].v += a * dt
            flowers[i].s += flowers[i].v * dt
            let sc = max(0, flowers[i].s) * (1 + w * 0.25)
            flowers[i].e.scale = SIMD3<Float>(repeating: sc)
            flowers[i].e.orientation = simd_quatf(angle: sin(time * 1.1 + Float(i)) * 0.08 + w * 0.2 * sin(Float(i)), axis: [0, 0, 1])
        }

        // Tree pollen: motes drifting round the canopy; a tap on the tree sends them swirling.
        moteRush *= exp(-dt * 0.9)
        for i in motes.indices {
            let m = motes[i]
            let want: Float = m.order < now.tree - 0.001 ? 1 : 0
            motes[i].s += (want - m.s) * (1 - exp(-dt * 3))
            let a = m.phase + time * m.speed * (1 + moteRush * 3)
            let r = m.radius * (1 + moteRush * 0.35)
            m.e.position = [cos(a) * r, m.height + sin(time * 0.7 + m.phase * 2) * 0.12, sin(a) * r]
            m.e.scale = SIMD3<Float>(repeating: motes[i].s * (0.8 + 0.2 * sin(time * 2 + m.phase)))
        }

        // Fog: soft veils drifting slowly round the tile, thicker the more humid it is; a tap stirs them.
        let stir = spring(.island)
        for v in fog {
            let a = v.angle + time * v.speed * (1 + abs(stir) * 4)
            v.e.position = [cos(a) * v.radius, v.y + sin(time * 0.3 + v.phase) * 0.05, sin(a) * v.radius]
            let breathe = 0.75 + 0.25 * sin(time * 0.25 + v.phase)
            v.e.components.set(OpacityComponent(opacity: min(0.85, now.humidity * 0.8 * breathe)))
        }
    }

    // MARK: Build

    /// A soft round puff for the steam: white, fading to nothing at its edge.
    static func puff() -> TextureResource? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.4).cgColor,
                          UIColor.white.withAlphaComponent(0.1).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.3, 0.65, 1]) else { return }
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0, endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
        guard let cg = image.cgImage else { return nil }
        return try? TextureResource(image: cg, options: .init(semantic: .color))
    }

    static func makeCamera() -> PerspectiveCamera {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 30
        camera.look(at: [0, 0.5, 0], from: [0, 1.35, 6.0], relativeTo: nil)
        return camera
    }

    private func build() {
        built = true
        var rng = IslandRNG(seed: 7)


        sunLight.light.intensity = 2200
        sunLight.light.color = Self.lightColor(0.5)
        sunLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 6, depthBias: 1.5)
        sunLight.look(at: [0, 0.3, 0], from: [-2.2, 4, 2.4], relativeTo: nil)
        scene.addChild(sunLight)
        let fill = DirectionalLight()
        fill.light.intensity = 1600
        fill.light.color = UIColor(red: 0.85, green: 0.9, blue: 1, alpha: 1)
        fill.look(at: [0, 0.3, 0], from: [2.5, 1.2, 3], relativeTo: nil)
        scene.addChild(fill)

        scene.addChild(root)
        root.addChild(body)

        // The sun: fixed in the sky (it doesn't turn with the island).
        sunBall = ModelEntity(mesh: LowPoly.blob(radius: 0.12, subdiv: 1, lump: 0.04, rng: &rng), materials: [Self.sunMaterial(Self.sunColor(0.5), opacity: 1)])

        sunBall.position = [-0.78, 1.32, -0.35]
        tappable(sunBall, .sun)
        scene.addChild(sunBall)

        // Ground (owner's reference, Nov 6: a low-poly diorama): a square tile of grass with darker sides.
        let island = Entity()
        let tile = ModelEntity(mesh: LowPoly.column(rings: [(0, 1.32), (-0.3, 1.32)], sides: 4, jitter: 0, rng: &rng),
                               materials: [Self.matte(Self.groundColor(0.5))])
        tileTop = tile
        tile.orientation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])
        let sides = ModelEntity(mesh: LowPoly.column(rings: [(-0.02, 1.322), (-0.3, 1.322)], sides: 4, jitter: 0, rng: &rng),
                                materials: [Self.matte(Self.hex(0x4F9446))])
        sides.orientation = tile.orientation
        island.addChild(tile)
        island.addChild(sides)
        // Lavender rocks, as in the reference.
        for (p, r) in [(SIMD3<Float>(-0.4, 0.02, -0.62), Float(0.08)), (SIMD3<Float>(0.7, 0.02, 0.15), 0.06), (SIMD3<Float>(0.15, 0.02, 0.7), 0.05),
                       (SIMD3<Float>(-0.72, 0.02, -0.1), 0.045)] {
            let rock = ModelEntity(mesh: LowPoly.blob(radius: r, subdiv: 0, lump: 0.18, squash: [1.3, 0.7, 1], rng: &rng),
                                   materials: [Self.matte(Self.hex(0xB9B0DE))])
            rock.position = p
            island.addChild(rock)
        }
        tappable(island, .island)
        body.addChild(island)

        // Tree: a brown trunk and a faceted lime canopy.
        tree = Entity()
        let bark = Self.matte(Self.hex(0x8A5A3C))
        tree.addChild(ModelEntity(mesh: LowPoly.column(rings: [(0.62, 0.035), (0, 0.06)], sides: 6, jitter: 0, rng: &rng), materials: [bark]))
        let branch = ModelEntity(mesh: LowPoly.column(rings: [(0.22, 0.012), (0, 0.025)], sides: 5, jitter: 0, rng: &rng), materials: [bark])
        branch.position = [0, 0.32, 0]
        branch.orientation = simd_quatf(angle: -0.7, axis: [0, 0, 1])
        tree.addChild(branch)
        for (p, r, c) in [(SIMD3<Float>(0, 0.88, 0), Float(0.34), UInt32(0xB5DE6A)), ([0.2, 0.68, 0.05], 0.2, 0xA6D460)] {
            let leaf = ModelEntity(mesh: LowPoly.blob(radius: r, subdiv: 1, lump: 0.12, squash: [1, 1.1, 1], rng: &rng),
                                   materials: [Self.matte(Self.hex(c))])
            leaf.position = p
            tree.addChild(leaf)
        }
        tree.position = [-0.1, 0, 0.05]
        tappable(tree, .tree)
        body.addChild(tree)

        // Pines: stacked cones round the edge.
        for (p, h, c) in [(SIMD3<Float>(0.62, 0, -0.55), Float(0.95), UInt32(0x6FB86A)), ([-0.65, 0, -0.5], 0.7, 0x8DCB5E), ([0.68, 0, 0.55], 0.55, 0x5FAE66)] {
            let pine = Entity()
            pine.addChild(ModelEntity(mesh: LowPoly.column(rings: [(0.16 * h, 0.022), (0, 0.035)], sides: 5, jitter: 0, rng: &rng), materials: [bark]))
            let green = Self.matte(Self.hex(c))
            for k in 0..<3 {
                let kf = Float(k)
                let r = (0.3 - kf * 0.07) * h
                let cone = ModelEntity(mesh: LowPoly.column(rings: [((0.42 - kf * 0.04) * h, 0), (0, r)], sides: 7, jitter: 0.06, rng: &rng),
                                       materials: [green])
                cone.position = [0, (0.14 + kf * 0.24) * h, 0]
                pine.addChild(cone)
            }
            pine.position = p
            tappable(pine, .tree)
            body.addChild(pine)
        }

        // Bushes: small faceted mounds.
        for (p, r, c) in [(SIMD3<Float>(-0.55, 0.06, 0.4), Float(0.13), UInt32(0x5FA85A)), ([0.35, 0.05, -0.75], 0.1, 0x6BB55E), ([-0.25, 0.05, 0.72], 0.09, 0x5FA85A)] {
            let bush = ModelEntity(mesh: LowPoly.blob(radius: r, subdiv: 1, lump: 0.1, squash: [1.2, 0.8, 1.1], rng: &rng),
                                   materials: [Self.matte(Self.hex(c))])
            bush.position = p
            tappable(bush, .grass)
            body.addChild(bush)
        }

        // Grass: tufts of blades round the island, each with a seed head at the tip.
        let grassGroup = Entity()
        let bladeMats = (0..<3).map { Self.matte(Self.grassColor(0.5, shade: $0)) }
        let seedMat = Self.paint(0xFFF3A0, 0xF5A83A)
        for _ in 0..<26 {
            let a = Float.random(in: 0..<(2 * .pi), using: &rng), r = Float.random(in: 0.25...0.88, using: &rng)
            let tuft = Entity()
            tuft.position = [cos(a) * r, 0, sin(a) * r]
            for _ in 0..<Int.random(in: 5...9, using: &rng) {
                let h = Float.random(in: 0.08...0.2, using: &rng)
                let shade = Int.random(in: 0..<3, using: &rng)
                let blade = ModelEntity(mesh: LowPoly.column(rings: [(h, 0), (0, 0.016)], sides: 3, jitter: 0, rng: &rng),
                                        materials: [bladeMats[shade]])
                blade.position = [Float.random(in: -0.06...0.06, using: &rng), 0, Float.random(in: -0.06...0.06, using: &rng)]
                let seed = ModelEntity(mesh: LowPoly.blob(radius: 0.016, subdiv: 0, lump: 0.1, squash: [0.8, 1.6, 0.8], rng: &rng), materials: [seedMat])
                seed.position = [0, h, 0]
                blade.addChild(seed)
                tuft.addChild(blade)
                blades.append(Blade(e: blade, seed: seed, shade: shade, phase: Float.random(in: 0...6, using: &rng),
                                    lean: [Float.random(in: -0.25...0.25, using: &rng), Float.random(in: -0.25...0.25, using: &rng)]))
            }
            tappable(tuft, .grass, pad: 0.06)
            grassGroup.addChild(tuft)
        }
        body.addChild(grassGroup)

        // Blooms: magenta flowers on short stems, opening as weed pollen rises.
        let stemMat = Self.paint(0x9EE07A, 0x3FAF5A)
        let petalMats = [Self.paint(0xFFD0E8, 0xF06BB0, 0x9B5BEA), Self.paint(0xFFE0A0, 0xFF7FB8), Self.paint(0xFFB0D8, 0xD9479A, 0x6A5BEA)]
        for i in 0..<15 {
            let a = Float.random(in: 0..<(2 * .pi), using: &rng), r = Float.random(in: 0.3...0.9, using: &rng)
            let flower = Entity()
            flower.position = [cos(a) * r, 0, sin(a) * r]
            flower.addChild(ModelEntity(mesh: LowPoly.column(rings: [(0.15, 0.008), (0, 0.012)], sides: 4, jitter: 0, rng: &rng), materials: [stemMat]))
            let head = ModelEntity(mesh: LowPoly.blob(radius: 0.05, subdiv: 0, lump: 0.1, rng: &rng), materials: [petalMats[i % 3]])
            head.position = [0, 0.16, 0]
            flower.addChild(head)
            flower.scale = .zero
            tappable(flower, .blooms, pad: 0.05)
            body.addChild(flower)
            flowers.append(Pop(e: flower, order: (Float(i) + 0.5) / 15))
        }

        // Tree pollen: little glowing motes round the canopy.
        let moteMat = UnlitMaterial(color: Self.pollenYellow)
        for i in 0..<30 {
            let mote = ModelEntity(mesh: LowPoly.blob(radius: 0.017, subdiv: 0, lump: 0.1, rng: &rng), materials: [moteMat])
            mote.scale = .zero
            tree.addChild(mote)
            motes.append(Mote(e: mote, phase: Float.random(in: 0...(2 * .pi), using: &rng), radius: Float.random(in: 0.45...0.8, using: &rng),
                              speed: Float.random(in: 0.12...0.35, using: &rng) * (Bool.random(using: &rng) ? 1 : -1),
                              height: Float.random(in: 0.6...1.35, using: &rng), order: (Float(i) + 0.5) / 30))
        }

        // Fog (owner, Nov 6: "like fog… floaty", not clumps): soft see-through veils that always face you and
        // drift slowly round the tile; thicker the more humid it is.
        var veil = UnlitMaterial()
        if let t = Self.puff() { veil.color = .init(tint: UIColor(red: 0.97, green: 0.98, blue: 1, alpha: 1), texture: .init(t)) }
        veil.blending = .transparent(opacity: .init(floatLiteral: 1))
        for i in 0..<10 {
            let w = Float.random(in: 1.0...1.6, using: &rng)
            let card = ModelEntity(mesh: .generatePlane(width: w, height: w * 0.38), materials: [veil])
            card.components.set(BillboardComponent())
            card.components.set(OpacityComponent(opacity: 0))
            body.addChild(card)
            fog.append(Veil(e: card, angle: Float(i) / 10 * 2 * .pi, radius: Float.random(in: 0.7...1.25, using: &rng),
                            y: Float.random(in: -0.05...0.3, using: &rng), speed: Float.random(in: 0.03...0.07, using: &rng),
                            phase: Float.random(in: 0...6, using: &rng)))
        }

        // Cloud: lumpy puffs, lit from within a little (like a cloud lamp).
        cloud = Entity()
        let puffs: [(SIMD3<Float>, Float)] = [([0, 0.02, 0], 0.24), ([-0.26, -0.03, 0.02], 0.19), ([0.27, -0.03, 0], 0.18), ([0.05, -0.05, 0.08], 0.2)]
        for (p, r) in puffs {
            let puff = ModelEntity(mesh: LowPoly.blob(radius: r, subdiv: 1, lump: 0.1, squash: [1.4, 0.65, 1.05], rng: &rng), materials: [Self.cloudMaterial(Self.cloudColor(0))])
            puff.position = p
            cloud.addChild(puff)
            cloudPuffs.append(puff)
        }
        tappable(cloud, .cloud)
        root.addChild(cloud)
    }

    /// Names a part and makes it tappable, with a box round what it draws.
    private func tappable(_ e: Entity, _ part: Part, pad: Float = 0) {
        e.name = "part:\(part.rawValue)"
        let b = e.visualBounds(relativeTo: e)
        e.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: b.extents + SIMD3<Float>(repeating: pad * 2)).offsetBy(translation: b.center)]))
        e.components.set(InputTargetComponent())
    }

    // MARK: Colours

    static let grassGreen = hex(0x4CC46A)
    static let pollenYellow = hex(0xF7DC4A)
    static let bloomPink = hex(0xF06BB0)

    static func hex(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    static func mix(_ a: UIColor, _ b: UIColor, _ t: Float) -> UIColor {
        var (r1, g1, b1, a1, r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0, 0, 0, 0, 0)
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(max(0, min(1, t)))
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
    }

    /// Clean air white; then pink; poor air coral.
    static func cloudColor(_ p: Float) -> UIColor {
        let white = UIColor(red: 0.98, green: 0.97, blue: 0.96, alpha: 1), pink = hex(0xF4C0D1), coral = hex(0xF0997B)
        return p < 0.5 ? mix(white, pink, p / 0.5) : mix(pink, coral, (p - 0.5) / 0.5)
    }

    /// The grass by temperature: cool sage (cold), fresh green (mild), dry straw (hot). Three shades for variety.
    static func grassColor(_ w: Float, shade: Int) -> UIColor {
        let cold = [hex(0x8DB8A0), hex(0x7AAA94), hex(0xA2C7B2)], mild = [hex(0x5FB04E), hex(0x7CC456), hex(0x4C9E48)]
        let hot = [hex(0xC8B85A), hex(0xB5A64C), hex(0xD8C870)]
        return w < 0.5 ? mix(cold[shade], mild[shade], w / 0.5) : mix(mild[shade], hot[shade], (w - 0.5) / 0.5)
    }

    static func groundColor(_ w: Float) -> UIColor {
        w < 0.5 ? mix(hex(0x8DB59E), hex(0x74B85C), w / 0.5) : mix(hex(0x74B85C), hex(0xB9B25E), (w - 0.5) / 0.5)
    }

    /// Cold: a pale blue sun; mild: soft butter; hot: deep gold.
    static func sunColor(_ w: Float) -> UIColor {
        let cold = hex(0xB5D4F4), mild = hex(0xFAE3A0), hot = hex(0xF5A65B)
        return w < 0.5 ? mix(cold, mild, w / 0.5) : mix(mild, hot, (w - 0.5) / 0.5)
    }

    static func lightColor(_ w: Float) -> UIColor {
        let cold = UIColor(red: 0.8, green: 0.88, blue: 1, alpha: 1), mild = UIColor(red: 1, green: 0.97, blue: 0.9, alpha: 1)
        let hot = UIColor(red: 1, green: 0.84, blue: 0.62, alpha: 1)
        return w < 0.5 ? mix(cold, mild, w / 0.5) : mix(mild, hot, (w - 0.5) / 0.5)
    }

    /// Frutiger Aero (owner, Nov 6): each shape a soft gradient, light at the top to its colour at the bottom,
    /// glossy and a little see-through.
    static func matte(_ c: UIColor, opacity: Float = 1) -> PhysicallyBasedMaterial {
        aero([mix(c, .white, 0.15), c], tint: .white, opacity: opacity)
    }

    /// A gradient that shifts hue top to bottom (owner's references, Nov 6: soft multi-colour gradients).
    static func paint(_ stops: UInt32..., opacity: Float = 1) -> PhysicallyBasedMaterial {
        aero(stops.map(hex), tint: .white, opacity: opacity)
    }

    static func aero(_ stops: [UIColor], tint: UIColor, opacity: Float) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        if let tex = gradient(stops) {
            m.baseColor = .init(tint: tint, texture: .init(tex))
        } else {
            m.baseColor = .init(tint: stops.first ?? .white)
        }
        // Flat and soft (owner, Nov 6: "flat soft… Tolan"): no shine, no reflections; the gradient glows a
        // little from within so the light only shapes it gently.
        m.roughness = .init(floatLiteral: 1)
        m.metallic = .init(floatLiteral: 0)
        m.specular = .init(floatLiteral: 0)
        if let tex = gradient(stops) {
            m.emissiveColor = .init(color: tint, texture: .init(tex))
            m.emissiveIntensity = 0.12
        }
        m.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return m
    }

    /// The sun: a warm (or cool) glow, white at its top.
    static func sunMaterial(_ c: UIColor, opacity: Float) -> PhysicallyBasedMaterial {
        var m = aero([.white, UIColor(white: 0.85, alpha: 1)], tint: c, opacity: opacity)
        m.emissiveColor = .init(color: c)
        m.emissiveIntensity = 0.9
        return m
    }

    /// A cloud-lamp puff: white at the top, the pollution's tint below, glowing softly.
    static func cloudMaterial(_ c: UIColor) -> PhysicallyBasedMaterial {
        var m = aero([.white, UIColor(white: 0.84, alpha: 1)], tint: c, opacity: 0.95)
        m.emissiveColor = .init(color: c)
        m.emissiveIntensity = 0.35
        return m
    }

    private static var textures: [String: TextureResource] = [:]

    /// A small top-to-bottom gradient image, made once per pair of colours.
    static func gradient(_ stops: [UIColor]) -> TextureResource? {
        let key = stops.map(\.description).joined(separator: "|")
        if let t = textures[key] { return t }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 64), format: format).image { ctx in
            let colors = stops.map(\.cgColor) as CFArray
            let locations = stops.indices.map { CGFloat($0) / CGFloat(max(stops.count - 1, 1)) }
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else { return }
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 64), options: [])
        }
        guard let cg = image.cgImage, let t = try? TextureResource(image: cg, options: .init(semantic: .color)) else { return nil }
        textures[key] = t
        return t
    }
}

/// Faceted meshes made in code: every triangle gets its own flat normal, so the shapes read as low poly.
enum LowPoly {
    static func mesh(_ p: [SIMD3<Float>], _ tris: [UInt32], smooth: Bool = false, inside: (SIMD3<Float>, Int) -> SIMD3<Float>) -> MeshResource {
        var pos: [SIMD3<Float>] = [], nor: [SIMD3<Float>] = [], idx: [UInt32] = []
        for i in stride(from: 0, to: tris.count, by: 3) {
            var a = p[Int(tris[i])], b = p[Int(tris[i + 1])], c = p[Int(tris[i + 2])]
            var n = simd_cross(b - a, c - a)
            guard simd_length(n) > 1e-9 else { continue }
            let centre = (a + b + c) / 3
            if simd_dot(n, centre - inside(centre, i / 3)) < 0 { swap(&b, &c); n = -n }
            n = simd_normalize(n)
            for v in [a, b, c] {
                idx.append(UInt32(pos.count))
                pos.append(v)
                // Smooth: shaded as a round shape (soft), though the outline stays low poly.
                let o = inside(v, i / 3)
                let capped = abs(o.x) < 1e-6 && abs(o.z) < 1e-6 && abs(o.y - v.y) > 0.5   // a column's cap
                nor.append(smooth && !capped ? simd_normalize(v - o) : n)
            }
        }
        // Texture runs bottom to top, so each shape carries its own soft vertical gradient.
        let lo = pos.map(\.y).min() ?? 0, hi = pos.map(\.y).max() ?? 1
        let uv = pos.map { SIMD2<Float>(0.5, ($0.y - lo) / max(hi - lo, 0.0001)) }
        var d = MeshDescriptor(name: "lowpoly")
        d.positions = MeshBuffers.Positions(pos)
        d.normals = MeshBuffers.Normals(nor)
        d.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        d.primitives = .triangles(idx)
        return (try? MeshResource.generate(from: [d])) ?? .generateSphere(radius: 0.01)
    }

    /// A lumpy faceted ball (an icosahedron, split `subdiv` times, each corner nudged in or out).
    static func blob(radius: Float, subdiv: Int, lump: Float, squash: SIMD3<Float> = [1, 1, 1], rng: inout IslandRNG) -> MeshResource {
        let t = Float((1 + 5.0.squareRoot()) / 2)
        var v: [SIMD3<Float>] = [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
                                 [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]].map { simd_normalize($0) }
        var f: [UInt32] = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
                           3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
        for _ in 0..<subdiv {
            var cache: [UInt64: UInt32] = [:]
            func mid(_ a: UInt32, _ b: UInt32) -> UInt32 {
                let key = UInt64(min(a, b)) << 32 | UInt64(max(a, b))
                if let m = cache[key] { return m }
                v.append(simd_normalize((v[Int(a)] + v[Int(b)]) / 2))
                let m = UInt32(v.count - 1)
                cache[key] = m
                return m
            }
            var next: [UInt32] = []
            for i in stride(from: 0, to: f.count, by: 3) {
                let a = f[i], b = f[i + 1], c = f[i + 2]
                let ab = mid(a, b), bc = mid(b, c), ca = mid(c, a)
                next += [a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]
            }
            f = next
        }
        let p = v.map { $0 * radius * (1 + Float.random(in: -lump...max(lump, 0.0001), using: &rng)) * squash }
        return mesh(p, f) { _, _ in .zero }
    }

    /// Rings from top to bottom (height, radius) round the y axis, capped at both ends. A radius of 0 is a point.
    static func column(rings: [(Float, Float)], sides: Int, jitter: Float, rng: inout IslandRNG) -> MeshResource {
        var p: [SIMD3<Float>] = []
        for (y, r) in rings {
            for s in 0..<sides {
                let a = Float(s) / Float(sides) * 2 * .pi
                let rr = r * (1 + (jitter > 0 ? Float.random(in: -jitter...jitter, using: &rng) : 0))
                p.append([cos(a) * rr, y, sin(a) * rr])
            }
        }
        var f: [UInt32] = []
        let n = UInt32(sides)
        for k in 0..<UInt32(rings.count - 1) {
            for s in 0..<n {
                let a = k * n + s, b = k * n + (s + 1) % n, c = (k + 1) * n + s, d = (k + 1) * n + (s + 1) % n
                f += [a, b, c, b, d, c]
            }
        }
        let sideTris = f.count / 3
        let top = UInt32(p.count)
        p.append([0, rings[0].0, 0])
        for s in 0..<n { f += [top, s, (s + 1) % n] }
        let last = UInt32(rings.count - 1) * n
        let bottom = UInt32(p.count)
        p.append([0, rings[rings.count - 1].0, 0])
        for s in 0..<n { f += [bottom, last + (s + 1) % n, last + s] }
        let topY = rings[0].0, bottomY = rings[rings.count - 1].0
        return mesh(p, f) { c, tri in
            if tri < sideTris { return [0, c.y, 0] }   // per vertex in smooth mode: straight out from the axis
            return tri < sideTris + sides ? [0, topY - 1, 0] : [0, bottomY + 1, 0]
        }
    }
}

/// A small fixed-seed random source, so the island looks the same every time.
struct IslandRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
