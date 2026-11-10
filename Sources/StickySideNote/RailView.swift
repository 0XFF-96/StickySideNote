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

/// Decides which note counts as hovered.
///
/// Enter/exit events only prompt a check; the answer comes from where the pointer actually
/// is. Resizing the panel as a note expands makes AppKit send a stray mouseExited for the
/// note under the pointer, and trusting it made the card collapse and re-open in a loop.
@MainActor
final class HoverRouter {
    private weak var model: RailModel?
    private var views: [UUID: WeakCatcher] = [:]
    private var lastEntered: UUID?
    private var pending: DispatchWorkItem?
    /// Off while the rail is being dragged, and in snapshot runs where hover is set directly.
    var isEnabled = true

    private struct WeakCatcher { weak var view: CatcherView? }

    init(model: RailModel) { self.model = model }

    func register(_ id: UUID, _ view: CatcherView) {
        views[id] = WeakCatcher(view: view)
    }

    func set(_ id: UUID, inside isInside: Bool) {
        guard isEnabled else { return }
        if isInside { lastEntered = id }
        schedule(after: isInside ? 0.06 : 0.08)
    }

    private func schedule(after delay: Double) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.resolve() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func resolve() {
        guard isEnabled, let model else { return }
        let alive = Set(model.store.notes.map(\.id))
        views = views.filter { alive.contains($0.key) && $0.value.view != nil }
        let under = views.filter { $0.value.view?.containsPointer == true }.map(\.key)

        if let current = model.hoveredID, under.contains(current) {
            // Still on the open card, even where it overlaps the tabs beneath it.
        } else if let lastEntered, under.contains(lastEntered) {
            model.setHover(lastEntered)
        } else {
            model.setHover(under.first)
        }
        // While a card is open keep checking, so it closes even if mouseExited never arrives.
        if model.hoveredID != nil { schedule(after: 0.2) }
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
