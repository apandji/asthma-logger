import AppKit
import WebKit
let args = CommandLine.arguments
let input = URL(fileURLWithPath: args[1]); let output = URL(fileURLWithPath: args[2])
let width = CGFloat(Double(args[3])!); let dark = args.count > 4 && args[4] == "dark"
final class D: NSObject, WKNavigationDelegate {
  func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
      w.evaluateJavaScript("Math.max(document.documentElement.scrollHeight, document.body.scrollHeight)") { r, _ in
        let h = CGFloat((r as? NSNumber)?.doubleValue ?? 1000)
        w.setFrameSize(NSSize(width: width, height: h))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
          let c = WKSnapshotConfiguration(); c.rect = CGRect(x: 0, y: 0, width: width, height: h)
          w.takeSnapshot(with: c) { img, err in
            guard let img, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else { print("fail", err as Any); exit(1) }
            try! png.write(to: output); print("ok", rep.pixelsWide, rep.pixelsHigh); exit(0)
          }
        }
      }
    }
  }
}
let app = NSApplication.shared
let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 1000), styleMask: [.borderless], backing: .buffered, defer: false)
let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: 1000))
wv.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
win.appearance = wv.appearance
let d = D(); wv.navigationDelegate = d
win.contentView = wv
wv.loadFileURL(input, allowingReadAccessTo: input.deletingLastPathComponent())
DispatchQueue.main.asyncAfter(deadline: .now() + 30) { print("timeout"); exit(2) }
app.run()
