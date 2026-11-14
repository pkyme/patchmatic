import SwiftUI

struct NoteTooltipData {
    let text: String
    let anchor: Anchor<CGRect>
}

struct NoteTooltipPreferenceKey: PreferenceKey {
    static let defaultValue: NoteTooltipData? = nil
    static func reduce(value: inout NoteTooltipData?, nextValue: () -> NoteTooltipData?) {
        value = nextValue() ?? value
    }
}

struct NoteIcon: View {
    let note: ModuleNote
    let panelSize: CGSize
    let zoom: CGFloat
    let onTap: (() -> Void)?

    @State private var isHovering = false
    #if os(iOS)
    @State private var showingText = false
    #endif

    var body: some View {
        let iconSize: CGFloat = 12 * max(zoom, 1.0)

        ZStack {
            Image(systemName: "note.text")
                .font(.system(size: iconSize))
                .foregroundStyle(.yellow)
                .shadow(color: .black.opacity(0.3), radius: 2)
        }
        .frame(width: iconSize, height: iconSize)
        #if os(iOS)
        .frame(width: max(iconSize, NoteTextPopover.touchSize), height: max(iconSize, NoteTextPopover.touchSize))
        .contentShape(Rectangle())
        .onTapGesture {
            if let onTap { onTap() } else if !note.text.isEmpty { showingText = true }
        }
        .popover(isPresented: $showingText) { NoteTextPopover(text: note.text) }
        #else
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .allowsHitTesting(onTap != nil)
        #endif
        .onHover { hovering in
            isHovering = hovering
        }
        .anchorPreference(key: NoteTooltipPreferenceKey.self, value: .bounds) { anchor in
            isHovering && !note.text.isEmpty ? NoteTooltipData(text: note.text, anchor: anchor) : nil
        }
    }
}

#if os(iOS)
/// Note text shown when a note is tapped on touch devices.
struct NoteTextPopover: View {
    static let touchSize: CGFloat = 44

    let text: String

    var body: some View {
        Text(text)
            .padding()
            .frame(maxWidth: 320, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .presentationCompactAdaptation(.popover)
    }
}
#endif
