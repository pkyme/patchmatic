import SwiftUI

extension PatchViewModel {
    // MARK: - Cable drag

    func beginDrag(moduleID: UUID, controlID: UUID, point: CGPoint) {
        dragFrom = (moduleID: moduleID, controlID: controlID)
        dragCurrentPoint = point
    }

    func updateDrag(point: CGPoint) {
        dragCurrentPoint = point
    }

    func endDrag(moduleID: UUID?, controlID: UUID?) {
        defer {
            dragFrom = nil
            dragCurrentPoint = nil
        }
        guard let from = dragFrom,
              let toModule = moduleID,
              let toControl = controlID,
              from.moduleID != toModule || from.controlID != toControl
        else { return }

        prepareEdit()

        let nextColorIndex = activePatch?.nextCableColorIndex ?? 0
        let cable = PatchCable(
            fromModuleID: from.moduleID,
            fromControlID: from.controlID,
            toModuleID: toModule,
            toControlID: toControl,
            colorIndex: nextColorIndex
        )
        guard let patch = activePatch else { return }
        patch.cables.append(cable)
        // Number newly connected patch points after the existing ones
        patch.backfillPatchPointOrder()
    }

    func cancelDrag() {
        dragFrom = nil
        dragCurrentPoint = nil
    }

    func deleteCable(_ cable: PatchCable) {
        prepareEdit()
        activePatch?.cables.removeAll { $0.id == cable.id }
        selectedCableIDs.remove(cable.id)
        compactPatchPointOrder()
    }

    func toggleCableSelection(_ cableID: UUID) {
        if selectedCableIDs.contains(cableID) {
            selectedCableIDs.remove(cableID)
        } else {
            selectedCableIDs.insert(cableID)
        }
    }

    func clearCableSelection() {
        selectedCableIDs.removeAll()
    }

    func deleteSelectedCables() {
        guard !selectedCableIDs.isEmpty else { return }
        prepareEdit()
        activePatch?.cables.removeAll { selectedCableIDs.contains($0.id) }
        selectedCableIDs.removeAll()
        compactPatchPointOrder()
    }

    /// Readable cable name of the form "Module Jack → Module Jack"
    func cableDescription(_ cable: PatchCable) -> String {
        "\(patchPointDescription(moduleID: cable.fromModuleID, controlID: cable.fromControlID)) \u{2192} \(patchPointDescription(moduleID: cable.toModuleID, controlID: cable.toControlID))"
    }

    func patchPointDescription(moduleID: UUID, controlID: UUID) -> String {
        let definition = activePatch
            .flatMap { document.rack(for: $0.rackID)?.placedModule(moduleID) }
            .flatMap { document.moduleDefinition(for: $0.moduleDefinitionID) }
        let moduleName = definition?.name ?? "Unknown"
        let label = definition?.controls.first { $0.id == controlID }?.label
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !label.isEmpty { return "\(moduleName) \(label)" }
        if let number = patchPointNumber(moduleID: moduleID, controlID: controlID) {
            return "\(moduleName) #\(number)"
        }
        return moduleName
    }
    // MARK: - Cable copy and paste

    func copySelectedCables() {
        guard let patch = activePatch, !selectedCableIDs.isEmpty else { return }
        let cables = patch.cables.filter { selectedCableIDs.contains($0.id) }
        guard !cables.isEmpty else { return }
        cableClipboard = CableClipboard(rackID: patch.rackID, cables: cables)
    }

    /// Whether copied cables can be pasted into the active patch, which must use the rack they were copied from
    var canPasteCables: Bool {
        guard let clipboard = cableClipboard, let patch = activePatch else { return false }
        return clipboard.rackID == patch.rackID
    }

    /// Adds the copied cables to the active patch with new IDs and selects them.
    /// Cables whose modules are no longer in the rack, or that duplicate an existing
    /// connection, are skipped.
    func pasteCables() {
        guard canPasteCables,
              let clipboard = cableClipboard,
              let patch = activePatch,
              let rack = document.rack(for: patch.rackID) else { return }

        let caseIDs = Set(rack.cases.map(\.id))
        func connectionKey(_ c: PatchCable) -> Set<PatchPointKey> {
            [PatchPointKey(moduleID: c.fromModuleID, controlID: c.fromControlID),
             PatchPointKey(moduleID: c.toModuleID, controlID: c.toControlID)]
        }
        var existing = Set(patch.cables.map(connectionKey))

        var pasted: [PatchCable] = []
        for source in clipboard.cables {
            guard rack.placedModule(source.fromModuleID) != nil,
                  rack.placedModule(source.toModuleID) != nil,
                  !existing.contains(connectionKey(source)) else { continue }
            existing.insert(connectionKey(source))
            var cable = source
            cable.id = UUID()
            cable.pins = source.pins
                .filter { $0.caseID.map(caseIDs.contains) ?? true }
                .map { var pin = $0; pin.id = UUID(); return pin }
            pasted.append(cable)
        }
        guard !pasted.isEmpty else { return }

        prepareEdit()
        patch.cables.append(contentsOf: pasted)
        for cable in pasted {
            for key in [PatchPointKey(moduleID: cable.fromModuleID, controlID: cable.fromControlID),
                        PatchPointKey(moduleID: cable.toModuleID, controlID: cable.toControlID)]
            where !patch.patchPointOrder.contains(key) {
                patch.patchPointOrder.append(key)
            }
        }
        selectedPinID = nil
        selectedCableIDs = Set(pasted.map(\.id))
    }

    func setSelectedCableColor(paletteIndex: Int) {
        guard let patch = activePatch, !selectedCableIDs.isEmpty else { return }
        prepareEdit()
        for i in patch.cables.indices where selectedCableIDs.contains(patch.cables[i].id) {
            patch.cables[i].colorIndex = paletteIndex
            patch.cables[i].customColor = nil
        }
    }
    // MARK: - Cable Pins

    func addCablePin(cableID: UUID, pin: CablePin) {
        guard let patch = activePatch,
              let index = patch.cables.firstIndex(where: { $0.id == cableID }) else { return }
        prepareEdit()
        // Shift existing pins at or after the insertion point, then re-index sequentially
        for i in patch.cables[index].pins.indices where patch.cables[index].pins[i].sortIndex >= pin.sortIndex {
            patch.cables[index].pins[i].sortIndex += 1
        }
        patch.cables[index].pins.append(pin)
        patch.cables[index].pins.sort { $0.sortIndex < $1.sortIndex }
        Self.renumberPins(of: &patch.cables[index])
        rebuildRopes(forCable: cableID)
    }

    /// Sets each pin's sort index to its position in the cable's pin array.
    static func renumberPins(of cable: inout PatchCable) {
        for i in cable.pins.indices { cable.pins[i].sortIndex = i }
    }

    func beginPinDrag(cableID: UUID, pinID: UUID) {
        prepareEdit(grouped: true)
    }

    func endPinDrag() {
        undoManager?.endUndoGrouping()
    }

    func moveCablePin(cableID: UUID, pinID: UUID, to position: CGPoint, caseID: UUID?) {
        guard let cableIdx = activePatch?.cables.firstIndex(where: { $0.id == cableID }),
              let pinIdx = activePatch?.cables[cableIdx].pins.firstIndex(where: { $0.id == pinID })
        else { return }
        if let caseID,
           let rack = document.activeRack,
           let rackCase = rack.cases.first(where: { $0.id == caseID }) {
            activePatch?.cables[cableIdx].pins[pinIdx].x = position.x - rackCase.positionX
            activePatch?.cables[cableIdx].pins[pinIdx].y = position.y - rackCase.positionY
            activePatch?.cables[cableIdx].pins[pinIdx].caseID = caseID
        } else {
            activePatch?.cables[cableIdx].pins[pinIdx].x = position.x
            activePatch?.cables[cableIdx].pins[pinIdx].y = position.y
            activePatch?.cables[cableIdx].pins[pinIdx].caseID = nil
        }
    }

    func deleteCablePin(cableID: UUID, pinID: UUID) {
        guard let patch = activePatch,
              let index = patch.cables.firstIndex(where: { $0.id == cableID }) else { return }
        prepareEdit()
        patch.cables[index].pins.removeAll { $0.id == pinID }
        Self.renumberPins(of: &patch.cables[index])
        selectedPinID = nil
        rebuildRopes(forCable: cableID)
    }

    func deleteSelectedPin() {
        guard let pin = selectedPinID else { return }
        deleteCablePin(cableID: pin.cableID, pinID: pin.pinID)
    }

    /// Returns cable IDs connected to a specific patch point
    func cablesForPatchPoint(moduleID: UUID, controlID: UUID) -> [UUID] {
        guard let patch = activePatch else { return [] }
        return patch.cables.compactMap { cable in
            if (cable.fromModuleID == moduleID && cable.fromControlID == controlID) ||
               (cable.toModuleID == moduleID && cable.toControlID == controlID) {
                return cable.id
            }
            return nil
        }
    }
    // MARK: - Patch point numbering

    func compactPatchPointOrder() {
        activePatch?.compactPatchPointOrder()
    }

    func patchPointNumber(moduleID: UUID, controlID: UUID) -> Int? {
        rebuildPatchPointNumberMapIfNeeded()
        let key = PatchPointKey(moduleID: moduleID, controlID: controlID)
        return patchPointNumberMap[key]
    }

    func patchPointNumbers(forModule moduleID: UUID) -> [UUID: Int] {
        rebuildPatchPointNumberMapIfNeeded()
        var map: [UUID: Int] = [:]
        for (key, number) in patchPointNumberMap where key.moduleID == moduleID {
            map[key.controlID] = number
        }
        return map
    }

    func rebuildPatchPointNumberMapIfNeeded() {
        guard let patch = activePatch else {
            patchPointNumberMap.removeAll()
            return
        }
        if patch.id == patchPointNumberMapPatchID && patch.patchPointOrder == patchPointNumberMapOrder {
            return
        }
        patchPointNumberMap.removeAll(keepingCapacity: true)
        for (index, key) in patch.patchPointOrder.enumerated() {
            patchPointNumberMap[key] = index + 1
        }
        patchPointNumberMapPatchID = patch.id
        patchPointNumberMapOrder = patch.patchPointOrder
    }
}
