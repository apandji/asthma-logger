import CoreMotion
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
/// Tap it and you go into it: the camera flies into the cube, its edges grow past the screen and fade, and the
/// phone's own edges become the cube's walls. Inside, tap a particle and a fine line names it. Close flies back out.
/// One 3D view draws the cube, full screen, in a layer over the home (a second 3D view, for going inside, never
/// drew). On the page, `AirCubeSlot` holds its place: the layer's camera frames the cube in the slot, following it
/// as you scroll. Going in moves that camera into the cube.
struct AirCubeSlot: View {
    let air: AirCubeAir
    let felt: MenusFelt
    @Environment(\.airCubeWorld) private var world
    @Environment(\.airCubeSlot) private var report

    var body: some View {
        GeometryReader { g in
            let r = (world?.screenRadius(in: g.size) ?? 100)
            Ellipse().fill(Color.black.opacity(0.06)).frame(width: r * 1.7, height: r * 0.2).blur(radius: 12)
                .position(x: g.size.width / 2, y: g.size.height / 2 + r * 1.25)
                .opacity(Double(1 - (world?.zoom ?? 0)))
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { report?($0) }
        .onDisappear { report?(.zero) }
        .onChange(of: air, initial: true) { _, a in world?.setAir(a, felt: felt) }
        .onChange(of: felt) { _, f in world?.setAir(air, felt: f) }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { v in world?.drag(v.translation) }
                .onEnded { v in world?.release(velocity: v.velocity) }
        )
        .simultaneousGesture(TapGesture().onEnded { world?.zoomIn() })
        .overlay(alignment: .bottomTrailing) {
            Button { world?.zoomIn() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.footnote.weight(.semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.glass).buttonBorderShape(.circle)
            .padding(.trailing, 24).padding(.bottom, 8)
            .accessibilityLabel("Go into the cube")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("A glass cube of outdoor air")
        .accessibilityValue(world?.summary(air) ?? "")
    }
}

/// The layer over the home: the one 3D view, and, inside, the page fading to the cube, the title, the close button
/// and the annotation. Out on the home it's see-through to touches (the slot takes them) and fades as the slot
/// scrolls up under the timeline.
struct AirCubeLayer: View {
    let world: CubeWorld
    let slot: CGRect

    var body: some View {
        GeometryReader { g in
            let size = g.size
            let inside = world.zoom > 0.001
            // Fade as the slot slides up under the sticky timeline; gone when there's no slot (another scale or tab).
            let visible: Double = inside ? 1 : slot == .zero ? 0 : max(0, min(1, Double(slot.midY - 230) / 140))
            ZStack(alignment: .topTrailing) {
                Color(uiColor: .systemGroupedBackground).opacity(Double(world.zoom))
                    .allowsHitTesting(inside)
                RealityView { content in
                    content.camera = .virtual
                    world.attach(content)
                }
                .opacity(visible)
                .allowsHitTesting(false)
                // The 3D view keeps touches to itself, so a clear SwiftUI layer over it takes the taps and drags.
                if inside {
                    Color.clear.contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { v in world.drag(v.translation) }
                                .onEnded { v in world.release(velocity: v.velocity) }
                        )
                        .simultaneousGesture(SpatialTapGesture().onEnded { t in world.select(at: t.location) })
                }
                if world.zoom > 0.98, let a = world.annotation { annotation(a, size: size) }
                if inside {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inside the air").font(.title2.weight(.bold))
                        Text("Tilt your phone and the water follows. Drag to stir the air. Tap a particle to see what it is.").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("Outdoor air, regional readings. Drawn, not to scale.").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 20).padding(.top, 70).padding(.bottom, 34)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .opacity(Double(max(0, world.zoom - 0.6) / 0.4))
                    .allowsHitTesting(false)
                    Button { world.leave() } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 22, height: 22)
                    }
                    .buttonStyle(.glass).buttonBorderShape(.circle)
                    .padding(.trailing, 20).padding(.top, 62)
                    .opacity(Double(world.zoom))
                    .accessibilityLabel("Close")
                }
            }
            .onAppear { world.screen = size }
            .onChange(of: size) { _, s in world.screen = s }
            .onChange(of: slot, initial: true) { _, s in world.slot = s }
        }
        .ignoresSafeArea()
    }

    /// Scientific-figure annotation: a small ring on the particle, a hairline out to the side it isn't on, a short
    /// horizontal run, and the label set against it. No card.
    @ViewBuilder private func annotation(_ a: CubeWorld.Annotation, size: CGSize) -> some View {
        let p = a.point
        let right = p.x < size.width / 2
        let elbow = CGPoint(x: right ? size.width * 0.72 : size.width * 0.28, y: max(150, min(size.height - 140, p.y - 60)))
        let end = CGPoint(x: right ? size.width - 16 : 16, y: elbow.y)
        Path { path in path.move(to: p); path.addLine(to: elbow); path.addLine(to: end) }
            .stroke(Color.primary.opacity(0.8), lineWidth: 0.75)
            .allowsHitTesting(false)
        Circle().stroke(Color.primary, lineWidth: 0.75).frame(width: 18, height: 18).position(p).allowsHitTesting(false)
        Circle().fill(Color.primary).frame(width: 3, height: 3).position(elbow).allowsHitTesting(false)
        VStack(alignment: right ? .trailing : .leading, spacing: 2) {
            Text(a.title.uppercased()).font(.caption2.weight(.semibold)).tracking(0.8)
            if let v = a.value { Text(v).font(.title3.weight(.semibold).monospacedDigit()) }
            Text(a.detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(right ? .trailing : .leading)
        }
        .frame(width: 160, alignment: right ? .trailing : .leading)
        .position(x: right ? end.x - 80 : end.x + 80, y: elbow.y + 44)
        .allowsHitTesting(false)
    }
}

struct AirCubeWorldKey: EnvironmentKey { static let defaultValue: CubeWorld? = nil }
struct AirCubeSlotKey: EnvironmentKey { static let defaultValue: ((CGRect) -> Void)? = nil }
extension EnvironmentValues {
    var airCubeWorld: CubeWorld? {
        get { self[AirCubeWorldKey.self] }
        set { self[AirCubeWorldKey.self] = newValue }
    }
    var airCubeSlot: ((CGRect) -> Void)? {
        get { self[AirCubeSlotKey.self] }
        set { self[AirCubeSlotKey.self] = newValue }
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
        /// The one of its kind that stays inside, grown to tap size; the rest fade.
        let rep: Bool
    }

    var viewSize: CGSize = .zero
    private(set) var annotation: Annotation?
    /// 0 on the home, 1 inside: eased, for the page's fade.
    private(set) var zoom: Float = 0
    /// The scene is inside (on the overlay); the home's cube is empty until it comes back.
    private(set) var isAway = false
    @ObservationIgnored private var zoomT: Float = 0
    @ObservationIgnored private var zoomTarget: Float = 0
    @ObservationIgnored private var zoomDone: (() -> Void)?
    @ObservationIgnored private var inside = false
    @ObservationIgnored private var insideCamera: PerspectiveCamera?
    @ObservationIgnored private var insideSize: CGSize = .zero
    @ObservationIgnored private var camStart = SIMD3<Float>(0, 0, 1)
    @ObservationIgnored private var camEnd = SIMD3<Float>(0, 0.02, 0.06)
    @ObservationIgnored private var insideUpdate: EventSubscription?
    @ObservationIgnored private weak var homeScene: RealityKit.Scene?
    @ObservationIgnored private let glass = Entity()
    @ObservationIgnored private var built = false
    private let insideFov: Float = 58
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
    /// The walls' half-extents: the cube on the home, the screen's shape inside (they stretch between).
    @ObservationIgnored private var ext = SIMD3<Float>(repeating: 0.21)
    @ObservationIgnored private var drawnExt = SIMD3<Float>(repeating: 0)
    @ObservationIgnored private var startOrientation = simd_quatf(angle: 0, axis: [0, 1, 0])
    @ObservationIgnored private var tilt: Float = 0
    /// Inside, gravity is the phone's own (Core Motion's gravity vector, no permission needed); the drag's tilt
    /// stands in where there's no gyroscope (the simulator).
    @ObservationIgnored private let motion = CMMotionManager()
    /// Inside: the camera this far back, the walls on the screen's edges at the box's middle.
    private let fullZ: Float = 1.0
    private let corner: Float = 0.06
    private var radius: Float { half }
    private let distance: Float = 1.12
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

    /// Where the cube sits on the page (global), and the screen: the camera frames the cube in the slot.
    var slot: CGRect = .zero
    var screen: CGSize = .zero
    @ObservationIgnored private var camera: PerspectiveCamera?
    @ObservationIgnored private var airKey: String = ""

    /// The one 3D view: camera, light, the scene, and the frame tick.
    func attach(_ content: RealityViewCameraContent) {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = insideFov
        camera.position = [0, 0, 3]
        content.add(camera)
        self.camera = camera
        for (dir, intensity) in [(SIMD3<Float>(-0.6, -1, -0.5), Float(2800)), (SIMD3<Float>(0.8, -0.2, 0.6), Float(1000))] {
            let light = DirectionalLight()
            light.light.intensity = intensity
            light.look(at: dir, from: .zero, relativeTo: nil)
            content.add(light)
        }
        if !built {
            built = true
            var sim = PhysicsSimulationComponent()
            sim.gravity = [0, -Self.gravity, 0]
            root.components.set(sim)
            root.orientation = simd_quatf(angle: -0.55, axis: [0, 1, 0]) * simd_quatf(angle: 0.38, axis: [1, 0, 0])
        }
        content.add(root)
        update = content.subscribe(to: SceneEvents.Update.self) { [weak self] (e: SceneEvents.Update) in
            MainActor.assumeIsolated {
                self?.tick(Float(e.deltaTime))
                self?.frame(Float(e.deltaTime))
            }
        }
    }

    /// New air (another moment, or Now's readings arriving): refill the cube.
    func setAir(_ air: AirCubeAir, felt: MenusFelt) {
        let key = "\(air)\(felt)"
        guard key != airKey else { return }
        airKey = key
        for c in Array(root.children) { c.removeFromParent() }
        for c in Array(glass.children) { c.removeFromParent() }
        floaters = []
        wander = []
        water = nil
        drawnUp = .zero
        ext = SIMD3<Float>(repeating: half)
        annotation = nil
        selected = nil
        addGlass(tint: air.tempF.map(Self.tempColor) ?? UIColor(white: 0.85, alpha: 1))
        addWater(humidity: air.humidity)
        var rng = SystemRandomNumberGenerator()
        func count(_ v: Double, per: Double, cap: Int) -> Int { min(cap, Int((v / per).rounded())) }
        func level(_ l: Int) -> String { ["none", "low", "moderate", "high"][max(0, min(3, l))] }
        add(.pebble, n: count(air.pm10, per: 1.5, cap: 30), color: UIColor(red: 0.78, green: 0.66, blue: 0.46, alpha: 1),
            info: Info(title: "PM10 · coarse particles", value: "\(Int(air.pm10.rounded())) µg/m³", detail: "Dust and grit, the coarsest here."), rng: &rng)
        add(.mote, n: count(air.pm25, per: 0.5, cap: 46), color: UIColor(red: 0.36, green: 0.42, blue: 0.55, alpha: 1),
            info: Info(title: "PM2.5 · fine particles", value: "\(Int(air.pm25.rounded())) µg/m³", detail: "Smoke and exhaust. Small enough to reach deep in the lungs."), rng: &rng)
        add(.mote, n: count(air.no2, per: 1.0, cap: 24), color: UIColor(red: 0.72, green: 0.33, blue: 0.22, alpha: 1),
            info: Info(title: "NO₂ · nitrogen dioxide", value: "\(Int(air.no2.rounded())) ppb", detail: "A gas from traffic and burning, drawn as specks."), rng: &rng)
        add(.shard, n: count(air.ozone, per: 2.0, cap: 26), color: UIColor(red: 0.65, green: 0.36, blue: 0.89, alpha: 1),
            info: Info(title: "Ozone", value: "\(Int(air.ozone.rounded())) ppb", detail: "A gas that forms in sun and heat, drawn as shards."), rng: &rng)
        for (name, l, color) in [("Tree", air.tree, UIColor(red: 0.55, green: 0.75, blue: 0.35, alpha: 1)),
                                 ("Grass", air.grass, UIColor(red: 0.95, green: 0.76, blue: 0.19, alpha: 1)),
                                 ("Weed", air.weed, UIColor(red: 0.79, green: 0.59, blue: 0.23, alpha: 1))] where l > 0 {
            add(.dandelion, n: l * 4, color: color,
                info: Info(title: "\(name) pollen", value: level(l).capitalized, detail: "Light grains that ride the air, drawn as seeds."), rng: &rng)
        }
    }

    /// Where the camera sits to show the cube in the slot at the size the home gave it (as if a 40° camera at
    /// `distance` filled the slot's height), and over the slot's spot on screen.
    private var slotPose: SIMD3<Float> {
        guard slot.height > 1, screen.height > 1 else { return [0, 0, 3] }
        let tIn = tan(insideFov / 2 * .pi / 180), tHome = tan(fov / 2 * .pi / 180)
        let d0 = distance * Float(screen.height) * tHome / (Float(slot.height) * tIn)
        let dx = Float(slot.midX - screen.width / 2), dy = Float(slot.midY - screen.height / 2)
        let h = Float(screen.height) / 2
        return [-(dx / h) * d0 * tIn, (dy / h) * d0 * tIn, d0]
    }

    func zoomIn() {
        zoomTarget = 1
        if motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive {
            motion.deviceMotionUpdateInterval = 1 / 60
            motion.startDeviceMotionUpdates()
        }
    }

    func leave() {
        annotation = nil
        selected = nil
        zoomTarget = 0
    }

    /// Each frame: the camera on the slot, or on its way in or out (eased), the edges fading as they pass the screen.
    private func frame(_ dt: Float) {
        guard let camera else { return }
        if zoomT != zoomTarget {
            // Starting in: remember how the cube was turned, to turn it back on the way out.
            if zoomT == 0, zoomTarget == 1 { startOrientation = root.orientation; spin = .zero }
            let duration: Float = zoomTarget > zoomT ? 1.1 : 0.8
            let step = min(dt, 1 / 30) / duration   // a long first frame doesn't skip the zoom
            zoomT = zoomTarget > zoomT ? min(zoomTarget, zoomT + step) : max(zoomTarget, zoomT - step)
        }
        let e = zoomT * zoomT * (3 - 2 * zoomT)   // ease in and out
        camera.position = slotPose + (SIMD3<Float>(0, 0, fullZ) - slotPose) * e
        if zoomT > 0 || zoomTarget > 0 {
            // The cube turns to face you and its walls stretch out to the screen's edges: inside, the screen is the box.
            root.orientation = simd_slerp(startOrientation, simd_quatf(angle: 0, axis: [0, 1, 0]), e)
            let tanHalf = tan(insideFov / 2 * .pi / 180)
            let aspect = Float(max(1, screen.width) / max(1, screen.height))
            let fy = fullZ * tanHalf * 0.98, full = SIMD3<Float>(fy * aspect, fy, 0.07)   // shallow: walls sit on the screen's edges
            let cube = SIMD3<Float>(repeating: half)
            let next = cube + (full - cube) * e
            // The particles spread with the walls, so nothing jumps.
            let k = next / ext
            if simd_length(next - ext) > 1e-5 { for f in floaters { f.body.position *= k } }
            ext = next
            glass.scale = next / cube
            if var sim = root.components[PhysicsSimulationComponent.self] {
                // Inside, gravity is the phone's: tilt it and the water runs to the low side (the air floats).
                // Until fully in (or with no gyroscope), the screen's down, leaned by a drag.
                var g = root.orientation.inverse.act(SIMD3<Float>(sin(tilt), -cos(tilt), 0) * Self.gravity)
                if zoomT >= 1, let dm = motion.deviceMotion {
                    // Device axes (x right, y up, z out of the screen) are the box's axes inside.
                    g = SIMD3<Float>(Float(dm.gravity.x), Float(dm.gravity.y), Float(dm.gravity.z)) * Self.gravity
                }
                sim.gravity = g
                root.components.set(sim)
            }
            if zoomT == 0 {
                tilt = 0
                if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
            }
        }
        glass.components.set(OpacityComponent(opacity: max(0, 1 - e / 0.65)))
        if zoomT > 0 || zoomTarget > 0 || zoom > 0 {
            // Inside, one of each kind, big enough to tap (about 56 pt across); the crowd stays on the home.
            let tanHalf = tan(insideFov / 2 * .pi / 180)
            let tapRadius = 28 / Float(max(1, screen.height) / 2) * fullZ * tanHalf
            for f in floaters {
                if f.rep {
                    f.body.scale = SIMD3<Float>(repeating: 1 + e * (max(1, tapRadius / f.r) - 1))
                } else {
                    f.body.components.set(OpacityComponent(opacity: 1 - e))
                }
            }
        }
        if zoom != e { zoom = e }
        inside = e > 0.001
        if let i = selected, i < floaters.count, annotation != nil { annotation?.point = project(floaters[i].body.position(relativeTo: nil)) }
    }


    // MARK: Pieces

    /// The cube's edges as a halo: a fine grey line with a soft, light glow around it. Monochrome, quiet. No panes.
    private func addGlass(tint: UIColor) {
        _ = tint
        var core = UnlitMaterial(color: UIColor(white: 0.55, alpha: 1))
        core.blending = .transparent(opacity: .init(floatLiteral: 0.45))
        var halo = UnlitMaterial(color: .white)
        halo.blending = .transparent(opacity: .init(floatLiteral: 0.4))
        var glow = UnlitMaterial(color: .white)
        glow.blending = .transparent(opacity: .init(floatLiteral: 0.18))
        let b = half - corner * 0.3
        for a in [-b, b] { for c in [-b, b] {
            for (pos, axis) in [(SIMD3<Float>(0, a, c), 0), (SIMD3<Float>(a, 0, c), 1), (SIMD3<Float>(a, c, 0), 2)] {
                for (w, m) in [(Float(0.0022), core), (Float(0.008), halo), (Float(0.018), glow)] {
                    var size = SIMD3<Float>(repeating: w); size[axis] = 2 * b + w
                    let e = ModelEntity(mesh: .generateBox(size: size, cornerRadius: w / 2), materials: [m])
                    e.position = pos
                    glass.addChild(e)
                }
            }
        } }
        root.addChild(glass)
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
            // Half the size they were (owner, Oct 30): small enough to see between, and to move among inside.
            switch self { case .pebble: 0.0065...0.0095; case .mote: 0.003...0.0045; case .shard: 0.004...0.006; case .dandelion: 0.014...0.017; case .water: 0.0085...0.0105 }
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
        for index in 0..<n {
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
            floaters.append(Floater(body: body, lift: kind.lift, jitter: kind.jitter, r: r, info: info, rep: index == 0))
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
        guard simd_length(surfaceUp - drawnUp) > 0.0015 || simd_length(ext - drawnExt) > 0.0005 else { return }
        drawnUp = surfaceUp
        drawnExt = ext
        let box = ext - SIMD3<Float>(repeating: 0.022)   // just inside the walls
        surfaceH = Self.level(for: waterFill, n: surfaceUp, ext: box)
        let faces = Self.clippedBox(ext: box, n: surfaceUp, h: surfaceH)
        if let mesh = Self.mesh(faces) { water.model?.mesh = mesh }
    }

    /// The faces of a cube (half-side `half`) cut by the plane p·n = h, keeping p·n ≤ h: each face clipped, plus the
    /// cap where the cut is. Outward winding.
    static func clippedBox(ext e: SIMD3<Float>, n: SIMD3<Float>, h: Float) -> [[SIMD3<Float>]] {
        var faces: [[SIMD3<Float>]] = []
        var cut: [SIMD3<Float>] = []
        for axis in 0..<3 { for sign: Float in [-1, 1] {
            let u = (axis + 1) % 3, v = (axis + 2) % 3
            var quad: [SIMD3<Float>] = []
            for (a, c) in [(Float(-1), Float(-1)), (1, -1), (1, 1), (-1, 1)] {
                var p = SIMD3<Float>(repeating: 0); p[axis] = sign * e[axis]; p[u] = a * e[u]; p[v] = c * e[v]; quad.append(p)
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
    static func level(for fill: Float, n: SIMD3<Float>, ext b: SIMD3<Float>) -> Float {
        let target = fill * 8 * b.x * b.y * b.z
        let reach = simd_dot(simd_abs(n), b)
        var lo = -reach, hi = reach
        for _ in 0..<22 {
            let mid = (lo + hi) / 2
            if volume(clippedBox(ext: b, n: n, h: mid)) < target { lo = mid } else { hi = mid }
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
            let inner = ext - SIMD3<Float>(repeating: corner)
            let q = SIMD3<Float>(abs(pos.x), abs(pos.y), abs(pos.z)) - inner
            let o = simd_max(q, .zero), d = simd_length(o), limit = corner - f.r
            if d > limit, d > 0 {
                let sign = SIMD3<Float>(pos.x < 0 ? -1 : 1, pos.y < 0 ? -1 : 1, pos.z < 0 ? -1 : 1)
                let n = sign * o / d
                var fixed = pos
                for k in 0..<3 where q[k] > 0 { fixed[k] = sign[k] * (inner[k] + o[k] / d * limit) }
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
        if zoomTarget > 0 {
            // Inside: the screen is the box, so it doesn't turn. A drag tilts the water and stirs the air its way.
            tilt = max(-0.7, min(0.7, Float(translation.width) / 320))
            for f in floaters where f.body.components[PhysicsBodyComponent.self]?.isAffectedByGravity == false {
                if var motion = f.body.components[PhysicsMotionComponent.self] {
                    motion.linearVelocity += SIMD3<Float>(d.x, -d.y, 0) * 0.0009
                    f.body.components.set(motion)
                }
            }
        } else {
            rotate(by: d * 0.008)
        }
    }

    func release(velocity: CGSize) {
        dragging = false
        lastDrag = .zero
        if zoomTarget > 0 { tilt = 0; return }
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

    private func gravityInCube() -> SIMD3<Float> {
        root.components[PhysicsSimulationComponent.self]?.gravity ?? root.orientation.inverse.act([0, -Self.gravity, 0])
    }

    // MARK: Picking

    /// Where a point in the scene lands on screen (the camera looks straight down −z from `distance`).
    private func project(_ w: SIMD3<Float>) -> CGPoint {
        let cam = camera?.position ?? [0, 0, 3]
        let tanHalf = tan(insideFov / 2 * .pi / 180)
        let rel = w - cam, depth = -rel.z
        guard depth > 0.02 else { return CGPoint(x: -10_000, y: -10_000) }   // behind you
        let h = Float(screen.height) / 2
        return CGPoint(x: CGFloat(Float(screen.width) / 2 + rel.x / (depth * tanHalf) * h),
                       y: CGFloat(h - rel.y / (depth * tanHalf) * h))
    }

    /// The particle nearest a tap (within reach), or you; a tap on nothing clears the label.
    func select(at point: CGPoint) {
        var best: (Int, CGFloat)?
        for (i, f) in floaters.enumerated() where !(zoomTarget > 0 && !f.rep) {
            let p = project(f.body.position(relativeTo: nil))
            let d = hypot(p.x - point.x, p.y - point.y)
            if d < 36, d < (best?.1 ?? .infinity) { best = (i, d) }
        }
        if best == nil, water != nil {
            // Nothing small under the finger: if it's on the water, name the water.
            let surfaceWorld = root.convert(position: surfaceUp * surfaceH, to: nil)
            let sp = project(surfaceWorld)
            if point.y > sp.y - 10 {
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
