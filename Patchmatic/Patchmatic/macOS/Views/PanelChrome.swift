import SwiftUI

/// A vertical divider that resizes the panel to its left when dragged, saving the
/// width to UserDefaults when the drag ends.
struct ResizeDivider: View {
    @Binding var width: CGFloat
    let range: ClosedRange<CGFloat>
    let storageKey: String

    @State private var dragStartWidth: CGFloat?

    var body: some View {
        Divider()
            .padding(.horizontal, 3)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    let start = dragStartWidth ?? width
                    dragStartWidth = start
                    width = min(max(start + value.translation.width, range.lowerBound), range.upperBound)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    UserDefaults.standard.set(width, forKey: storageKey)
                })
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
    }

    /// The stored width for `key`, or `defaultWidth` when none is stored.
    static func storedWidth(_ key: String, default defaultWidth: CGFloat) -> CGFloat {
        UserDefaults.standard.object(forKey: key) as? CGFloat ?? defaultWidth
    }
}

extension View {
    /// Asks whether to save or discard uncommitted edits before switching away from them.
    func unsavedChangesAlert(
        isPresented: Bool,
        message: String = "You have unsaved changes. Save or discard before switching?",
        save: @escaping () -> Void,
        discard: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) -> some View {
        alert("Unsaved Changes", isPresented: Binding(
            get: { isPresented },
            set: { if !$0 { cancel() } }
        )) {
            Button("Save Changes", action: save)
            Button("Discard Edits", role: .destructive, action: discard)
            Button("Cancel", role: .cancel, action: cancel)
        } message: { Text(message) }
    }
}
