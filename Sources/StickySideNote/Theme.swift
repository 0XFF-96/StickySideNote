import SwiftUI
import CoreText
import StickyCore

/// Design tokens: colours, radii, shadows, motion and type (spec section 5.8).
enum Theme {
    static let fg = Color(hex: "#020617")
    static let brand = Color(hex: "#574efa")
    static let brandHover = Color(hex: "#463ee0")
    static let brandActive = Color(hex: "#3a33b8")

    static let radiusSm: CGFloat = 6
    static let radiusMd: CGFloat = 8
    static let radius2xl: CGFloat = 16
    static let radius3xl: CGFloat = 24
    /// The large "petal" arc on a collapsed tab.
    static let petalArc: CGFloat = 20

    static let duration: Double = 0.18
    static let ease = Animation.timingCurve(0.16, 1, 0.3, 1, duration: duration)

    static func color(_ c: NoteColor) -> Color { Color(hex: c.hex) }

    private static var hasDMSans = false

    /// Registers the bundled DM Sans; without it text falls back to the system font.
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "DMSans-VariableFont_opsz_wght", withExtension: "ttf") else {
            NSLog("StickySideNote: DM Sans not bundled, using the system font")
            return
        }
        hasDMSans = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        hasDMSans ? Font.custom("DM Sans", size: size).weight(weight) : Font.system(size: size, weight: weight)
    }
}

extension Color {
    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xff) / 255,
                  green: Double((value >> 8) & 0xff) / 255,
                  blue: Double(value & 0xff) / 255)
    }
}

extension View {
    /// `shadow-sm`: 0 1px 2px / 0 1px 3px of #020617.
    func shadowSm() -> some View {
        shadow(color: Theme.fg.opacity(0.06), radius: 1.5, y: 1)
    }
    /// `shadow-lg`: 0 10px 15px -3px / 0 4px 6px -4px of #020617.
    func shadowLg() -> some View {
        shadow(color: Theme.fg.opacity(0.10), radius: 7, y: 8)
            .shadow(color: Theme.fg.opacity(0.05), radius: 2, y: 2)
    }
}
