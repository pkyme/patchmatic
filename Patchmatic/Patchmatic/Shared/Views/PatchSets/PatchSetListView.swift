import SwiftUI

struct PatchSetListView: View {
    @Bindable var setVM: PatchSetViewModel
    var patchVM: PatchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            setHeader
            Divider()
            setList

            if setVM.activeSet != nil {
                Divider()
                setPatchesSection
            }
        }
    }

    private var setHeader: some View {
        HStack {
            Text("Sets")
                .font(.headline)
            Spacer()
            Button(action: setVM.addSet) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var setList: some View {
        List(setVM.document.sets, selection: Binding(
            get: { setVM.document.activeSetID },
            set: { id in
                if let id, let set = setVM.document.sets.first(where: { $0.id == id }) {
                    setVM.selectSet(set)
                }
            }
        )) { set in
            EditableText(text: set.name, onCommit: { newName in
                setVM.renameSet(set, to: newName)
            }, isSelected: setVM.document.activeSetID == set.id, beginEditing: Binding(
                get: { setVM.renamingSetID == set.id },
                set: { if !$0 { setVM.renamingSetID = nil } }
            ))
            .tag(set.id)
            .contextMenu {
                Button("Rename") {
                    setVM.renamingSetID = set.id
                }
                Button("Delete\u{2026}", role: .destructive) {
                    setVM.requestDeleteSet(set)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var setPatchesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Patches in Set")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            patchList

            if !setVM.availablePatches.isEmpty {
                addPatchMenu
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var patchList: some View {
        List {
            ForEach(setVM.resolvedPatches, id: \.patch.id) { entry in
                patchRow(entry: entry)
                    .contextMenu {
                        Button("Remove from Set", role: .destructive) {
                            setVM.removePatchFromSet(at: entry.index)
                        }
                    }
            }
            .onMove { source, destination in
                setVM.movePatchInSet(from: source, to: destination)
            }
        }
        .listStyle(.plain)
    }

    private func patchRow(entry: (index: Int, patch: Patch)) -> some View {
        SetPatchRow(position: entry.index + 1, name: entry.patch.name) {
            // Marks the patch Sets mode is showing
            if setVM.currentIndex == entry.index {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            setVM.goTo(index: entry.index)
        }
    }

    private var addPatchMenu: some View {
        Menu {
            ForEach(setVM.availablePatches) { patch in
                Button(patch.name) {
                    setVM.addPatchToSet(patch)
                }
            }
        } label: {
            Label("Add Patch", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 4)
    }
}
