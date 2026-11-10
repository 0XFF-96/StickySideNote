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

/// A sticky note stuck to the left edge: it runs off the plate on the left and has rounded
/// corners on the right. `curl` cuts the bottom-right corner for a lifted flap.
func note(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, radius: CGFloat, curl: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: x, y: y + h))
    p.addArc(tangent1End: CGPoint(x: x + w, y: y + h), tangent2End: CGPoint(x: x + w, y: y + h - radius), radius: radius)
    if curl > 0 {
        p.addLine(to: CGPoint(x: x + w, y: y + curl))
        p.addLine(to: CGPoint(x: x + w - curl, y: y))
    } else {
        p.addArc(tangent1End: CGPoint(x: x + w, y: y), tangent2End: CGPoint(x: x + w - radius, y: y), radius: radius)
    }
    p.addLine(to: CGPoint(x: x, y: y))
    p.closeSubpath()
    return p
}

// Three notes stuck to the left side, like tabs on the edge of a screen. The middle one is
// pulled out and readable; the other two are tucked in.
let left = plate.minX - 40          // starts beyond the plate so the notes look tucked behind the edge
let radius: CGFloat = 28, gap: CGFloat = 32
let small: CGFloat = 150, large: CGFloat = 290, curl: CGFloat = 104
let top = 512 + (2 * small + large + 2 * gap) / 2

func drawNote(hex: UInt32, y: CGFloat, w: CGFloat, h: CGFloat, curl: CGFloat, shadow: CGFloat) -> CGPath {
    let path = note(x: left, y: y, w: w, h: h, radius: radius, curl: curl)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 6, height: -12), blur: shadow, color: color(0x0e1533, 0.40))
    ctx.addPath(path)
    ctx.setFillColor(color(hex))
    ctx.fillPath()
    ctx.restoreGState()
    return path
}

_ = drawNote(hex: 0xa7cde8, y: top - small, w: 300, h: small, curl: 0, shadow: 20)
_ = drawNote(hex: 0xe59fb1, y: top - 2 * small - large - 2 * gap, w: 300, h: small, curl: 0, shadow: 20)

let y = top - small - gap - large, w: CGFloat = 640
let open = drawNote(hex: 0xf4d86b, y: y, w: w, h: large, curl: curl, shadow: 36)

// Lighter band where the adhesive strip holds the note to the edge.
ctx.saveGState()
ctx.addPath(open)
ctx.clip()
ctx.setFillColor(color(0xffffff, 0.24))
ctx.fill(CGRect(x: left, y: y, width: 40 + 96, height: large))
ctx.restoreGState()

// Handwriting, as three bars.
ctx.setFillColor(color(0x020617, 0.80))
for (n, width) in [330.0, 330.0, 190.0].enumerated() {
    let line = CGRect(x: plate.minX + 150, y: y + large - 82 - CGFloat(n) * 70, width: width, height: 28)
    ctx.addPath(CGPath(roundedRect: line, cornerWidth: 14, cornerHeight: 14, transform: nil))
}
ctx.fillPath()

// The lifted corner: the paper's underside folded back over the note.
let right = left + w
let flap = CGMutablePath()
flap.move(to: CGPoint(x: right, y: y + curl))
flap.addLine(to: CGPoint(x: right - curl, y: y))
flap.addArc(tangent1End: CGPoint(x: right - curl, y: y + curl),
            tangent2End: CGPoint(x: right, y: y + curl), radius: 26)
flap.closeSubpath()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: -8, height: 8), blur: 18, color: color(0x020617, 0.30))
ctx.addPath(flap)
ctx.setFillColor(color(0xebc221))
ctx.fillPath()
ctx.restoreGState()
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
