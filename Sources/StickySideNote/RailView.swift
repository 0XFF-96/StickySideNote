import SwiftUI
import AppKit
import StickyCore

/// Height the rail may use on the current screen, published by the panel controller.
@MainActor
final class ScreenMetrics: ObservableObject {
    @Published var available: CGFloat = 600
    @Published var screenHeight: CGFloat = 800
    @Published var side: RailSide = .left
}

/// Callbacks for dragging the rail to another edge or screen; points are in screen coordinates.
@MainActor
final class RailDrag {
    var onBegan: (NSPoint) -> Void = { _ in }
    var onMoved: (NSPoint) -> Void = { _ in }
    var onEnded: (NSPoint) -> Void = { _ in }
}

/// Decides which note counts as hovered when the pointer is over several tracking areas
/// (an expanded card overlaps the tabs beneath it), and debounces fast sweeps.
@MainActor
final class HoverRouter {
    private weak var model: RailModel?
    private var inside: [UUID] = []
    private var pending: DispatchWorkItem?
    /// Off in snapshot runs, where hover is set directly instead of by the pointer.
    var isEnabled = true

    init(model: RailModel) { self.model = model }

    func set(_ id: UUID, inside isInside: Bool) {
        guard isEnabled else { return }
        inside.removeAll { $0 == id }
        if isInside { inside.append(id) }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.resolve() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (isInside ? 0.06 : 0.08), execute: work)
    }

    func resolve() {
        guard let model else { return }
        let alive = Set(model.store.notes.map(\.id))
        inside.removeAll { !alive.contains($0) }
        // Stay on the current note while the pointer is still on its card.
        if let current = model.hoveredID, inside.contains(current) { return }
        model.setHover(inside.last)
    }
}

struct RailView: View {
    @ObservedObject var model: RailModel
    @ObservedObject var metrics: ScreenMetrics
    let hover: HoverRouter
    let drag: RailDrag

    @State private var cardHeights: [UUID: CGFloat] = [:]
    @State private var addHovered = false
    @State private var addPressed = false

    var body: some View {
        let notes = model.store.notes
        let layout = RailLayout.compute(noteCount: notes.count, available: metrics.available)
        let maxText = max(60, metrics.screenHeight * RailLayout.maxCardFraction - 60)
        let expandedID = model.editingID ?? model.hoveredID
        let side = metrics.side
        // Everything hugs the screen edge the rail is on and grows away from it.
        let edge: Alignment = side == .left ? .topLeading : .topTrailing

        ZStack(alignment: edge) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                let expanded = expandedID == note.id
                let top = expanded
                    ? layout.cardTop(index: index,
                                     cardHeight: cardHeights[note.id] ?? layout.tabHeight,
                                     available: metrics.available)
                    : layout.tabTop(index)
                NoteView(note: note, index: index, side: side, tabHeight: layout.tabHeight,
                         maxTextHeight: maxText, model: model, hover: hover, drag: drag,
                         onCardHeight: { cardHeights[note.id] = $0 })
                    .offset(y: top)
                    .zIndex(expanded ? 1 : 0)
                    .animation(Theme.ease, value: top)
            }
            if layout.canAdd {
                addButton(side).offset(y: layout.tabTop(notes.count))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge)
    }

    private func addButton(_ side: RailSide) -> some View {
        let r = Theme.radiusMd
        return Text("+")
            .font(Theme.font(18, .medium))
            .foregroundStyle(.white)
            .frame(width: RailLayout.addWidth, height: RailLayout.addHeight)
            .background(addPressed ? Theme.brandActive : addHovered ? Theme.brandHover : Theme.brand)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: side == .left ? 0 : r,
                                              bottomLeadingRadius: side == .left ? 0 : r,
                                              bottomTrailingRadius: side == .left ? r : 0,
                                              topTrailingRadius: side == .left ? r : 0))
            .overlay {
                MouseCatcher(drag: drag,
                             onHover: { addHovered = $0 },
                             onPress: { addPressed = $0 },
                             onClick: { model.addNote() },
                             onDoubleClick: { model.addNote() })
            }
            .animation(Theme.ease, value: addHovered)
            .help("新建便签")
    }
}
