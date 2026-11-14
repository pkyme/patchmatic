import SwiftUI

extension PatchViewModel {
    // MARK: - Knob values

    func knobValue(forModule moduleID: UUID, control controlID: UUID) -> Double {
        activePatch?.knobValue(forModule: moduleID, control: controlID) ?? 0.5
    }

    func setKnobValue(forModule moduleID: UUID, control controlID: UUID, value: Double) {
        beginEditing()
        activePatch?.setKnobValue(forModule: moduleID, control: controlID, value: value)
    }

    func knobValuesMap(forModule moduleID: UUID) -> [UUID: Double] {
        guard let patch = activePatch else { return [:] }
        var map: [UUID: Double] = [:]
        for kv in patch.knobValues where kv.placedModuleID == moduleID {
            map[kv.controlID] = kv.value
        }
        return map
    }

    /// Returns the cable color for each patched control on a module (last cable wins).
    /// During a drag, the source patch point is given the color of the cable that would be created.
    func patchPointColors(forModule moduleID: UUID, isDarkMode: Bool) -> [UUID: Color] {
        guard let patch = activePatch else { return [:] }
        var map: [UUID: Color] = [:]
        for cable in patch.cables {
            let color = CableRenderer.color(for: cable, isDarkMode: isDarkMode)
            if cable.fromModuleID == moduleID {
                map[cable.fromControlID] = color
            }
            if cable.toModuleID == moduleID {
                map[cable.toControlID] = color
            }
        }
        if let from = dragFrom, from.moduleID == moduleID {
            let nextColorIndex = patch.nextCableColorIndex
            map[from.controlID] = CableRenderer.color(forIndex: nextColorIndex, isDarkMode: isDarkMode)
        }
        return map
    }
    // MARK: - Screen Images

    func cycleScreenImage(moduleID: UUID, controlID: UUID, forward: Bool = true) {
        activePatch?.cycleScreenImage(forModule: moduleID, control: controlID, forward: forward)
    }

    func selectScreenImage(moduleID: UUID, controlID: UUID, at index: Int) {
        activePatch?.selectScreenImage(forModule: moduleID, control: controlID, at: index)
    }

    func addScreenImageFile(moduleID: UUID, controlID: UUID, filename: String) {
        prepareEdit()
        pendingImageDeletionFilenames.removeAll { $0 == filename }
        activePatch?.addScreenImageFile(forModule: moduleID, control: controlID, filename: filename)
    }

    func removeScreenImageFile(moduleID: UUID, controlID: UUID, at index: Int) {
        prepareEdit()
        if let si = activePatch?.screenImages.first(where: { $0.placedModuleID == moduleID && $0.controlID == controlID }),
           index < si.imageFilenames.count {
            pendingImageDeletionFilenames.append(si.imageFilenames[index])
        }
        activePatch?.removeScreenImageFile(forModule: moduleID, control: controlID, at: index, deleteFile: false)
    }

    func screenImagesMap(forModule moduleID: UUID) -> [UUID: Image] {
        guard let patch = activePatch else { return [:] }
        var map: [UUID: Image] = [:]
        for si in patch.screenImages where si.placedModuleID == moduleID {
            guard let filename = si.activeFilename else { continue }
            if let img = ImageStore.load(filename) {
                map[si.controlID] = Image(platformImage: img)
            }
        }
        return map
    }
    // MARK: - Activation

    func activatedControlIDs(forModule moduleID: UUID) -> Set<UUID> {
        guard let patch = activePatch else { return [] }
        var ids = Set<UUID>()
        for kv in patch.knobValues where kv.placedModuleID == moduleID {
            ids.insert(kv.controlID)
        }
        for cable in patch.cables {
            if cable.fromModuleID == moduleID { ids.insert(cable.fromControlID) }
            if cable.toModuleID == moduleID { ids.insert(cable.toControlID) }
        }
        for si in patch.screenImages where si.placedModuleID == moduleID && !si.imageFilenames.isEmpty {
            ids.insert(si.controlID)
        }
        if let from = dragFrom, from.moduleID == moduleID {
            ids.insert(from.controlID)
        }
        return ids
    }

    func deactivateControl(moduleID: UUID, controlID: UUID) {
        guard let patch = activePatch else { return }
        prepareEdit()
        patch.knobValues.removeAll { $0.placedModuleID == moduleID && $0.controlID == controlID }
        patch.cables.removeAll {
            (cable: PatchCable) -> Bool in
            (cable.fromModuleID == moduleID && cable.fromControlID == controlID) ||
            (cable.toModuleID == moduleID && cable.toControlID == controlID)
        }
        compactPatchPointOrder()
        if let index = patch.screenImages.firstIndex(where: { $0.placedModuleID == moduleID && $0.controlID == controlID }) {
            for filename in patch.screenImages[index].imageFilenames {
                pendingImageDeletionFilenames.append(filename)
            }
            patch.screenImages.remove(at: index)
        }
    }
    // MARK: - Control interaction

    func beginKnobDrag(moduleID: UUID, controlID: UUID, startY: CGFloat) {
        prepareEdit(grouped: true)
        let current = knobValue(forModule: moduleID, control: controlID)
        knobDragInfo = (moduleID: moduleID, controlID: controlID, startValue: current, startY: startY)
    }

    func updateKnobDrag(currentY: CGFloat) {
        guard let info = knobDragInfo else { return }
        let delta = Double(info.startY - currentY) / 150.0
        let newValue = min(max(info.startValue + delta, 0), 1)
        setKnobValue(forModule: info.moduleID, control: info.controlID, value: newValue)
    }

    func endKnobDrag() {
        undoManager?.endUndoGrouping()
        knobDragInfo = nil
    }

    func beginSliderDrag(moduleID: UUID, controlID: UUID, center: CGPoint, trackHalf: CGFloat, isVertical: Bool) {
        prepareEdit(grouped: true)
        sliderDragInfo = (moduleID: moduleID, controlID: controlID, centerX: center.x, centerY: center.y, trackHalf: trackHalf, isVertical: isVertical)
    }

    func updateSliderDrag(point: CGPoint) {
        guard let info = sliderDragInfo else { return }
        let raw: Double
        if info.isVertical {
            raw = Double((info.centerY + info.trackHalf - point.y) / (info.trackHalf * 2))
        } else {
            raw = Double((point.x - info.centerX + info.trackHalf) / (info.trackHalf * 2))
        }
        setKnobValue(forModule: info.moduleID, control: info.controlID, value: min(max(raw, 0), 1))
    }

    func endSliderDrag() {
        undoManager?.endUndoGrouping()
        sliderDragInfo = nil
    }

    func toggleControlValue(moduleID: UUID, controlID: UUID, states: Int = 2) {
        prepareEdit()
        let n = max(2, states)
        let newValue: Double
        if let current = activePatch?.knobValue(forModule: moduleID, control: controlID) {
            let currentStep = Int((current * Double(n - 1)).rounded())
            let nextStep = (currentStep + 1) % n
            newValue = Double(nextStep) / Double(n - 1)
        } else {
            newValue = 0.0
        }
        setKnobValue(forModule: moduleID, control: controlID, value: newValue)
    }
}
