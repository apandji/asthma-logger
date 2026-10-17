// Renders the app icon: the ripple riso. Black paper, a halftone of ink dots on a grid turned 12°, and two
// ripples running out from the pin (the place): an outer one in the rescue pastel, an inner one in the
// standard pastel. Dots swell and take the ink where a ring passes, the way the home does after a log.
//
//   swift ios/scripts/render-icon.swift ios/AsthmaLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.png")
let size = 1024.0
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, alpha: a)
}
func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
    func ch(_ s: Int) -> UInt32 {
        let x = Double((a >> s) & 0xFF), y = Double((b >> s) & 0xFF)
        return UInt32((x + (y - x) * t).rounded()) << s
    }
    return ch(16) | ch(8) | ch(0)
}

// Paper.
ctx.setFillColor(rgb(0x0B0B0D))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let centre = CGPoint(x: size / 2, y: size / 2)
let rescueSoft: UInt32 = 0xFFC9A3, standardSoft: UInt32 = 0xB4DCF7, grain: UInt32 = 0x3A3A40
// Two rings: where they are and how wide.
let rings: [(radius: Double, width: Double, ink: UInt32)] = [(372, 110, rescueSoft), (188, 80, standardSoft)]

// The halftone: a turned grid, each dot a little different, swelling where a ring passes.
let spacing = 30.0, angle = 12 * Double.pi / 180
let cosA = cos(angle), sinA = sin(angle)
let n = Int(size * 1.5 / spacing)
for i in -n...n {
    for j in -n...n {
        let gx = Double(i) * spacing, gy = Double(j) * spacing
        let x = centre.x + gx * cosA - gy * sinA, y = centre.y + gx * sinA + gy * cosA
        guard x > -20, y > -20, x < size + 20, y < size + 20 else { continue }
        let wobble = Double((i &* 73 &+ j &* 151) & 7) / 7
        var r = 4.2 * (0.7 + 0.5 * wobble)
        var ink = grain
        var alpha = 0.9
        let d = hypot(x - centre.x, y - centre.y)
        for ring in rings {
            let dd = abs(d - ring.radius)
            if dd < ring.width {
                let t = pow(1 - dd / ring.width, 1.6)
                r += t * 9.5
                ink = mix(ink, ring.ink, min(1, t * 1.2))
                alpha = 0.9 + 0.1 * t
            }
        }
        // Inside the inner ring the grain goes faint, like the map before the scan.
        if d < rings[1].radius - rings[1].width * 0.6 { alpha *= 0.45 }
        ctx.setFillColor(rgb(ink, alpha))
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
}

// The pin: the place, in the standard blue with a white ring.
ctx.setFillColor(rgb(0x4FB0F5))
ctx.fillEllipse(in: CGRect(x: centre.x - 26, y: centre.y - 26, width: 52, height: 52))
ctx.setStrokeColor(rgb(0xFFFFFF, 0.95))
ctx.setLineWidth(9)
ctx.strokeEllipse(in: CGRect(x: centre.x - 42, y: centre.y - 42, width: 84, height: 84))

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out.path)")
