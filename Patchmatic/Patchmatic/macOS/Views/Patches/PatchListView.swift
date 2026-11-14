import SwiftUI

struct PatchListView: View {
    @Bindable var patchVM: PatchViewModel
    @State private var editingPatchNotesID: UUID?
    @State private var listSelection: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Patches")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(patchVM.document.racks) { rack in
                        Button(rack.name) {
                            patchVM.addPatch(rackID: rack.id)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(patchVM.document.racks.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(patchVM.document.patches, selection: $listSelection) { patch in
                HStack(spacing: 4) {
                    EditableText(text: patch.name, onCommit: { newName in
                        patchVM.renamePatch(patch, to: newName)
                    }, isSelected: patchVM.document.activePatchID == patch.id, beginEditing: Binding(
                        get: { patchVM.renamingPatchID == patch.id },
                        set: { if !$0 { patchVM.renamingPatchID = nil } }
                    ))
                    Spacer()
                    PatchListIcons(
                        patch: patch,
                        audioPlayer: patchVM.audioPlayer
                    )
                }
                .help(patch.patchNotes.isEmpty ? "" : patch.patchNotes)
                .tag(patch.id)
                .contextMenu {
                    Button("Rename") {
                        patchVM.renamingPatchID = patch.id
                    }
                    Button("Patch Notes\u{2026}") {
                        patchVM.selectPatch(patch)
                        editingPatchNotesID = patch.id
                    }
                    Button("Duplicate") {
                        patchVM.duplicatePatch(patch)
                    }
                    Divider()
                    Button("Delete\u{2026}", role: .destructive) {
                        patchVM.requestDeletePatch(patch)
                    }
                }
            }
            .listStyle(.sidebar)
            .onAppear { listSelection = patchVM.document.activePatchID }
            .onChange(of: listSelection) { _, id in
                if let id, id != patchVM.document.activePatchID,
                   let patch = patchVM.document.patches.first(where: { $0.id == id }) {
                    patchVM.selectPatch(patch)
                }
            }
            .onChange(of: patchVM.document.activePatchID) { _, id in
                listSelection = id
            }
            .onChange(of: patchVM.pendingPatchSelectionID) { old, new in
                if old != nil && new == nil {
                    listSelection = patchVM.document.activePatchID
                }
            }
            .sheet(isPresented: Binding(
                get: { editingPatchNotesID != nil },
                set: { if !$0 { editingPatchNotesID = nil } }
            )) {
                PatchNotesSheet(patchVM: patchVM, readOnly: false) {
                    editingPatchNotesID = nil
                }
            }
        }
    }
}

private struct PatchListIcons: View {
    let patch: Patch
    let audioPlayer: AudioPlayer

    private static let iconWidth: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            if !patch.patchNotes.isEmpty {
                Image(systemName: "doc.text")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: Self.iconWidth)
            } else {
                Color.clear.frame(width: Self.iconWidth)
            }

            if let filename = patch.audioPreviewFilename {
                PatchListAudioButton(filename: filename, audioPlayer: audioPlayer)
                .frame(width: Self.iconWidth)
            } else {
                Color.clear.frame(width: Self.iconWidth)
            }
        }
    }
}

private struct PatchListAudioButton: View {
    let filename: String
    let audioPlayer: AudioPlayer
    @State private var isHovering = false

    private var isPlaying: Bool { audioPlayer.isPlaying(filename) }

    var body: some View {
        Button {
            audioPlayer.toggle(filename)
        } label: {
            Image(systemName: isPlaying ? "stop.fill" : "speaker.wave.2")
                .font(.system(size: 9))
                .foregroundStyle(isPlaying ? .primary : isHovering ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
