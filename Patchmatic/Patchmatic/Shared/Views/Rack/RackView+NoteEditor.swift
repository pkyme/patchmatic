import SwiftUI

// Sheet for editing module and patch point notes
extension RackView {
    /// Editor for a module or patch point note
    func noteEditor(for note: ModuleNote) -> some View {
        ModuleNoteEditor(
            note: note,
            readOnly: readOnly,
            onSave: { text in
                if text.isEmpty && isNewNote {
                    patchVM.deleteNote(note)
                } else {
                    patchVM.updateNote(note, text: text)
                }
                editingNote = nil
            },
            onCancel: {
                // A new note that was never given text is discarded
                if isNewNote && note.text.isEmpty {
                    patchVM.deleteNote(note)
                }
                editingNote = nil
            },
            onDelete: {
                patchVM.deleteNote(note)
                editingNote = nil
            }
        )
    }
}
