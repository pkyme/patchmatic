import SwiftUI

struct ContentView: View {
    let documentManager: DocumentManager

    @State private var editorVM: ModuleEditorViewModel
    @State private var rackVM: RackViewModel
    @State private var patchVM: PatchViewModel
    @State private var setVM: PatchSetViewModel

    @AppStorage(AppSettings.appearanceMode) private var appearanceMode: String = "system"
    /// Current mode, shared with the menus through the same stored setting
    @AppStorage(AppSettings.selectedMode) private var storedMode: String = AppMode.racks.rawValue
    private var selectedSidebarItem: AppMode {
        get { AppMode(rawValue: storedMode) ?? .racks }
        nonmutating set { storedMode = newValue.rawValue }
    }
    @State private var pendingModeChange: AppMode?
    /// Mode switch waiting for confirmation that edits to in-use items should be saved
    @State private var inUseSaveConfirmation: InUseSaveConfirmation?

    private struct InUseSaveConfirmation {
        let mode: AppMode
        let message: String
    }
    @State private var listPanelWidth = ResizeDivider.storedWidth(AppSettings.listPanelWidth, default: 220)
    @State private var moduleLibraryWidth = ResizeDivider.storedWidth(AppSettings.moduleLibraryWidth, default: 280)
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var undoManager

    init(documentManager: DocumentManager) {
        self.documentManager = documentManager
        let doc = documentManager.document
        self._editorVM = State(initialValue: ModuleEditorViewModel(document: doc))
        let rackVM = RackViewModel(document: doc)
        let patchVM = PatchViewModel(document: doc)
        patchVM.rackVM = rackVM
        self._rackVM = State(initialValue: rackVM)
        self._patchVM = State(initialValue: patchVM)
        self._setVM = State(initialValue: PatchSetViewModel(document: doc))
    }

    var body: some View {
        Group {
            if selectedSidebarItem == .modules {
                HStack(spacing: 0) {
                    ModuleLibraryView(editorVM: editorVM, rackVM: rackVM)
                        .frame(width: moduleLibraryWidth)
                    ResizeDivider(width: $moduleLibraryWidth, range: 200...400, storageKey: AppSettings.moduleLibraryWidth)
                    ModuleEditorView(viewModel: editorVM)
                }
            } else {
                HStack(spacing: 0) {
                    rackPatchSetListPanel
                        .frame(width: listPanelWidth)
                    ResizeDivider(width: $listPanelWidth, range: 160...320, storageKey: AppSettings.listPanelWidth)
                    rackPatchSetDetailPanel
                        .overlay(alignment: .bottom) {
                            if selectedSidebarItem == .patches, patchVM.isEditing {
                                EditConfirmationToolbar(
                                    onSave: { patchVM.commitEditing() },
                                    onDiscard: { patchVM.discardEditing() }
                                ).padding(.bottom, 20)
                            }
                        }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .preferredColorScheme(appearanceMode == "light" ? .light : appearanceMode == "dark" ? .dark : nil)
        .onChange(of: selectedSidebarItem) { _, newItem in
            if newItem == .patches, let patch = patchVM.activePatch {
                rackVM.document.activeRackID = patch.rackID
            } else if newItem == .sets {
                setVM.showCurrentPatch()
            }
        }
        .alert(documentManager.storageAlert?.title ?? "", isPresented: Binding(
            get: { documentManager.storageAlert != nil },
            set: { if !$0 { documentManager.storageAlert = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(documentManager.storageAlert?.message ?? "") }
        .alert("Delete \u{201C}\(setVM.pendingDeleteSet?.name ?? "")\u{201D}?", isPresented: Binding(
            get: { setVM.pendingDeleteSet != nil },
            set: { if !$0 { setVM.pendingDeleteSet = nil } }
        )) {
            Button("Delete", role: .destructive) { setVM.confirmDeleteSet() }
            Button("Cancel", role: .cancel) { setVM.pendingDeleteSet = nil }
        } message: {
            Text("The patches in this set are not deleted. You can undo this from the Edit menu.")
        }
        .unsavedChangesAlert(
            isPresented: rackVM.pendingRackSelectionID != nil,
            save: { rackVM.confirmSelectionChange(save: true) },
            discard: { rackVM.confirmSelectionChange(save: false) },
            cancel: { rackVM.cancelSelectionChange() }
        )
        .alert("Delete \u{201C}\(patchVM.pendingDeletePatch?.name ?? "")\u{201D}?", isPresented: Binding(
            get: { patchVM.pendingDeletePatch != nil },
            set: { if !$0 { patchVM.pendingDeletePatch = nil } }
        )) {
            Button("Delete", role: .destructive) { patchVM.confirmDeletePatch() }
            Button("Cancel", role: .cancel) { patchVM.pendingDeletePatch = nil }
        } message: {
            let inSets = patchVM.pendingDeletePatch.map { patch in
                patchVM.document.sets.contains { $0.patchIDs.contains(patch.id) }
            } ?? false
            Text(inSets
                 ? "This patch will also be removed from the sets that include it. You can undo this from the Edit menu."
                 : "You can undo this from the Edit menu.")
        }
        .unsavedChangesAlert(
            isPresented: patchVM.pendingPatchSelectionID != nil,
            save: { patchVM.confirmSelectionChange(save: true) },
            discard: { patchVM.confirmSelectionChange(save: false) },
            cancel: { patchVM.cancelSelectionChange() }
        )
        .unsavedChangesAlert(
            isPresented: editorVM.pendingModuleSelection != nil,
            save: { editorVM.confirmSelectionChange(save: true) },
            discard: { editorVM.confirmSelectionChange(save: false) },
            cancel: { editorVM.cancelSelectionChange() }
        )
        .unsavedChangesAlert(
            isPresented: pendingModeChange != nil,
            message: "You have unsaved changes. Save or discard before switching modes?",
            save: { finishModeChange(save: true) },
            discard: { finishModeChange(save: false) },
            cancel: { pendingModeChange = nil }
        )
        .alert("Save Changes?", isPresented: Binding(
            get: { inUseSaveConfirmation != nil },
            set: { if !$0 { inUseSaveConfirmation = nil } }
        )) {
            Button("Save Anyway", role: .destructive) {
                if let confirmation = inUseSaveConfirmation {
                    switchMode(to: confirmation.mode, save: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text(inUseSaveConfirmation?.message ?? "") }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                autosave()
            }
        }
        // Saves periodically so committed changes survive a crash and reach other
        // devices without waiting for the app to deactivate
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                autosave()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            autosave()
            rackVM.saveCanvasState()
            patchVM.flushDeferredMediaDeletions()
        }
        .onAppear {
            undoManager?.groupsByEvent = false
            editorVM.undoManager = undoManager
            rackVM.undoManager   = undoManager
            patchVM.undoManager  = undoManager
            setVM.undoManager    = undoManager
        }
        .focusedSceneValue(\.switchMode) { requestModeChange($0) }
        .modifier(FocusedAppState(
            editorVM: editorVM,
            rackVM: rackVM,
            patchVM: patchVM,
            setVM: setVM
        ))
        .navigationTitle("")
        .background(WindowTitleHider().frame(width: 0, height: 0))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: modeBinding) {
                    ForEach(AppMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }

    /// Saves the library, keeping the last committed state of any item being edited.
    private func autosave() {
        documentManager.autosave(adjusting: EditSession.committedState(of: [editorVM, rackVM, patchVM]))
    }

    private var modeBinding: Binding<AppMode> {
        Binding(get: { selectedSidebarItem }, set: { requestModeChange($0) })
    }

    /// Saves or discards edits in every editor, then switches to the pending mode. Saving
    /// edits to a module or rack that is in use asks for confirmation first, as Save does.
    private func finishModeChange(save: Bool) {
        guard let mode = pendingModeChange else { return }
        pendingModeChange = nil
        let warnings = save ? [editorVM.inUseWarning, rackVM.inUseWarning].compactMap { $0 } : []
        if warnings.isEmpty {
            switchMode(to: mode, save: save)
        } else {
            inUseSaveConfirmation = InUseSaveConfirmation(mode: mode, message: warnings.joined(separator: "\n\n"))
        }
    }

    private func switchMode(to mode: AppMode, save: Bool) {
        let editors: [any EditCommitting] = [editorVM, rackVM, patchVM]
        for editor in editors {
            if save { editor.commitEditing() } else { editor.discardEditing() }
        }
        selectedSidebarItem = mode
    }

    /// Switches mode, first asking to save or discard any uncommitted edits.
    private func requestModeChange(_ newMode: AppMode) {
        guard newMode != selectedSidebarItem else { return }
        if editorVM.isEditing || rackVM.isEditing || patchVM.isEditing {
            pendingModeChange = newMode
        } else {
            selectedSidebarItem = newMode
        }
    }

    @ViewBuilder private var rackPatchSetListPanel: some View {
        ZStack {
            RackListView(rackVM: rackVM)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedSidebarItem == .racks ? 1 : 0)
                .allowsHitTesting(selectedSidebarItem == .racks)
            PatchListView(patchVM: patchVM)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedSidebarItem == .patches ? 1 : 0)
                .allowsHitTesting(selectedSidebarItem == .patches)
            PatchSetListView(setVM: setVM, patchVM: patchVM)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(selectedSidebarItem == .sets ? 1 : 0)
                .allowsHitTesting(selectedSidebarItem == .sets)
        }
    }

    @ViewBuilder private var rackPatchSetDetailPanel: some View {
        if selectedSidebarItem == .sets {
            PatchSetView(rackVM: rackVM, patchVM: patchVM, setVM: setVM)
        } else {
            // .racks and .patches both land here — same structural position,
            // so SwiftUI updates showCables in-place rather than recreating the view.
            RackView(rackVM: rackVM, patchVM: patchVM, showCables: selectedSidebarItem == .patches)
        }
    }
}
