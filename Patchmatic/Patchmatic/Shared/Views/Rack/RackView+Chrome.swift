import SwiftUI

// Context menu, overlays and toolbar around the rack canvas
extension RackView {
    /// Right-click menu for the canvas background
    @ViewBuilder var canvasContextMenu: some View {
        if !readOnly, !showCables {
            Button {
                rackVM.addCase()
            } label: {
                Label("New Case", systemImage: "shippingbox")
            }
        }
        if !readOnly, showCables, patchVM.canPasteCables {
            Button("Paste Cables") {
                patchVM.pasteCables()
            }
        }
        if !readOnly, showCables, let patch = patchVM.activePatch, !patch.cables.isEmpty {
            Menu("Delete Cable") {
                ForEach(patch.cables) { cable in
                    Button(patchVM.cableDescription(cable)) {
                        patchVM.deleteCable(cable)
                    }
                }
            }
        }
        if !readOnly, showCables {
            Button {
                patchVM.showingPatchNotesSheet = true
            } label: {
                Label("Patch Notes\u{2026}", systemImage: "doc.text")
            }
        }
    }

    /// Floating list of the patch's module groups, when groups are shown
    @ViewBuilder var groupListOverlay: some View {
        if showCables, patchVM.showGroups,
           let patch = patchVM.activePatch, !patch.moduleGroups.isEmpty {
            FloatingGroupList(
                groups: patch.moduleGroups,
                patchVM: patchVM,
                readOnly: readOnly,
                onEditNotes: { group in
                    editingGroupForNotes = group
                },
                onRenameGroup: { group in
                    renameGroupText = group.name
                    renamingGroupID = group.id
                },
                onDeleteGroup: { groupID in
                    patchVM.deleteGroup(groupID)
                },
                onFocusGroup: { group in
                    focusOnModules(group.placedModuleIDs)
                }
            )
            .padding(8)
        }
    }

    /// The patch's notes and audio preview, when patch notes are shown
    @ViewBuilder var patchNotesOverlay: some View {
        if showCables, patchVM.showPatchNotes, let patch = patchVM.activePatch,
           !patch.patchNotes.isEmpty || patch.audioPreviewFilename != nil {
            PatchNotesOverlay(
                patch: patch,
                patchVM: patchVM,
                readOnly: readOnly,
                onEdit: { patchVM.showingPatchNotesSheet = true }
            )
            .padding(8)
        }
    }

    /// Enlarged view of a clicked screen control
    @ViewBuilder var magnifierOverlay: some View {
        if let info = magnifierInfo {
            let anchor = viewportFrame.size.width > 0
                ? UnitPoint(
                    x: info.controlViewportRect.midX / viewportFrame.size.width,
                    y: info.controlViewportRect.midY / viewportFrame.size.height
                  )
                : UnitPoint.center
            ScreenMagnifierView(
                info: info,
                onAddScreenImage: readOnly ? nil : { moduleID, controlID in
                    openScreenImagePicker(moduleID: moduleID, controlID: controlID)
                },
                onRemoveScreenImage: readOnly ? nil : { moduleID, controlID in
                    guard let si = patchVM.activePatch?.screenImage(forModule: moduleID, control: controlID),
                          !si.imageFilenames.isEmpty else { return }
                    patchVM.removeScreenImageFile(moduleID: moduleID, controlID: controlID, at: si.activeIndex)
                },
                onDismiss: {
                    magnifierInfo = nil
                    magnifiedScreen = nil
                },
                patchVM: patchVM
            )
            .transition(.scale(scale: 0.88, anchor: anchor).combined(with: .opacity))
        }
    }

    @ToolbarContentBuilder var canvasToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if !readOnly, !showCables {
                ControlGroup {
                    Button {
                        rackVM.addCase()
                    } label: {
                        Label("New Case", systemImage: "shippingbox")
                    }
                    .help("New Case")
                }
            }

            ControlGroup {
                Toggle(isOn: $rackVM.showLabels) {
                    Label("Labels", systemImage: "tag")
                }
                .help("Toggle control labels")

                if showCables {
                    Toggle(isOn: $patchVM.showGroups) {
                        Label("Groups", systemImage: "rectangle.3.group")
                    }
                    .help("Toggle group overlays")

                    Toggle(isOn: $rackVM.showPatchNumbers) {
                        Label("Numbers", systemImage: "1.circle")
                    }
                    .help("Toggle patch point numbers")

                    Toggle(isOn: $patchVM.showPatchNotes) {
                        Label("Notes", systemImage: "note.text")
                    }
                    .help("Toggle patch notes overlay")
                }
            }

            ControlGroup {
        #if os(macOS)
                Button {
                    zoom(by: RackViewModel.zoomStep)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .help("Zoom In")

                Button {
                    zoom(by: 1 / RackViewModel.zoomStep)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .help("Zoom Out")
        #endif

                Button {
                    frameRack()
                } label: {
                    Image(systemName: "1.magnifyingglass")
                }
                .help("Frame Rack")
            }

        #if os(macOS)
            ControlGroup {
                Slider(value: $rackVM.backgroundImageOpacity, in: 0...1)
                    .frame(width: 80)
                    .help("Image Opacity")
                    .padding(.horizontal, 4)
            }
        #else
            DisplayOptionsButton(rackVM: rackVM)
        #endif

        }
    }
}
