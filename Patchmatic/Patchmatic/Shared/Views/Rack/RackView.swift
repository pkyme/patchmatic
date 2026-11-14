import SwiftUI
import UniformTypeIdentifiers

struct ScreenCropRequest: Identifiable {
    let id = UUID()
    var moduleID: UUID
    var controlID: UUID
    var sourceImage: PlatformImage
    var aspectRatio: Double
}

struct RackView: View {
    @Bindable var rackVM: RackViewModel
    @Bindable var patchVM: PatchViewModel
    var showCables: Bool
    var readOnly: Bool = false

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.displayScale) var displayScale
    @Environment(\.scenePhase) var scenePhase
    @State var eventMonitors = RackEventMonitors()
    @State var gesture = RackGestureState()
    @FocusState var canvasFocused: Bool
    var currentZoom: CGFloat {
        get { rackVM.canvasZoom }
        nonmutating set { rackVM.canvasZoom = newValue }
    }
    var lastZoom: CGFloat {
        get { rackVM.canvasLastZoom }
        nonmutating set { rackVM.canvasLastZoom = newValue }
    }
    var panOffset: CGSize {
        get { rackVM.canvasPanOffset }
        nonmutating set { rackVM.canvasPanOffset = newValue }
    }
    var lastPanOffset: CGSize {
        get { rackVM.canvasLastPanOffset }
        nonmutating set { rackVM.canvasLastPanOffset = newValue }
    }
    @State var viewportFrame: CGRect = .zero
    /// Render-only transform animated back to identity after a framing change,
    /// so the whole rack moves as one image instead of each layer re-laying out.
    @State var framingScale: CGFloat = 1
    @State var framingOffset: CGSize = .zero
    @State var screenCropRequest: ScreenCropRequest?
    @State var magnifierInfo: ScreenMagnifierInfo?
    @State var magnifiedScreen: (moduleID: UUID, controlID: UUID)? = nil
    @State var editingNote: ModuleNote? = nil
    @State var isNewNote: Bool = false
    @State var hoverAnimator = HoverAnimator()
    @State var cableHover = CableHoverState()
    @State var editingGroupForNotes: ModuleGroup? = nil
    @State var renamingGroupID: UUID? = nil
    @State var renameGroupText: String = ""
    @State var creatingGroupForModuleIDs: Set<UUID>? = nil

    var body: some View {
        let isDark = colorScheme == .dark

        if showCables && patchVM.activePatch == nil {
            ContentUnavailableView("No Patch Selected",
                                   systemImage: "cable.connector",
                                   description: Text("Select or create a patch."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let rack = rackVM.rack {
            VStack(spacing: 0) {
            canvas(rack: rack, isDark: isDark)

            #if os(macOS)
            if !readOnly, !showCables {
                ModuleStripView(rackVM: rackVM)
            }
            #endif
            }
            #if os(macOS)
            .sheet(item: $screenCropRequest) { request in
                ScreenImageCropView(sourceImage: request.sourceImage, aspectRatio: request.aspectRatio) { croppedImage in
                    guard let patch = patchVM.activePatch else { screenCropRequest = nil; return }
                    let filename = ImageStore.makeScreenFilename(patchID: patch.id, placedModuleID: request.moduleID, controlID: request.controlID)
                    if ImageStore.save(croppedImage, filename: filename) {
                        patchVM.addScreenImageFile(moduleID: request.moduleID, controlID: request.controlID, filename: filename)
                    }
                    screenCropRequest = nil
                }
            }
            #endif
            .sheet(item: $editingNote) { note in
                noteEditor(for: note)
            }
            .alert("Rename Group", isPresented: Binding(
                get: { renamingGroupID != nil },
                set: { if !$0 { renamingGroupID = nil } }
            )) {
                TextField("Group Name", text: $renameGroupText)
                Button("Rename") {
                    if let id = renamingGroupID {
                        patchVM.renameGroup(id, to: renameGroupText)
                    }
                    renamingGroupID = nil
                }
                Button("Cancel", role: .cancel) { renamingGroupID = nil }
            }
            .sheet(isPresented: Binding(
                get: { creatingGroupForModuleIDs != nil },
                set: { if !$0 { creatingGroupForModuleIDs = nil } }
            )) {
                NewGroupEditor(
                    onCreate: { name, notes in
                        if let ids = creatingGroupForModuleIDs {
                            patchVM.addGroup(name: name, notes: notes, moduleIDs: Array(ids))
                        }
                        creatingGroupForModuleIDs = nil
                    },
                    onCancel: { creatingGroupForModuleIDs = nil }
                )
            }
            .sheet(item: $editingGroupForNotes) { group in
                GroupNotesEditor(group: group, patchVM: patchVM)
            }
            .sheet(isPresented: Binding(
                get: { showCables && patchVM.showingPatchNotesSheet },
                set: { patchVM.showingPatchNotesSheet = $0 }
            )) {
                PatchNotesSheet(patchVM: patchVM, readOnly: readOnly) {
                    patchVM.showingPatchNotesSheet = false
                }
            }
            #if os(macOS)
            .focusedSceneValue(\.printPatch, showCables ? { printPatch() } : nil)
            #endif
        } else {
            ContentUnavailableView("No Rack Selected",
                                   systemImage: "rectangle.split.3x1",
                                   description: Text("Select a rack from the sidebar."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    #if os(macOS)
    private func printPatch() {
        guard let patch = patchVM.activePatch,
              let rack = rackVM.document.rack(for: patch.rackID) else { return }
        PatchPrinter.print(
            rack: rack,
            patch: patch,
            rackVM: rackVM,
            patchVM: patchVM,
            isDarkMode: colorScheme == .dark,
            showPatchNumbers: rackVM.showPatchNumbers
        )
    }
    #endif

    /// The zoomable rack canvas with its gestures, overlays and edit controls
    @ViewBuilder
    func canvas(rack: Rack, isDark: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if !showCables {
                    RackGridBackground(panOffset: panOffset, zoom: currentZoom)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(x: -panOffset.width, y: -panOffset.height)
                        .allowsHitTesting(false)
                }

                Color.clear

                ForEach(rack.cases) { rackCase in
                    makeCaseView(rackCase, isDark: isDark)
                        .offset(
                            x: rackCase.positionX * currentZoom,
                            y: rackCase.positionY * currentZoom - rackVM.caseHeaderHeight
                        )
                }

                if showCables {
                    PatchCableOverlay(rackVM: rackVM, patchVM: patchVM, zoom: currentZoom, cableHover: cableHover)
                }

                // Ghost of the module being dragged
                ModuleDragGhost(rackVM: rackVM, showCables: showCables, zoom: currentZoom)

                // Marquee selection rectangle
                MarqueeOverlay(rect: rackVM.marqueeRect, zoom: currentZoom)

                // Ghost for new module being dragged from library strip
                if let definition = rackVM.newModuleDragDefinition,
                   let point = rackVM.newModuleDragScreenPoint {
                    let w = EurorackConstants.width(forHP: definition.widthHP)
                    ModulePanelView(
                        definition: definition,
                        panelHeight: definition.panelHeight,
                        knobValues: [:],
                        zoom: currentZoom
                    )
                    .opacity(0.5)
                    .offset(
                        x: point.x - panOffset.width - w * currentZoom / 2,
                        y: point.y - panOffset.height - definition.panelHeight * currentZoom / 2
                    )
                    .allowsHitTesting(false)
                }
            }
            .overlayPreferenceValue(NoteTooltipPreferenceKey.self) { pref in
                GeometryReader { geo in
                    if let data = pref {
                        let frame = geo[data.anchor]
                        ZStack(alignment: .topLeading) {
                            Color.clear
                            Text(data.text)
                                .font(.body)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                                .fixedSize(horizontal: true, vertical: true)
                                .offset(x: frame.maxX + 4, y: frame.minY)
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
            .offset(panOffset)
            .scaleEffect(framingScale, anchor: .topLeading)
            .offset(framingOffset)
            .contentShape(Rectangle())
            .gesture(readOnly ?
                // Read-only mode: only allow panning
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        handleReadOnlyDragChanged(value)
                    }
                    .onEnded { value in
                        handleReadOnlyDragEnded(value)
                    }
                :
                // Normal mode: allow all interactions
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if showCables {
                            handleCableDragChanged(value)
                        } else {
                            handleModuleDragChanged(value)
                        }
                    }
                    .onEnded { value in
                        if showCables {
                            handleCableDragEnded(value)
                        } else {
                            handleModuleDragEnded(value)
                        }
                    }
            )
            .contextMenu {
                canvasContextMenu
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    if showCables {
                        cableHover.update(worldPoint: scaledPoint(location), geometry: cableGeometry)
                    }
                    if showCables, patchVM.showGroups {
                        let worldPt = scaledPoint(location)
                        if let placed = rackVM.placedModule(at: worldPt) {
                            let groups = patchVM.groupOverlays(forModule: placed.id)
                            let ids = Set(groups.map { $0.groupID })
                            if ids != patchVM.moduleHoverGroupIDs {
                                patchVM.moduleHoverGroupIDs = ids
                            }
                        } else if !patchVM.moduleHoverGroupIDs.isEmpty {
                            patchVM.moduleHoverGroupIDs = []
                        }
                    }
                case .ended:
                    cableHover.update(worldPoint: nil, geometry: nil)
                    if !patchVM.moduleHoverGroupIDs.isEmpty {
                        patchVM.moduleHoverGroupIDs = []
                    }
                @unknown default:
                    break
                }
            }
            .onDrop(of: readOnly ? [] : [.text], delegate: ModuleDropDelegate(rackVM: rackVM, zoom: currentZoom, panOffset: panOffset))
        }
        .clipped()
        .overlay(alignment: .topTrailing) {
            groupListOverlay
        }
        .overlay(alignment: .topLeading) {
            patchNotesOverlay
        }
        .overlay(alignment: .topLeading) {
            magnifierOverlay
        }
        .animation(.spring(duration: 0.18), value: magnifierInfo != nil)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { viewportFrame = proxy.frame(in: .global) }
                    .onChange(of: proxy.size) { _, _ in
                        viewportFrame = proxy.frame(in: .global)
                    }
            }
        }
        #if os(iOS)
        // Fit the rack whenever the viewport resizes (rotation, sidebar) or the rack changes.
        // Resizes while inactive (app switcher snapshots) apply without animation.
        .onChange(of: viewportFrame.size) { _, _ in frameRack(animated: scenePhase == .active) }
        .onChange(of: rackVM.document.activeRackID) { _, _ in frameRack() }
        #endif
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    let newZoom = RackViewModel.clampedZoom(lastZoom * value.magnification)
                    adjustPanForZoom(newZoom: newZoom)
                    currentZoom = newZoom
                }
                .onEnded { value in
                    lastZoom = currentZoom
                }
        )
        #if os(macOS)
        .onAppear {
            installEventMonitors()
        }
        .onChange(of: showCables) { _, _ in updateEventMonitorState() }
        .onChange(of: readOnly) { _, _ in updateEventMonitorState() }
        .onChange(of: colorScheme) { _, _ in updateEventMonitorState() }
        .onChange(of: viewportFrame) { _, _ in updateEventMonitorState() }
        .onDisappear {
            eventMonitors.removeMonitors()
        }
        #endif
        .focusable()
        .focused($canvasFocused)
        // Case headers are hidden in patch mode; CaseView reports their height when shown
        .onChange(of: showCables, initial: true) { _, isPatchMode in
            if isPatchMode { rackVM.caseHeaderHeight = 0 }
        }
        .focusEffectDisabled()
        #if os(macOS)
        .onDeleteCommand {
            guard !readOnly else { return }
            if showCables {
                if patchVM.selectedPinID != nil {
                    patchVM.deleteSelectedPin()
                    return
                }
                guard !patchVM.selectedCableIDs.isEmpty else { return }
                patchVM.deleteSelectedCables()
            } else {
                guard !rackVM.selectedPlacedModuleIDs.isEmpty || !rackVM.selectedCaseIDs.isEmpty else { return }
                rackVM.deleteSelection()
            }
        }
        #endif
        .modifier(RackKeyboardShortcuts(rackVM: rackVM, patchVM: patchVM, showCables: showCables, readOnly: readOnly))
        .toolbar {
            canvasToolbar
        }
        #if os(macOS)
        .focusedSceneValue(\.zoomIn) {
            self.zoom(by: RackViewModel.zoomStep)
        }
        .focusedSceneValue(\.zoomOut) {
            self.zoom(by: 1 / RackViewModel.zoomStep)
        }
        .focusedSceneValue(\.frameContent) {
            self.frameRack()
        }
        #endif
        .overlay(alignment: .bottom) {
            if !readOnly, !showCables, rackVM.isEditing {
                EditConfirmationToolbar(
                    onSave: { rackVM.requestCommit() },
                    onDiscard: { rackVM.discardEditing() }
                )
                .padding(.bottom, 16)
            }
        }
        .alert("Rack In Use", isPresented: $rackVM.pendingSaveConfirmation) {
            Button("Save Anyway", role: .destructive) { rackVM.commitEditing() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(rackVM.inUseWarning ?? "")
        }
    }

    @ViewBuilder
    func makeCaseView(_ rackCase: Case, isDark: Bool) -> some View {
        CaseView(
            rackCase: rackCase,
            rackVM: rackVM,
            patchVM: patchVM,
            showKnobValues: showCables,
            labelsIgnoreActivation: showCables && !readOnly,
            isDarkMode: isDark,
            zoom: currentZoom,
            actions: rackRowActions,
            pressedControlID: gesture.pressedControlID,
            hoverAnimator: hoverAnimator,
            readOnly: readOnly
        )
    }

    /// What module panels can do in the current mode; editing actions are off when read-only.
    var rackRowActions: RackRowActions {
        RackRowActions(
            addScreenImage: readOnly ? nil : { moduleID, controlID in
                openScreenImagePicker(moduleID: moduleID, controlID: controlID)
            },
            removeScreenImage: readOnly ? nil : { moduleID, controlID in
                guard let si = patchVM.activePatch?.screenImage(forModule: moduleID, control: controlID),
                      !si.imageFilenames.isEmpty else { return }
                patchVM.removeScreenImageFile(moduleID: moduleID, controlID: controlID, at: si.activeIndex)
            },
            zoomScreenImage: { moduleID, controlID in
                showMagnifier(for: moduleID, controlID: controlID)
            },
            addNote: readOnly ? nil : { moduleID, position in
                patchVM.addNote(forModule: moduleID, at: position)
                editingNote = patchVM.notes(forModule: moduleID).last
                isNewNote = true
            },
            editNote: readOnly ? nil : { _, note in
                editingNote = note
                isNewNote = false
            },
            addPatchPointNote: readOnly ? nil : { moduleID, controlID in
                patchVM.addPatchPointNote(forModule: moduleID, controlID: controlID)
                editingNote = patchVM.patchPointNote(forModule: moduleID, controlID: controlID)
                isNewNote = true
            },
            hoverControl: showCables ? { moduleID, controlID in
                if let moduleID, let controlID {
                    hoverAnimator.hoverIn(moduleID: moduleID, controlID: controlID)
                } else {
                    hoverAnimator.hoverOut()
                }
            } : nil,
            createGroup: { moduleIDs in
                creatingGroupForModuleIDs = moduleIDs
            }
        )
    }

    func updateEventMonitorState() {
        eventMonitors.showCables = showCables
        eventMonitors.readOnly = readOnly
        eventMonitors.isDarkMode = colorScheme == .dark
        eventMonitors.viewportFrame = viewportFrame
    }

    var cableGeometry: CableGeometry? {
        CableGeometry(rackVM: rackVM, patchVM: patchVM)
    }
}

/// AppKit event monitors for scroll-wheel zoom and right-click menus on the rack canvas.
/// The monitor closures outlive any one view value, so the view state they read is kept
/// here and updated as it changes.
@MainActor
final class RackEventMonitors {
    var scrollMonitor: Any?
    var rightClickMonitor: Any?
    var showCables = false
    var readOnly = false
    var isDarkMode = false
    var viewportFrame: CGRect = .zero

    func removeMonitors() {
        #if os(macOS)
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        if let rightClickMonitor { NSEvent.removeMonitor(rightClickMonitor) }
        #endif
        scrollMonitor = nil
        rightClickMonitor = nil
    }

    isolated deinit { removeMonitors() }
}
