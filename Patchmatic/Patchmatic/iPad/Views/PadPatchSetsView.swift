import SwiftUI

/// iPad root view: read-only browsing of sets. Selection is stored in local
/// UserDefaults so the shared document is never modified by the iPad.
struct PadPatchSetsView: View {
    let documentManager: DocumentManager
    let onChangeFolder: () -> Void

    @State private var rackVM: RackViewModel
    @State private var patchVM: PatchViewModel
    @State private var setVM: PatchSetViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility =
        UserDefaults.standard.object(forKey: AppSettings.padSidebarVisible) as? Bool ?? true ? .all : .detailOnly

    init(documentManager: DocumentManager, onChangeFolder: @escaping () -> Void) {
        self.documentManager = documentManager
        self.onChangeFolder = onChangeFolder
        let doc = documentManager.document
        let rackVM = RackViewModel(document: doc)
        let patchVM = PatchViewModel(document: doc)
        patchVM.rackVM = rackVM
        self._rackVM = State(initialValue: rackVM)
        self._patchVM = State(initialValue: patchVM)
        self._setVM = State(initialValue: PatchSetViewModel(document: doc))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            PatchSetView(rackVM: rackVM, patchVM: patchVM, setVM: setVM,
                    edgeSwipeEnabled: columnVisibility == .detailOnly)
                .id(documentManager.imagesGeneration)
                .navigationTitle(setVM.currentPatch?.name ?? "")
                .navigationBarTitleDisplayMode(.inline)
        }
        // Not done in init: init reruns on every parent update and would overwrite
        // the shared document's selection.
        .onAppear {
            let defaults = UserDefaults.standard
            setVM.restoreSelection(
                setID: defaults.string(forKey: AppSettings.padActiveSetID).flatMap(UUID.init),
                patchID: defaults.string(forKey: AppSettings.padActivePatchID).flatMap(UUID.init)
            )
        }
        .onChange(of: setVM.document.activeSetID) { _, id in
            UserDefaults.standard.set(id?.uuidString, forKey: AppSettings.padActiveSetID)
        }
        .onChange(of: setVM.document.activePatchID) { _, id in
            UserDefaults.standard.set(id?.uuidString, forKey: AppSettings.padActivePatchID)
        }
        .onChange(of: columnVisibility) { _, visibility in
            UserDefaults.standard.set(visibility != .detailOnly, forKey: AppSettings.padSidebarVisible)
        }
    }

    private var selectedSetID: Binding<UUID?> {
        Binding(
            get: { setVM.document.activeSetID },
            set: { id in
                guard let id, id != setVM.document.activeSetID,
                      let set = setVM.document.sets.first(where: { $0.id == id }) else { return }
                setVM.selectSet(set)
            }
        )
    }

    private var selectedPatchIndex: Binding<Int?> {
        Binding(
            get: { setVM.currentIndex },
            set: { index in
                guard let index else { return }
                setVM.goTo(index: index)
            }
        )
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            setList
            Divider()
            patchList
        }
        .navigationTitle("Sets")
        .toolbar {
            Button(action: onChangeFolder) {
                Label("Change Folder", systemImage: "folder")
            }
        }
    }

    private var setList: some View {
        List(selection: selectedSetID) {
            Section("Sets") {
                ForEach(setVM.document.sets) { set in
                    Text(set.name)
                        .tag(set.id)
                }
            }
        }
        .overlay {
            if setVM.document.sets.isEmpty {
                ContentUnavailableView("No Sets",
                                       systemImage: "list.number",
                                       description: Text("Create sets in Patchmatic on your Mac."))
            }
        }
    }

    private var patchList: some View {
        List(selection: selectedPatchIndex) {
            Section("Patches in Set") {
                ForEach(setVM.resolvedPatches, id: \.index) { entry in
                    SetPatchRow(position: entry.index + 1, name: entry.patch.name, numberWidth: 32) {
                        if let filename = entry.patch.audioPreviewFilename {
                            AudioPreviewButton(filename: filename, audioPlayer: patchVM.audioPlayer)
                        }
                    }
                    .tag(entry.index)
                }
            }
        }
        .overlay {
            if setVM.activeSet != nil, setVM.resolvedPatches.isEmpty {
                ContentUnavailableView("Empty Set",
                                       systemImage: "list.number",
                                       description: Text("Add patches to this set in Patchmatic on your Mac."))
            }
        }
    }
}

/// Play/stop control for a patch's audio preview in the sidebar.
private struct AudioPreviewButton: View {
    let filename: String
    let audioPlayer: AudioPlayer

    private var isPlaying: Bool { audioPlayer.isPlaying(filename) }

    var body: some View {
        Button {
            audioPlayer.toggle(filename)
        } label: {
            Image(systemName: isPlaying ? "stop.fill" : "speaker.wave.2")
                .foregroundStyle(isPlaying ? Color.accentColor : Color.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}
