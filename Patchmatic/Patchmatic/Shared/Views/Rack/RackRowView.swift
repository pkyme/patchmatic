import SwiftUI

struct RackRowView: View {
    var rackCase: Case
    var rowIndex: Int
    var rowHeight: CGFloat
    var rackVM: RackViewModel
    var patchVM: PatchViewModel
    var showKnobValues: Bool
    var labelsIgnoreActivation: Bool = false
    var isDarkMode: Bool = false
    var zoom: CGFloat = 1.0
    var actions = RackRowActions()
    var pressedControlID: UUID? = nil
    /// Hovered control highlight; nil where controls don't highlight on hover
    var hoverAnimator: HoverAnimator? = nil
    var readOnly: Bool = false

    @State private var moduleHoverPos: [UUID: NormalizedPoint] = [:]
    @State private var moduleHoverControl: [UUID: Control] = [:]
    /// Hovered screens, keyed by placed module and control since module definitions share control IDs
    @State private var screenHovered: Set<PatchPointKey> = []

    private static func loadImage(for definition: ModuleDefinition) -> CGImage? {
        guard let filename = definition.imageFileName,
              let img = ImageStore.load(filename) else { return nil }
        return img.platformCGImage
    }

    var body: some View {
        let rowWidth = EurorackConstants.width(forHP: rackCase.rowWidthHP) * zoom
        let modules = rackCase.modules(inRow: rowIndex)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(.tertiary)
                .frame(width: rowWidth, height: rowHeight)
                .opacity(showKnobValues ? 0 : 1)

            // Drop indicator
            if let indicator = rackVM.dropIndicator,
               indicator.caseID == rackCase.id,
               indicator.rowIndex == rowIndex {
                RoundedRectangle(cornerRadius: 4 * zoom)
                    .fill(Color.accentColor.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4 * zoom)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2 * zoom, dash: [6, 4]))
                    )
                    .frame(
                        width: EurorackConstants.width(forHP: indicator.widthHP) * zoom,
                        height: rowHeight
                    )
                    .offset(x: CGFloat(indicator.positionHP) * EurorackConstants.pointsPerHP * zoom)
            }

            ForEach(modules) { placed in
                if let definition = rackVM.document.moduleDefinition(for: placed.moduleDefinitionID) {
                    let isDragging = rackVM.moduleDragID == placed.id || rackVM.multiDragIDs.contains(placed.id)
                    let bgImage: CGImage? = rackVM.backgroundImageOpacity > 0 ? Self.loadImage(for: definition) : nil
                    ModulePanelView(
                        definition: definition,
                        panelHeight: definition.panelHeight,
                        knobValues: showKnobValues ? patchVM.knobValuesMap(forModule: placed.id) : [:],
                        patchPointColors: showKnobValues ? patchVM.patchPointColors(forModule: placed.id, isDarkMode: isDarkMode) : [:],
                        activatedControlIDs: showKnobValues && patchVM.activePatch != nil ? patchVM.activatedControlIDs(forModule: placed.id) : nil,
                        backgroundImage: bgImage,
                        backgroundImageOpacity: rackVM.backgroundImageOpacity,
                        showLabels: rackVM.showLabels,
                        labelsIgnoreActivation: labelsIgnoreActivation,
                        zoom: zoom,
                        screenImages: showKnobValues ? patchVM.screenImagesMap(forModule: placed.id) : [:],
                        pressedControlID: pressedControlID,
                        hoveredControlID: hoverAnimator?.moduleID == placed.id ? hoverAnimator?.controlID : nil,
                        hoveredControlBrightness: hoverAnimator?.brightness(forModule: placed.id) ?? 0,
                    )
                    .opacity(isDragging ? 0.3 : 1.0)
                    .onContinuousHover { phase in
                        if showKnobValues {
                            switch phase {
                            case .active(let location):
                                let pw = EurorackConstants.width(forHP: definition.widthHP) * zoom
                                let ph = definition.panelHeight * zoom
                                moduleHoverPos[placed.id] = NormalizedPoint(
                                    x: Double(location.x / pw),
                                    y: Double(location.y / ph)
                                )
                                let panelSize = CGSize(width: pw, height: ph)
                                let hit = definition.controls.first {
                                    $0.hitTest(point: location, in: panelSize, zoom: zoom, padding: Control.hitPadding * zoom)
                                }
                                moduleHoverControl[placed.id] = hit
                                actions.hoverControl?(placed.id, hit?.id)
                            case .ended:
                                actions.hoverControl?(nil, nil)
                            }
                        }
                    }
                    .contextMenu {
                        if showKnobValues, let addNote = actions.addNote {
                            if let control = moduleHoverControl[placed.id],
                               control.kind == .patchPoint {
                                if patchVM.patchPointNote(forModule: placed.id, controlID: control.id) == nil {
                                    Button("Add Patch Point Note") {
                                        actions.addPatchPointNote?(placed.id, control.id)
                                    }
                                } else if let existing = patchVM.patchPointNote(forModule: placed.id, controlID: control.id) {
                                    Button("Edit Patch Point Note") {
                                        actions.editNote?(placed.id, existing)
                                    }
                                }
                            } else {
                                Button("Add Note") {
                                    let pos = moduleHoverPos[placed.id] ?? NormalizedPoint(x: 0.5, y: 0.5)
                                    addNote(placed.id, pos)
                                }
                            }
                        }
                        if showKnobValues, patchVM.showGroups, !readOnly {
                            let selectedIDs = rackVM.effectiveGroupSelection(for: placed.id)
                            let moduleCount = selectedIDs.count
                            let label = moduleCount == 1 ? definition.name : "\(moduleCount) Modules"
                            Divider()
                            Button("New Group with \(label)") {
                                actions.createGroup?(selectedIDs)
                            }
                            if let patch = patchVM.activePatch, !patch.moduleGroups.isEmpty {
                                Menu("Add to Group") {
                                    ForEach(patch.moduleGroups) { group in
                                        Button(group.name) {
                                            patchVM.addModulesToGroup(moduleIDs: selectedIDs, groupID: group.id)
                                        }
                                    }
                                }
                                let containingGroups = patchVM.groupsContainingAny(of: selectedIDs)
                                if !containingGroups.isEmpty {
                                    Menu("Remove from Group") {
                                        ForEach(containingGroups) { group in
                                            Button(group.name) {
                                                patchVM.removeModulesFromGroup(moduleIDs: selectedIDs, groupID: group.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .overlay {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 4 * zoom)
                                .stroke(Color.accentColor, lineWidth: 2 * zoom)
                                .opacity((!showKnobValues || patchVM.showGroups) && rackVM.selectedPlacedModuleIDs.contains(placed.id) ? 1 : 0)

                            if showKnobValues, patchVM.showGroups {
                                let groups = patchVM.groupOverlays(forModule: placed.id)
                                let isHighlighting = !patchVM.hoveredGroupIDs.isEmpty
                                let belongsToHovered = groups.contains { patchVM.hoveredGroupIDs.contains($0.groupID) }

                                if !groups.isEmpty {
                                    if isHighlighting && belongsToHovered {
                                        // Show only the hovered group colors
                                        let hoveredGroups = groups.filter { patchVM.hoveredGroupIDs.contains($0.groupID) }
                                        if hoveredGroups.count == 1 {
                                            RoundedRectangle(cornerRadius: 4 * zoom)
                                                .fill(GroupPalette.color(forIndex: hoveredGroups[0].colorIndex).opacity(0.2))
                                                .allowsHitTesting(false)
                                        } else {
                                            GroupStripeOverlay(
                                                groups: hoveredGroups,
                                                hoveredGroupIDs: patchVM.hoveredGroupIDs,
                                                cornerRadius: 4 * zoom
                                            )
                                            .allowsHitTesting(false)
                                        }
                                    } else {
                                        GroupStripeOverlay(
                                            groups: groups,
                                            hoveredGroupIDs: patchVM.hoveredGroupIDs,
                                            cornerRadius: 4 * zoom
                                        )
                                        .allowsHitTesting(false)
                                    }
                                }

                                // Fade out modules not in the hovered group
                                if isHighlighting && !belongsToHovered {
                                    RoundedRectangle(cornerRadius: 4 * zoom)
                                        .fill((isDarkMode ? Color.black : Color.white).opacity(0.25))
                                        .allowsHitTesting(false)
                                }
                            } else if !patchVM.hoveredGroupIDs.isEmpty {
                                // Module has no groups — fade out when a group is hovered
                                RoundedRectangle(cornerRadius: 4 * zoom)
                                    .fill((isDarkMode ? Color.black : Color.white).opacity(0.25))
                                    .allowsHitTesting(false)
                            }

                            if showKnobValues {
                                let panelSize = CGSize(
                                    width: EurorackConstants.width(forHP: definition.widthHP) * zoom,
                                    height: definition.panelHeight * zoom
                                )

                                ForEach(definition.controls.filter { $0.kind == .screen }) { control in
                                    let rect = control.screenRect(in: panelSize, zoom: zoom)
                                    let screenImage = patchVM.activePatch?.screenImage(forModule: placed.id, control: control.id)
                                    let hasImages = screenImage != nil && !screenImage!.imageFilenames.isEmpty
                                    let canCycle = screenImage?.imageFilenames.count ?? 0 > 1

                                    ZStack {
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .overlay {
                                                VStack {
                                                    Spacer()
                                                    HoverScreenToolbar(externalHover: screenHovered.contains(PatchPointKey(moduleID: placed.id, controlID: control.id))) {
                                                        ScreenToolbarView(
                                                            screenWidth: rect.width,
                                                            zoom: zoom,
                                                            hasImages: hasImages,
                                                            canCycle: canCycle,
                                                            zoomIconName: "plus.magnifyingglass",
                                                            readOnly: actions.addScreenImage == nil,
                                                            onAddImage: {
                                                                actions.addScreenImage?(placed.id, control.id)
                                                            },
                                                            onDeleteImage: {
                                                                actions.removeScreenImage?(placed.id, control.id)
                                                            },
                                                            onZoomImage: {
                                                                actions.zoomScreenImage?(placed.id, control.id)
                                                            },
                                                            onCycleImage: {
                                                                patchVM.cycleScreenImage(moduleID: placed.id, controlID: control.id)
                                                            }
                                                        )
                                                    }
                                                    .padding(.bottom, 4 * zoom)
                                                }
                                            }
                                    }
                                    .frame(width: rect.width, height: rect.height)
                                    .onHover { hovering in
                                        let key = PatchPointKey(moduleID: placed.id, controlID: control.id)
                                        if hovering { screenHovered.insert(key) } else { screenHovered.remove(key) }
                                    }
                                    .position(x: rect.midX, y: rect.midY)
                                }

                                noteOverlays(placed: placed, definition: definition, panelSize: panelSize)

                            }
                        }
                    }
                    .offset(x: CGFloat(displayedPosition(of: placed)) * EurorackConstants.pointsPerHP * zoom)
                    .animation(.easeOut(duration: 0.15), value: displayedPosition(of: placed))
                }
            }
        }
        .frame(width: rowWidth, height: rowHeight)
    }

    /// Row position of a module, including any temporary shift to make room for a module being dragged
    private func displayedPosition(of placed: PlacedModule) -> Int {
        if let indicator = rackVM.dropIndicator,
           indicator.caseID == rackCase.id,
           indicator.rowIndex == rowIndex,
           let position = indicator.displacedPositions[placed.id] {
            return position
        }
        return placed.positionInRow
    }

    @ViewBuilder
    private func noteOverlays(placed: PlacedModule, definition: ModuleDefinition, panelSize: CGSize) -> some View {
        // Free-form note icons
        ForEach(patchVM.notes(forModule: placed.id).filter { $0.controlID == nil }) { note in
            NoteIcon(
                note: note,
                panelSize: panelSize,
                zoom: zoom,
                onTap: actions.editNote == nil ? nil : {
                    actions.editNote?(placed.id, note)
                }
            )
            .position(
                x: note.position.x * panelSize.width,
                y: note.position.y * panelSize.height
            )
        }

        // Patch point note indicators
        ForEach(patchVM.notes(forModule: placed.id).filter { $0.controlID != nil }) { note in
            if let control = definition.controls.first(where: { $0.id == note.controlID }) {
                let isHovered = hoverAnimator?.moduleID == placed.id && hoverAnimator?.controlID == control.id
                PatchPointNoteIndicator(
                    note: note,
                    control: control,
                    panelSize: panelSize,
                    zoom: zoom
                )
                .anchorPreference(key: NoteTooltipPreferenceKey.self, value: .bounds) { anchor in
                    isHovered && !note.text.isEmpty
                        ? NoteTooltipData(text: note.text, anchor: anchor) : nil
                }
                .position(
                    x: control.position.x * panelSize.width,
                    y: control.position.y * panelSize.height
                )
            }
        }
    }
}

// MARK: - Group stripe overlay

private struct GroupStripeOverlay: View {
    let groups: [(groupID: UUID, colorIndex: Int, name: String)]
    let hoveredGroupIDs: Set<UUID>
    let cornerRadius: CGFloat

    var body: some View {
        if groups.count == 1 {
            let g = groups[0]
            let highlighted = hoveredGroupIDs.contains(g.groupID)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(GroupPalette.color(forIndex: g.colorIndex).opacity(highlighted ? 0.2 : 0.125))
                .animation(.easeInOut(duration: 0.15), value: highlighted)
        } else {
            Canvas { context, size in
                let stripeWidth: CGFloat = 12
                let count = groups.count
                let totalDiag = size.width + size.height
                let stripeCount = Int(ceil(totalDiag / (stripeWidth * CGFloat(count)))) + 1

                for s in 0..<stripeCount {
                    for (i, g) in groups.enumerated() {
                        let highlighted = hoveredGroupIDs.contains(g.groupID)
                        let opacity = highlighted ? 0.2 : 0.125
                        let offset = CGFloat(s * count + i) * stripeWidth
                        var path = Path()
                        let x0 = offset - size.height
                        path.move(to: CGPoint(x: x0, y: 0))
                        path.addLine(to: CGPoint(x: x0 + stripeWidth, y: 0))
                        path.addLine(to: CGPoint(x: x0 + stripeWidth + size.height, y: size.height))
                        path.addLine(to: CGPoint(x: x0 + size.height, y: size.height))
                        path.closeSubpath()
                        context.fill(path, with: .color(GroupPalette.color(forIndex: g.colorIndex).opacity(opacity)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .animation(.easeInOut(duration: 0.15), value: hoveredGroupIDs)
        }
    }
}

// MARK: - Screen Toolbar Components

/// Shows its content whenever externalHover (screen hover) is true.
struct HoverScreenToolbar<Content: View>: View {
    var externalHover: Bool = false
    let content: () -> Content

    init(externalHover: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.externalHover = externalHover
        self.content = content
    }

    var body: some View {
        content()
            .opacity(externalHover ? 1 : 0)
            .scaleEffect(externalHover ? 1 : 0.9)
            .animation(.spring(duration: 0.2), value: externalHover)
    }
}

struct ScreenToolbarView: View {
    let screenWidth: CGFloat
    let zoom: CGFloat
    let hasImages: Bool
    let canCycle: Bool
    let zoomIconName: String
    var readOnly: Bool = false
    let onAddImage: () -> Void
    let onDeleteImage: () -> Void
    let onZoomImage: () -> Void
    let onCycleImage: () -> Void

    var body: some View {
        let effectiveZoom = max(zoom, 2.4)
        let iconSize: CGFloat = 7.5 * effectiveZoom
        let spacing: CGFloat = 2.25 * effectiveZoom
        let padding: CGFloat = 2.25 * effectiveZoom
        let cornerRadius: CGFloat = 2.25 * effectiveZoom
        let shadowRadius: CGFloat = 1.5 * effectiveZoom

        HStack(spacing: spacing) {
            // Add new image (hidden in read-only)
            if !readOnly {
                Button {
                    onAddImage()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white)
                        .frame(width: iconSize, height: iconSize)
                }
                .buttonStyle(.plain)
                .help("Add image")
            }

            // Zoom image (only shown when images exist)
            if hasImages {
                Button {
                    onZoomImage()
                } label: {
                    Image(systemName: zoomIconName)
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white)
                        .frame(width: iconSize, height: iconSize)
                }
                .buttonStyle(.plain)
                .help("Zoom image")
            }

            // Cycle images (only shown when 2+ images)
            if canCycle {
                Button {
                    onCycleImage()
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white)
                        .frame(width: iconSize, height: iconSize)
                }
                .buttonStyle(.plain)
                .help("Cycle images")
            }

            // Delete current image (hidden in read-only)
            if hasImages && !readOnly {
                Button {
                    onDeleteImage()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: iconSize))
                        .foregroundStyle(.white)
                        .frame(width: iconSize, height: iconSize)
                }
                .buttonStyle(.plain)
                .help("Remove current image")
            }
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: shadowRadius, x: 0, y: 0.75 * effectiveZoom)
        )
        .opacity(0.5)
    }
}
