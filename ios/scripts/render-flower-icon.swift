// Replaces render-icon.swift (the earlier riso ripple). Renders the app icon (April, Nov 20: "more simple and presentable, maybe just one blue flower"): one of
// Home's fan flowers on the app's paper. A fan that opens upward from its stem, scalloped along the top, its ink
// deepest where it meets the stem and fading toward the edge, like the garden's watercolour flowers.
//
//   swift ios/scripts/render-flower-icon.swift ios/AsthmaLog/Assets.xcassets/AppIcon.appiconset/AppIcon.png
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

// Paper (the app's grouped background).
ctx.setFillColor(rgb(0xF2F2F7))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Core Graphics counts y from the bottom. The fan's point sits a little below the middle; the stem runs off the
// bottom edge.
let apex = CGPoint(x: size / 2, y: 330)
let radius = 400.0
let half = 52.0 * Double.pi / 180          // half the fan's opening, either side of straight up
let deep: UInt32 = 0x2F63CF, pale: UInt32 = 0xA9C2EE

// The stem first, so the fan sits over its top.
ctx.setStrokeColor(rgb(deep))
ctx.setLineWidth(11)
ctx.setLineCap(.butt)
ctx.move(to: CGPoint(x: apex.x, y: -10))
ctx.addLine(to: CGPoint(x: apex.x, y: apex.y + 6))
ctx.strokePath()

// The fan: one outline, two straight sides up from the point and a top edge of soft scallops, each a curve that
// bulges past the arc between two points on it.
let start = Double.pi / 2 + half, end = Double.pi / 2 - half
func onArc(_ a: Double, _ r: Double) -> CGPoint { CGPoint(x: apex.x + r * cos(a), y: apex.y + r * sin(a)) }
let scallops = 4
let fan = CGMutablePath()
fan.move(to: apex)
fan.addLine(to: onArc(start, radius))
for k in 0..<scallops {
    let a0 = start - (start - end) * Double(k) / Double(scallops)
    let a1 = start - (start - end) * Double(k + 1) / Double(scallops)
    let mid = (a0 + a1) / 2
    fan.addQuadCurve(to: onArc(a1, radius), control: onArc(mid, radius * 1.2))
}
fan.closeSubpath()
let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                          colors: [rgb(deep), rgb(0x5C88DE), rgb(0xBACCEF), rgb(0xD3DDF2)] as CFArray,
                          locations: [0, 0.3, 0.78, 1])!
ctx.saveGState()
ctx.addPath(fan)
ctx.clip()
ctx.drawRadialGradient(gradient, startCenter: apex, startRadius: 0, endCenter: apex, endRadius: radius * 1.12,
                       options: [.drawsAfterEndLocation])
ctx.restoreGState()

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out.path)")
