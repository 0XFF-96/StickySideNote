// Draws the app icon to a 1024×1024 PNG.  Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// macOS icon grid: an 824 pt rounded square centred on the 1024 canvas.
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
let platePath = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Soft shadow under the plate.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x020617, 0.30))
ctx.addPath(platePath)
ctx.setFillColor(color(0x4a42e6))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(platePath)
ctx.clip()

// Plate: brand indigo, lighter at the top left.
let ground = CGGradient(colorsSpace: nil,
                        colors: [color(0x6f67ff), color(0x4a42e6), color(0x352dc0)] as CFArray,
                        locations: [0, 0.55, 1])!
ctx.drawLinearGradient(ground, start: CGPoint(x: 220, y: 924), end: CGPoint(x: 800, y: 100), options: [])

/// A square sticky note centred at the origin. `curl` cuts the bottom-right corner for a lifted flap.
func note(side: CGFloat, radius: CGFloat, curl: CGFloat) -> CGPath {
    let half = side / 2
    let p = CGMutablePath()
    p.move(to: CGPoint(x: -half + radius, y: half))
    p.addArc(tangent1End: CGPoint(x: half, y: half), tangent2End: CGPoint(x: half, y: half - radius), radius: radius)
    if curl > 0 {
        p.addLine(to: CGPoint(x: half, y: -half + curl))
        p.addLine(to: CGPoint(x: half - curl, y: -half))
    } else {
        p.addArc(tangent1End: CGPoint(x: half, y: -half), tangent2End: CGPoint(x: half - radius, y: -half), radius: radius)
    }
    p.addArc(tangent1End: CGPoint(x: -half, y: -half), tangent2End: CGPoint(x: -half, y: -half + radius), radius: radius)
    p.addArc(tangent1End: CGPoint(x: -half, y: half), tangent2End: CGPoint(x: -half + radius, y: half), radius: radius)
    p.closeSubpath()
    return p
}

let side: CGFloat = 470, radius: CGFloat = 26, curl: CGFloat = 132
let half = side / 2

/// Draws one note rotated about its own centre.
func draw(hex: UInt32, at centre: CGPoint, degrees: CGFloat, curl: CGFloat, shadow: CGFloat,
          extras: () -> Void = {}) {
    ctx.saveGState()
    ctx.translateBy(x: centre.x, y: centre.y)
    ctx.rotate(by: degrees * .pi / 180)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: shadow, color: color(0x0e1533, 0.38))
    ctx.addPath(note(side: side, radius: radius, curl: curl))
    ctx.setFillColor(color(hex))
    ctx.fillPath()
    ctx.restoreGState()
    extras()
    ctx.restoreGState()
}

// Two notes fanned out behind, one on top: the classic pad of sticky notes.
draw(hex: 0xa7cde8, at: CGPoint(x: 452, y: 548), degrees: 13, curl: 0, shadow: 22)
draw(hex: 0xe59fb1, at: CGPoint(x: 566, y: 520), degrees: -9, curl: 0, shadow: 22)
draw(hex: 0xf4d86b, at: CGPoint(x: 512, y: 500), degrees: 3, curl: curl, shadow: 34) {
    // Lighter band along the top, where the adhesive strip sits.
    ctx.saveGState()
    ctx.addPath(note(side: side, radius: radius, curl: curl))
    ctx.clip()
    ctx.setFillColor(color(0xffffff, 0.22))
    ctx.fill(CGRect(x: -half, y: half - 92, width: side, height: 92))
    ctx.restoreGState()

    // Handwriting, as three bars.
    ctx.setFillColor(color(0x020617, 0.80))
    for (n, width) in [300.0, 300.0, 170.0].enumerated() {
        let line = CGRect(x: -half + 62, y: half - 190 - CGFloat(n) * 74, width: width, height: 28)
        ctx.addPath(CGPath(roundedRect: line, cornerWidth: 14, cornerHeight: 14, transform: nil))
    }
    ctx.fillPath()

    // The lifted corner: the paper's underside folded back over the note.
    let flap = CGMutablePath()
    flap.move(to: CGPoint(x: half, y: -half + curl))
    flap.addLine(to: CGPoint(x: half - curl, y: -half))
    flap.addArc(tangent1End: CGPoint(x: half - curl, y: -half + curl),
                tangent2End: CGPoint(x: half, y: -half + curl), radius: 30)
    flap.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -8, height: 8), blur: 18, color: color(0x020617, 0.30))
    ctx.addPath(flap)
    ctx.setFillColor(color(0xebc221))
    ctx.fillPath()
    ctx.restoreGState()
}
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
