import Foundation

@Observable
final class PatchmaticDocument: Codable {
    /// Version of the on-disk format written by this build. Increment when a change
    /// can't be read by older builds, and migrate older versions in `init(from:)`.
    static let currentSchemaVersion = 1

    var moduleLibrary: [ModuleDefinition]
    var racks: [Rack]
    var patches: [Patch]
    var sets: [PatchSet]
    // Selection is per device and stored outside the document. Files written by older
    // builds include it, so it is still decoded as an initial selection.
    var activeRackID: UUID?
    var activePatchID: UUID?
    var activeSetID: UUID?

    init(
        moduleLibrary: [ModuleDefinition] = [],
        racks: [Rack] = [],
        patches: [Patch] = [],
        sets: [PatchSet] = [],
        activeRackID: UUID? = nil,
        activePatchID: UUID? = nil,
        activeSetID: UUID? = nil
    ) {
        self.moduleLibrary = moduleLibrary
        self.racks = racks
        self.patches = patches
        self.sets = sets
        self.activeRackID = activeRackID
        self.activePatchID = activePatchID
        self.activeSetID = activeSetID
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case schemaVersion, moduleLibrary, racks, patches, sets, activeRackID, activePatchID, activeSetID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        guard version <= Self.currentSchemaVersion else {
            throw SchemaError.newerVersion(version)
        }
        moduleLibrary = try container.decode([ModuleDefinition].self, forKey: .moduleLibrary)
        racks = try container.decode([Rack].self, forKey: .racks)
        patches = try container.decode([Patch].self, forKey: .patches)
        sets = try container.decodeIfPresent([PatchSet].self, forKey: .sets) ?? []
        activeRackID = try container.decodeIfPresent(UUID.self, forKey: .activeRackID)
        activePatchID = try container.decodeIfPresent(UUID.self, forKey: .activePatchID)
        activeSetID = try container.decodeIfPresent(UUID.self, forKey: .activeSetID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(moduleLibrary, forKey: .moduleLibrary)
        try container.encode(racks, forKey: .racks)
        try container.encode(patches, forKey: .patches)
        try container.encode(sets, forKey: .sets)
    }

    enum SchemaError: LocalizedError {
        case newerVersion(Int)

        var errorDescription: String? {
            switch self {
            case .newerVersion(let version):
                return "This library was saved by a newer version of Patchmatic (format \(version)). Update Patchmatic to open it."
            }
        }
    }

    // MARK: - Helpers

    var activeRack: Rack? {
        racks.first { $0.id == activeRackID }
    }

    var activePatch: Patch? {
        patches.first { $0.id == activePatchID }
    }

    /// Replaces the selection with any of the given IDs that exist in the document.
    func applySelection(rackID: UUID?, patchID: UUID?, setID: UUID?) {
        if let rackID, racks.contains(where: { $0.id == rackID }) { activeRackID = rackID }
        if let patchID, patches.contains(where: { $0.id == patchID }) { activePatchID = patchID }
        if let setID, sets.contains(where: { $0.id == setID }) { activeSetID = setID }
    }

    /// Drops set entries whose patch no longer exists.
    func removeMissingPatchesFromSets() {
        let existing = Set(patches.map(\.id))
        for set in sets where set.patchIDs.contains(where: { !existing.contains($0) }) {
            set.patchIDs.removeAll { !existing.contains($0) }
        }
    }

    func rack(for id: UUID) -> Rack? {
        racks.first { $0.id == id }
    }

    /// Whether any rack has the module definition placed in it.
    func isModuleInUse(_ definitionID: UUID) -> Bool {
        racks.contains { rack in
            rack.cases.contains { $0.placedModules.contains { $0.moduleDefinitionID == definitionID } }
        }
    }

    func moduleDefinition(for id: UUID) -> ModuleDefinition? {
        moduleLibrary.first { $0.id == id }
    }
}
