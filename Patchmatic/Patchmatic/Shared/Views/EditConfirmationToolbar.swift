import SwiftUI

struct EditConfirmationToolbar: View {
    let onSave: () -> Void
    let onDiscard: () -> Void

    @State private var visible = false

    var body: some View {
        HStack(spacing: 12) {
            Button("Discard Edits", action: onDiscard)
            Button("Save Changes", action: onSave)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .opacity(visible ? 0.55 : 0)
        .offset(y: visible ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) { visible = true }
        }
    }
}
