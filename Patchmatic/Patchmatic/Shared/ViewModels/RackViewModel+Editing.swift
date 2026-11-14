import SwiftUI

extension RackViewModel {
    // MARK: - Selection

    func clearSelection() {
        selectedPlacedModuleIDs.removeAll()
        selectedCaseIDs.removeAll()
    }

    /// Returns the effective set of module IDs for a group context menu action.
    /// If the clicked module is in the current selection, returns the full selection;
    /// otherwise returns just the clicked module.
    func effectiveGroupSelection(for clickedID: UUID) -> Set<UUID> {
        if selectedPlacedModuleIDs.contains(clickedID) && selectedPlacedModuleIDs.count > 1 {
            return selectedPlacedModuleIDs
        }
        return [clickedID]
    }

    func removeSelectedModules() {
        guard let rack, !selectedPlacedModuleIDs.isEmpty else { return }
        prepareEdit()
        for rackCase in rack.cases {
            rackCase.placedModules.removeAll { selectedPlacedModuleIDs.contains($0.id) }
        }
        purgePatchReferences(to: selectedPlacedModuleIDs, in: rack)
        selectedPlacedModuleIDs.removeAll()
    }

    /// Deletes the selected cases. A rack always keeps at least one case.
    func removeSelectedCases() {
        guard let rack, !selectedCaseIDs.isEmpty else { return }
        guard rack.cases.contains(where: { !selectedCaseIDs.contains($0.id) }) else {
            #if os(macOS)
            NSSound.beep()
            #endif
            return
        }
        prepareEdit()
        let removed = rack.cases.filter { selectedCaseIDs.contains($0.id) }
        rack.cases.removeAll { selectedCaseIDs.contains($0.id) }
        purgePatchReferences(to: Set(removed.flatMap { $0.placedModules.map(\.id) }), in: rack)
        selectedCaseIDs.removeAll()
    }

    /// Removes cables, knob values, screen images and notes that refer to removed modules
    /// from the rack's patches. Image files are deleted when the edit is committed.
    func purgePatchReferences(to moduleIDs: Set<UUID>, in rack: Rack) {
        guard !moduleIDs.isEmpty else { return }
        for patch in document.patches where patch.rackID == rack.id {
            patch.removeReferences(toModules: moduleIDs)
        }
    }

    func deleteSelection() {
        if !selectedCaseIDs.isEmpty {
            removeSelectedCases()
        }
        if !selectedPlacedModuleIDs.isEmpty {
            removeSelectedModules()
        }
    }

    func selectAllModules() {
        guard let rack else { return }
        selectedPlacedModuleIDs = Set(rack.cases.flatMap { $0.placedModules.map(\.id) })
        selectedCaseIDs.removeAll()
    }

    func duplicateSelectedModules() {
        guard let rack else { return }
        prepareEdit()
        var newIDs = Set<UUID>()
        for moduleID in selectedPlacedModuleIDs {
            guard let rackCase = rack.caseForModule(moduleID),
                  let placed = rackCase.placedModules.first(where: { $0.id == moduleID }),
                  let definition = document.moduleDefinition(for: placed.moduleDefinitionID),
                  let position = rackCase.nextAvailablePosition(inRow: placed.rowIndex, moduleWidth: definition.widthHP, widthOf: widthHP(of:))
            else { continue }
            let copy = PlacedModule(
                moduleDefinitionID: definition.id,
                rowIndex: placed.rowIndex,
                positionInRow: position
            )
            rackCase.placedModules.append(copy)
            newIDs.insert(copy.id)
        }
        selectedPlacedModuleIDs = newIDs
    }

    func nudgeSelectedModules(by deltaHP: Int) {
        guard let rack else { return }
        prepareEdit()
        var moduleToCaseMap: [UUID: Case] = [:]
        for rackCase in rack.cases {
            for placed in rackCase.placedModules where selectedPlacedModuleIDs.contains(placed.id) {
                moduleToCaseMap[placed.id] = rackCase
            }
        }
        for moduleID in selectedPlacedModuleIDs {
            guard let rackCase = moduleToCaseMap[moduleID],
                  let index = rackCase.placedModules.firstIndex(where: { $0.id == moduleID }),
                  let definition = document.moduleDefinition(for: rackCase.placedModules[index].moduleDefinitionID)
            else { continue }
            let newPos = rackCase.placedModules[index].positionInRow + deltaHP
            if canPlaceModule(id: moduleID, width: definition.widthHP, inCase: rackCase, row: rackCase.placedModules[index].rowIndex, atPosition: newPos) {
                rackCase.placedModules[index].positionInRow = newPos
            }
        }
    }

    /// Returns modules and cases whose frames intersect the given rect (rack coordinates)
    func selectItemsInRect(_ rect: CGRect) {
        guard let rack else { return }
        var moduleIDs = Set<UUID>()
        var caseIDs = Set<UUID>()

        var sizeCache: [UUID: CGSize] = [:]
        for def in document.moduleLibrary {
            sizeCache[def.id] = CGSize(
                width: EurorackConstants.width(forHP: def.widthHP),
                height: def.panelHeight
            )
        }

        for rackCase in rack.cases {
            let caseRect = caseContentFrame(rackCase)

            if rect.intersects(caseRect) {
                var anyModuleHit = false
                for placed in rackCase.placedModules {
                    let origin = moduleOrigin(for: placed, in: rackCase)
                    guard let size = sizeCache[placed.moduleDefinitionID] else { continue }
                    let moduleRect = CGRect(origin: origin, size: size)
                    if rect.intersects(moduleRect) {
                        moduleIDs.insert(placed.id)
                        anyModuleHit = true
                    }
                }
                if !anyModuleHit {
                    caseIDs.insert(rackCase.id)
                }
            }
        }

        selectedPlacedModuleIDs = moduleIDs
        selectedCaseIDs = caseIDs
    }
    // MARK: - Rack CRUD

    func addRack() {
        let name = GeometryHelpers.uniqueName("Rack", among: document.racks.map(\.name))
        let rack = Rack(name: name)
        document.racks.append(rack)
        document.activeRackID = rack.id
    }

    func duplicateRack(_ rack: Rack) {
        let copyName = GeometryHelpers.uniqueName("\(rack.name) Copy", among: document.racks.map(\.name))
        let copiedCases = rack.cases.map { original in
            Case(
                name: original.name,
                rows: original.rows,
                rowWidthHP: original.rowWidthHP,
                placedModules: original.placedModules.map {
                    PlacedModule(moduleDefinitionID: $0.moduleDefinitionID, rowIndex: $0.rowIndex, positionInRow: $0.positionInRow)
                },
                positionX: original.positionX,
                positionY: original.positionY
            )
        }
        let copy = Rack(name: copyName, cases: copiedCases)
        document.racks.append(copy)
        document.activeRackID = copy.id
    }

    func deleteRack(_ rack: Rack) {
        document.racks.removeAll { $0.id == rack.id }
        document.patches.removeAll { $0.rackID == rack.id }
        document.removeMissingPatchesFromSets()
        if document.activeRackID == rack.id {
            document.activeRackID = document.racks.first?.id
        }
    }

    func selectRack(_ rack: Rack) {
        if isEditing { pendingRackSelectionID = rack.id }
        else { document.activeRackID = rack.id }
    }

    func renameRack(_ rack: Rack, to newName: String) {
        let others = document.racks.filter { $0.id != rack.id }.map(\.name)
        rack.name = GeometryHelpers.uniqueName(newName, among: others)
    }
    // MARK: - Case CRUD

    func renameCase(_ rackCase: Case, to newName: String) {
        prepareEdit()
        rackCase.name = newName
    }

    func setCaseWidthHP(_ rackCase: Case, to widthHP: Int) {
        prepareEdit()
        rackCase.rowWidthHP = widthHP
    }

    func addCase() {
        guard let rack else { return }
        prepareEdit()
        // Position new case below the current bounding box
        let bb = rack.boundingBox()
        let newY = bb.isEmpty ? 0 : bb.maxY + Rack.caseSpacing + caseHeaderHeight
        let caseName = GeometryHelpers.uniqueName("Case", among: rack.cases.map(\.name))
        let newCase = Case(name: caseName, positionY: newY)
        rack.cases.append(newCase)
    }

    func deleteCase(_ rackCase: Case) {
        guard let rack else { return }
        prepareEdit()
        rack.cases.removeAll { $0.id == rackCase.id }
        purgePatchReferences(to: Set(rackCase.placedModules.map(\.id)), in: rack)
    }
    // MARK: - Module placement

    func addModuleToRack(_ definition: ModuleDefinition, case rackCase: Case, row: Int) {
        guard row < rackCase.rows.count else { return }
        guard rackCase.rows[row].size == definition.format else { return }
        guard let position = rackCase.nextAvailablePosition(inRow: row, moduleWidth: definition.widthHP, widthOf: widthHP(of:)) else {
            return
        }
        prepareEdit()
        let placed = PlacedModule(
            moduleDefinitionID: definition.id,
            rowIndex: row,
            positionInRow: position
        )
        rackCase.placedModules.append(placed)
    }

    func addModuleToFirstAvailableSlot(_ definition: ModuleDefinition) {
        guard let rack else { return }
        for rackCase in rack.cases {
            for (rowIndex, row) in rackCase.rows.enumerated() {
                guard row.size == definition.format else { continue }
                if let position = rackCase.nextAvailablePosition(inRow: rowIndex, moduleWidth: definition.widthHP, widthOf: widthHP(of:)) {
                    prepareEdit()
                    let placed = PlacedModule(
                        moduleDefinitionID: definition.id,
                        rowIndex: rowIndex,
                        positionInRow: position
                    )
                    rackCase.placedModules.append(placed)
                    return
                }
            }
        }
    }

    func removeModuleFromRack(_ placedModuleID: UUID) {
        guard let rack, let rackCase = rack.caseForModule(placedModuleID) else { return }
        prepareEdit()
        rackCase.placedModules.removeAll { $0.id == placedModuleID }
        purgePatchReferences(to: [placedModuleID], in: rack)
    }

    /// Width in HP of a placed module's definition, or 0 if the definition is missing.
    func widthHP(of placed: PlacedModule) -> Int {
        document.moduleDefinition(for: placed.moduleDefinitionID)?.widthHP ?? 0
    }

    func moveModule(_ placedModuleID: UUID, inCase rackCase: Case, toRow row: Int, position: Int) {
        guard let index = rackCase.placedModules.firstIndex(where: { $0.id == placedModuleID }) else { return }
        rackCase.placedModules[index].rowIndex = row
        rackCase.placedModules[index].positionInRow = position
    }
    // MARK: - Row management

    func addRow(to rackCase: Case, size: RowSize) {
        prepareEdit()
        rackCase.rows.append(RackRow(size: size))
    }

    func removeRow(from rackCase: Case, at index: Int) {
        guard index < rackCase.rows.count else { return }
        prepareEdit()
        let removedIDs = Set(rackCase.placedModules.filter { $0.rowIndex == index }.map(\.id))
        rackCase.placedModules.removeAll { $0.rowIndex == index }
        if let rack { purgePatchReferences(to: removedIDs, in: rack) }
        for i in rackCase.placedModules.indices {
            if rackCase.placedModules[i].rowIndex > index {
                rackCase.placedModules[i].rowIndex -= 1
            }
        }
        rackCase.rows.remove(at: index)
    }
}
