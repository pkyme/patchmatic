import SwiftUI

// MARK: - New Group Editor

struct NewGroupEditor: View {
    let onCreate: (String, String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("New Group")
                .font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $notes)
                .font(.body)
                .frame(minWidth: 300, minHeight: 80, maxHeight: 150)
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Notes")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    onCreate(name, notes)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding()
    }
}

// MARK: - Group Notes Editor

struct GroupNotesEditor: View {
    let group: ModuleGroup
    let patchVM: PatchViewModel

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(group: ModuleGroup, patchVM: PatchViewModel) {
        self.group = group
        self.patchVM = patchVM
        _text = State(initialValue: group.notes)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Notes for \(group.name)")
                .font(.headline)
            TextEditor(text: $text)
                .font(.body)
                .frame(minWidth: 300, minHeight: 100, maxHeight: 200)
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    patchVM.updateGroupNotes(group.id, notes: text)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}
