import SwiftUI
import StickyCore

/// Height the rail may use on the current screen, published by the panel controller.
@MainActor
final class ScreenMetrics: ObservableObject {
    @Published var available: CGFloat = 600
    @Published var screenHeight: CGFloat = 800
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

    @State private var cardHeights: [UUID: CGFloat] = [:]
    @State private var addHovered = false
    @State private var addPressed = false

    var body: some View {
        let notes = model.store.notes
        let layout = RailLayout.compute(noteCount: notes.count, available: metrics.available)
        let maxText = max(60, metrics.screenHeight * RailLayout.maxCardFraction - 60)
        let expandedID = model.editingID ?? model.hoveredID

        ZStack(alignment: .topLeading) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                let expanded = expandedID == note.id
                let top = expanded
                    ? layout.cardTop(index: index,
                                     cardHeight: cardHeights[note.id] ?? layout.tabHeight,
                                     available: metrics.available)
                    : layout.tabTop(index)
                NoteView(note: note, index: index, tabHeight: layout.tabHeight,
                         maxTextHeight: maxText, model: model, hover: hover,
                         onCardHeight: { cardHeights[note.id] = $0 })
                    .offset(y: top)
                    .zIndex(expanded ? 1 : 0)
                    .animation(Theme.ease, value: top)
            }
            if layout.canAdd {
                addButton.offset(y: layout.tabTop(notes.count))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var addButton: some View {
        Text("+")
            .font(Theme.font(18, .medium))
            .foregroundStyle(.white)
            .frame(width: RailLayout.addWidth, height: RailLayout.addHeight)
            .background(addPressed ? Theme.brandActive : addHovered ? Theme.brandHover : Theme.brand)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                              bottomTrailingRadius: Theme.radiusMd,
                                              topTrailingRadius: Theme.radiusMd))
            .overlay {
                MouseCatcher(onHover: { addHovered = $0 },
                             onPress: { addPressed = $0 },
                             onClick: { model.addNote() },
                             onDoubleClick: { model.addNote() })
            }
            .animation(Theme.ease, value: addHovered)
            .help("新建便签")
    }
}
