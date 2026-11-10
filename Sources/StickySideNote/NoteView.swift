import SwiftUI
import StickyCore

/// One note: a collapsed tab on the edge that expands into a card on hover or while editing.
struct NoteView: View {
    let note: Note
    let index: Int
    let side: RailSide
    let tabHeight: CGFloat
    /// Tallest the text area may get before it scrolls.
    let maxTextHeight: CGFloat
    @ObservedObject var model: RailModel
    let hover: HoverRouter
    let drag: RailDrag
    /// Reports the expanded card's height so the rail can keep it on screen.
    let onCardHeight: (CGFloat) -> Void

    @State private var bodyHeight: CGFloat = 0
    @FocusState private var editorFocused: Bool

    private var isEditing: Bool { model.editingID == note.id }
    private var isExpanded: Bool { isEditing || model.hoveredID == note.id }
    private var isCopied: Bool { model.copiedID == note.id }

    private var hint: String {
        if isEditing { return "Esc 或点别处保存" }
        return isCopied ? "✓ 已复制" : "单击复制 · 双击编辑"
    }

    /// Petal shape: one large arc and one small corner on the free side, alternating down the rail.
    private var shape: UnevenRoundedRectangle {
        let big = isExpanded ? Theme.radius3xl : Theme.petalArc
        let small = isExpanded ? Theme.radius2xl : Theme.radiusSm
        let bigOnTop = index % 2 == 0
        let top = bigOnTop ? big : small, bottom = bigOnTop ? small : big
        // Square against the screen edge, rounded on the free side.
        return side == .left
            ? UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                     bottomTrailingRadius: bottom, topTrailingRadius: top)
            : UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom,
                                     bottomTrailingRadius: 0, topTrailingRadius: 0)
    }

    private var edge: Alignment { side == .left ? .topLeading : .topTrailing }

    var body: some View {
        ZStack(alignment: edge) {
            card
                .frame(width: RailLayout.cardWidth, alignment: edge)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    bodyHeight = $0
                    onCardHeight(max(tabHeight, $0))
                }
                .opacity(isExpanded ? 1 : 0)
            Text(note.cap)
                .font(Theme.font(17, .bold))
                .tracking(-0.34)
                .frame(width: RailLayout.tabWidth - 2, height: tabHeight)
                .opacity(isExpanded ? 0 : 1)
        }
        .foregroundStyle(Theme.fg)
        .frame(width: isExpanded ? RailLayout.cardWidth : RailLayout.tabWidth,
               height: isExpanded ? max(tabHeight, bodyHeight) : tabHeight,
               alignment: edge)
        .background(Theme.color(note.color))
        .clipShape(shape)
        .overlay { if isEditing { shape.strokeBorder(Theme.brand, lineWidth: 2) } }
        .background { if isEditing { shape.stroke(Theme.brand.opacity(0.2), lineWidth: 8) } }
        .modifier(Elevation(lifted: isExpanded))
        .overlay {
            MouseCatcher(
                passThrough: isEditing,
                drag: drag,
                onHover: { hover.set(note.id, inside: $0) },
                onClick: { copy() },
                onDoubleClick: { model.beginEdit(note.id) },
                onSecondaryClick: { view, event in
                    NoteMenu.show(for: note, model: model, in: view, with: event)
                    // The menu's tracking loop can swallow mouseExited; re-check where the pointer is.
                    if (view as? CatcherView)?.containsPointer == false {
                        hover.set(note.id, inside: false)
                    }
                })
        }
        .animation(Theme.ease, value: isExpanded)
        .onChange(of: isEditing) { _, editing in editorFocused = editing }
        .onAppear { editorFocused = isEditing }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                editor
            } else {
                ViewThatFits(in: .vertical) {
                    noteText
                    ScrollView { noteText }
                }
                .frame(maxHeight: maxTextHeight)
            }
            Text(hint)
                .font(Theme.font(11, isCopied ? .semibold : .medium))
                .foregroundStyle(Theme.fg.opacity(isCopied ? 1 : 0.64))
        }
        .padding(EdgeInsets(top: 12, leading: side == .left ? 16 : 18,
                            bottom: 10, trailing: side == .left ? 18 : 16))
    }

    private var noteText: some View {
        Text(note.text)
            .font(Theme.font(14, .regular))
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A TextEditor has no intrinsic height, so an invisible copy of the draft sizes it.
    private var editor: some View {
        Text(model.draft.isEmpty || model.draft.hasSuffix("\n") ? model.draft + " " : model.draft)
            .font(Theme.font(14, .regular))
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(0)
            .overlay {
                TextEditor(text: $model.draft)
                    .font(Theme.font(14, .regular))
                    .lineSpacing(3)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .padding(.horizontal, -5)
                    .focused($editorFocused)
            }
            .frame(maxHeight: maxTextHeight)
    }

    private func copy() {
        let id = note.id
        model.click(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { model.clearCopied(id) }
    }
}

private struct Elevation: ViewModifier {
    let lifted: Bool
    func body(content: Content) -> some View {
        if lifted { content.shadowLg() } else { content.shadowSm() }
    }
}
