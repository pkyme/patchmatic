import SwiftUI

struct ModuleNoteEditor: View {
    @State private var text: String
    let note: ModuleNote
    let readOnly: Bool
    let onSave: (String) -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    init(note: ModuleNote, readOnly: Bool, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.note = note
        self.readOnly = readOnly
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        _text = State(initialValue: note.text)
    }

    var body: some View {
        VStack(spacing: 16) {
            TextEditor(text: $text)
                .font(.body)
                .frame(minHeight: 100, maxHeight: 200)
                .disabled(readOnly)

            if readOnly {
                Button("Close") {
                    onCancel()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }

                    Spacer()

                    Button("Delete", role: .destructive) {
                        onDelete()
                    }

                    Button("Save") {
                        onSave(text)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 400)
    }
}
