import CoreGraphics

/// Which vertical edge of the screen the rail is stuck to.
public enum RailSide: String, Codable {
    case left, right
}

/// Sizes for the column of tabs on the screen edge.
public struct RailLayout: Equatable {
    public static let tabWidth: CGFloat = 36, tabHeight: CGFloat = 52, gap: CGFloat = 8
    public static let addWidth: CGFloat = 28, addHeight: CGFloat = 32
    public static let cardWidth: CGFloat = 268, minTabHeight: CGFloat = 14
    public static let topFraction: CGFloat = 0.13, bottomMargin: CGFloat = 8
    public static let maxCardFraction: CGFloat = 0.6

    public let tabHeight: CGFloat
    public let gap: CGFloat
    public let canAdd: Bool
    public let railHeight: CGFloat

    /// `available` is the height the column may use: usable screen height × (1 − topFraction) − bottomMargin.
    public static func compute(noteCount n: Int, available: CGFloat) -> RailLayout {
        let slot = tabHeight + gap
        let count = CGFloat(n)
        if count * slot + addHeight <= available {
            let canAdd = (count + 1) * slot + addHeight <= available
            return RailLayout(tabHeight: tabHeight, gap: gap, canAdd: canAdd,
                              railHeight: count * slot + (canAdd ? addHeight : 0))
        }
        // Too many notes for this screen: shrink every tab so none is clipped.
        let scale = available / (count * slot)
        let h = max(minTabHeight, tabHeight * scale)
        let g = gap * scale
        return RailLayout(tabHeight: h, gap: g, canAdd: false, railHeight: count * (h + g))
    }

    /// Offset of tab `index` from the top of the column.
    public func tabTop(_ index: Int) -> CGFloat {
        CGFloat(index) * (tabHeight + gap)
    }

    /// Offset of the expanded card: aligned with its tab unless that would run past the bottom.
    public func cardTop(index: Int, cardHeight: CGFloat, available: CGFloat) -> CGFloat {
        max(0, min(tabTop(index), available - cardHeight))
    }

    /// The edge nearer to the pointer; where a dragged rail snaps when it is dropped.
    public static func nearestSide(pointerX: CGFloat, in screen: CGRect) -> RailSide {
        pointerX <= screen.midX ? .left : .right
    }

    /// Panel frame (AppKit coordinates, origin bottom-left) for a panel of `size` whose top
    /// edge sits `topFraction` down the usable area, flush against the chosen side.
    public static func panelFrame(in visible: CGRect, side: RailSide, size: CGSize) -> CGRect {
        let top = visible.maxY - visible.height * topFraction
        let x = side == .left ? visible.minX : visible.maxX - size.width
        return CGRect(x: x, y: top - size.height, width: size.width, height: size.height)
    }
}
