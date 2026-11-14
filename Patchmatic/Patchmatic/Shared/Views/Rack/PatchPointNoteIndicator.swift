import SwiftUI

struct PatchPointNoteIndicator: View {
    let note: ModuleNote
    let control: Control
    let panelSize: CGSize
    let zoom: CGFloat
    @Environment(\.drawsShadows) private var drawsShadows

    #if os(iOS)
    @State private var showingText = false
    #endif

    var body: some View {
        let r = control.effectiveRadius * zoom
        let dotSize: CGFloat = max(5 * zoom * 0.75, 3)
        let gap: CGFloat = 4 * zoom
        let offset = (r + gap + dotSize / 2) / sqrt(2)

        Circle()
            .fill(.yellow)
            .frame(width: dotSize, height: dotSize)
            .shadow(color: drawsShadows ? .black.opacity(0.3) : .clear, radius: 1)
            #if os(iOS)
            .frame(width: NoteTextPopover.touchSize, height: NoteTextPopover.touchSize)
            .contentShape(Rectangle())
            .onTapGesture { showingText = true }
            .allowsHitTesting(!note.text.isEmpty)
            .popover(isPresented: $showingText) { NoteTextPopover(text: note.text) }
            .offset(x: offset, y: -offset)
            #else
            .offset(x: offset, y: -offset)
            .allowsHitTesting(false)
            #endif
    }
}
