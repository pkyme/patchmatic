import Foundation

struct ModuleGroup: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var notes: String = ""
    var colorIndex: Int
    var placedModuleIDs: [UUID]
}

struct PatchPointKey: Codable, Hashable {
    var moduleID: UUID
    var controlID: UUID
}

struct ScreenImage: Codable, Identifiable, Hashable {
    var id = UUID()
    var placedModuleID: UUID
    var controlID: UUID
    var imageFilenames: [String]
    var activeIndex: Int = 0

    var activeFilename: String? {
        guard !imageFilenames.isEmpty else { return nil }
        return imageFilenames[min(activeIndex, imageFilenames.count - 1)]
    }
}

struct ModuleNote: Codable, Identifiable, Hashable {
    var id = UUID()
    var placedModuleID: UUID
    /// When set, note is anchored to this patch point control (position field ignored)
    var controlID: UUID?
    /// Normalized position (0...1) within the module panel
    var position: NormalizedPoint
    var text: String

    enum CodingKeys: String, CodingKey {
        case id, placedModuleID, controlID, position, text
    }

    init(placedModuleID: UUID, controlID: UUID? = nil, position: NormalizedPoint, text: String) {
        self.placedModuleID = placedModuleID
        self.controlID = controlID
        self.position = position
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        placedModuleID = try container.decode(UUID.self, forKey: .placedModuleID)
        controlID = try container.decodeIfPresent(UUID.self, forKey: .controlID)
        position = try container.decode(NormalizedPoint.self, forKey: .position)
        text = try container.decode(String.self, forKey: .text)
    }
}

struct KnobValue: Codable, Identifiable, Hashable {
    var id = UUID()
    var placedModuleID: UUID
    var controlID: UUID
    /// 0...1 normalized knob position
    var value: Double
}

@Observable
final class Patch: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var rackID: UUID
    var cables: [PatchCable]
    var knobValues: [KnobValue]
    var screenImages: [ScreenImage]
    /// Notes attached to modules or patch points; `patchNotes` is the patch's own note
    var moduleNotes: [ModuleNote]
    var patchPointOrder: [PatchPointKey] = []
    var moduleGroups: [ModuleGroup] = []
    var patchNotes: String = ""
    var audioPreviewFilename: String?

    init(id: UUID = UUID(), name: String = "Init", rackID: UUID, cables: [PatchCable] = [], knobValues: [KnobValue] = [], screenImages: [ScreenImage] = [], moduleNotes: [ModuleNote] = [], patchPointOrder: [PatchPointKey] = [], moduleGroups: [ModuleGroup] = [], patchNotes: String = "", audioPreviewFilename: String? = nil) {
        self.id = id
        self.name = name
        self.rackID = rackID
        self.cables = cables
        self.knobValues = knobValues
        self.screenImages = screenImages
        self.moduleNotes = moduleNotes
        self.patchPointOrder = patchPointOrder
        self.moduleGroups = moduleGroups
        self.patchNotes = patchNotes
        self.audioPreviewFilename = audioPreviewFilename
        backfillPatchPointOrder()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, rackID, cables, knobValues, screenImages, patchPointOrder, moduleGroups, patchNotes, audioPreviewFilename
        case moduleNotes = "notes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rackID = try container.decode(UUID.self, forKey: .rackID)
        cables = try container.decode([PatchCable].self, forKey: .cables)
        knobValues = try container.decode([KnobValue].self, forKey: .knobValues)
        screenImages = try container.decodeIfPresent([ScreenImage].self, forKey: .screenImages) ?? []
        moduleNotes = try container.decodeIfPresent([ModuleNote].self, forKey: .moduleNotes) ?? []
        patchPointOrder = try container.decodeIfPresent([PatchPointKey].self, forKey: .patchPointOrder) ?? []
        moduleGroups = try container.decodeIfPresent([ModuleGroup].self, forKey: .moduleGroups) ?? []
        patchNotes = try container.decodeIfPresent(String.self, forKey: .patchNotes) ?? ""
        audioPreviewFilename = try container.decodeIfPresent(String.self, forKey: .audioPreviewFilename)
        backfillPatchPointOrder()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rackID, forKey: .rackID)
        try container.encode(cables, forKey: .cables)
        try container.encode(knobValues, forKey: .knobValues)
        try container.encode(screenImages, forKey: .screenImages)
        try container.encode(moduleNotes, forKey: .moduleNotes)
        try container.encode(patchPointOrder, forKey: .patchPointOrder)
        try container.encode(moduleGroups, forKey: .moduleGroups)
        try container.encode(patchNotes, forKey: .patchNotes)
        try container.encodeIfPresent(audioPreviewFilename, forKey: .audioPreviewFilename)
    }

    // MARK: - Hashable

    static func == (lhs: Patch, rhs: Patch) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Helpers

    func knobValue(forModule moduleID: UUID, control controlID: UUID) -> Double? {
        knobValues.first { $0.placedModuleID == moduleID && $0.controlID == controlID }?.value
    }

    func setKnobValue(forModule moduleID: UUID, control controlID: UUID, value: Double) {
        if let index = knobValues.firstIndex(where: { $0.placedModuleID == moduleID && $0.controlID == controlID }) {
            knobValues[index].value = value
        } else {
            knobValues.append(KnobValue(placedModuleID: moduleID, controlID: controlID, value: value))
        }
    }

    // MARK: - Screen Images

    func screenImage(forModule moduleID: UUID, control controlID: UUID) -> ScreenImage? {
        screenImages.first { $0.placedModuleID == moduleID && $0.controlID == controlID }
    }

    func addScreenImageFile(forModule moduleID: UUID, control controlID: UUID, filename: String) {
        if let index = screenImages.firstIndex(where: { $0.placedModuleID == moduleID && $0.controlID == controlID }) {
            screenImages[index].imageFilenames.append(filename)
            screenImages[index].activeIndex = screenImages[index].imageFilenames.count - 1
        } else {
            screenImages.append(ScreenImage(placedModuleID: moduleID, controlID: controlID, imageFilenames: [filename]))
        }
    }

    func cycleScreenImage(forModule moduleID: UUID, control controlID: UUID, forward: Bool = true) {
        guard let index = screenImages.firstIndex(where: { $0.placedModuleID == moduleID && $0.controlID == controlID }),
              screenImages[index].imageFilenames.count > 1 else { return }
        let count = screenImages[index].imageFilenames.count
        let current = screenImages[index].activeIndex
        screenImages[index].activeIndex = forward ? (current + 1) % count : (current - 1 + count) % count
    }

    func selectScreenImage(forModule moduleID: UUID, control controlID: UUID, at fileIndex: Int) {
        guard let index = screenImages.firstIndex(where: { $0.placedModuleID == moduleID && $0.controlID == controlID }),
              screenImages[index].imageFilenames.indices.contains(fileIndex) else { return }
        screenImages[index].activeIndex = fileIndex
    }

    func removeScreenImageFile(forModule moduleID: UUID, control controlID: UUID, at fileIndex: Int, deleteFile: Bool = true) {
        guard let index = screenImages.firstIndex(where: { $0.placedModuleID == moduleID && $0.controlID == controlID }),
              fileIndex < screenImages[index].imageFilenames.count else { return }
        let filename = screenImages[index].imageFilenames.remove(at: fileIndex)
        if deleteFile { ImageStore.delete(filename) }
        if screenImages[index].imageFilenames.isEmpty {
            screenImages.remove(at: index)
        } else if screenImages[index].activeIndex >= screenImages[index].imageFilenames.count {
            screenImages[index].activeIndex = screenImages[index].imageFilenames.count - 1
        }
    }

    /// Palette colour index for the next cable added, cycling through the palette
    var nextCableColorIndex: Int {
        cables.count % CableRenderer.darkModePalette.count
    }

    // MARK: - Module references

    /// Removes cables, knob values, screen images, notes and group memberships that
    /// refer to the given placed modules.
    func removeReferences(toModules moduleIDs: Set<UUID>) {
        guard !moduleIDs.isEmpty else { return }
        cables.removeAll { moduleIDs.contains($0.fromModuleID) || moduleIDs.contains($0.toModuleID) }
        knobValues.removeAll { moduleIDs.contains($0.placedModuleID) }
        screenImages.removeAll { moduleIDs.contains($0.placedModuleID) }
        moduleNotes.removeAll { moduleIDs.contains($0.placedModuleID) }
        for i in moduleGroups.indices { moduleGroups[i].placedModuleIDs.removeAll { moduleIDs.contains($0) } }
        compactPatchPointOrder()
    }

    /// Removes references to placed modules that are no longer in `rack`, e.g. when a
    /// deleted patch is restored after modules were removed from its rack.
    func removeReferencesMissing(from rack: Rack) {
        let present = Set(rack.cases.flatMap { $0.placedModules.map(\.id) })
        var referenced = Set(knobValues.map(\.placedModuleID))
        referenced.formUnion(cables.flatMap { [$0.fromModuleID, $0.toModuleID] })
        referenced.formUnion(screenImages.map(\.placedModuleID))
        referenced.formUnion(moduleNotes.map(\.placedModuleID))
        referenced.formUnion(moduleGroups.flatMap(\.placedModuleIDs))
        removeReferences(toModules: referenced.subtracting(present))
    }

    // MARK: - Restoring

    /// Replaces this patch's contents with `other`'s, keeping this instance so views
    /// observing its properties (e.g. `cables`) are notified directly.
    func restoreContents(from other: Patch) {
        cables = other.cables
        knobValues = other.knobValues
        screenImages = other.screenImages
        moduleNotes = other.moduleNotes
        patchPointOrder = other.patchPointOrder
        moduleGroups = other.moduleGroups
        name = other.name
        patchNotes = other.patchNotes
        audioPreviewFilename = other.audioPreviewFilename
    }

    /// Image files referenced by this patch's screens
    var screenImageFilenames: Set<String> {
        Set(screenImages.flatMap(\.imageFilenames))
    }

    // MARK: - Patch point numbering

    /// Appends any cable endpoints missing from `patchPointOrder`, for patches saved
    /// before patch point numbering existed.
    func backfillPatchPointOrder() {
        var known = Set(patchPointOrder)
        for cable in cables {
            for key in [PatchPointKey(moduleID: cable.fromModuleID, controlID: cable.fromControlID),
                        PatchPointKey(moduleID: cable.toModuleID, controlID: cable.toControlID)]
            where known.insert(key).inserted {
                patchPointOrder.append(key)
            }
        }
    }

    /// Removes patch points that no longer have a cable connected.
    func compactPatchPointOrder() {
        let connected = Set(cables.flatMap { cable in
            [PatchPointKey(moduleID: cable.fromModuleID, controlID: cable.fromControlID),
             PatchPointKey(moduleID: cable.toModuleID, controlID: cable.toControlID)]
        })
        patchPointOrder.removeAll { !connected.contains($0) }
    }

    // MARK: - Module Notes

    func notes(forModule moduleID: UUID) -> [ModuleNote] {
        moduleNotes.filter { $0.placedModuleID == moduleID }
    }

    func patchPointNote(moduleID: UUID, controlID: UUID) -> ModuleNote? {
        moduleNotes.first { $0.placedModuleID == moduleID && $0.controlID == controlID }
    }

    func addNote(_ note: ModuleNote) {
        if let cid = note.controlID {
            guard patchPointNote(moduleID: note.placedModuleID, controlID: cid) == nil else { return }
        }
        moduleNotes.append(note)
    }

    func updateNote(_ note: ModuleNote, text: String) {
        if let index = moduleNotes.firstIndex(where: { $0.id == note.id }) {
            moduleNotes[index].text = text
        }
    }

    func deleteNote(_ note: ModuleNote) {
        moduleNotes.removeAll { $0.id == note.id }
    }

    // MARK: - Module Groups

    func groups(forModule moduleID: UUID) -> [ModuleGroup] {
        moduleGroups.filter { $0.placedModuleIDs.contains(moduleID) }
    }

    func addGroup(_ group: ModuleGroup) {
        moduleGroups.append(group)
    }

    func deleteGroup(_ groupID: UUID) {
        moduleGroups.removeAll { $0.id == groupID }
    }

    func toggleModuleInGroup(moduleID: UUID, groupID: UUID) {
        guard let index = moduleGroups.firstIndex(where: { $0.id == groupID }) else { return }
        if let pos = moduleGroups[index].placedModuleIDs.firstIndex(of: moduleID) {
            moduleGroups[index].placedModuleIDs.remove(at: pos)
        } else {
            moduleGroups[index].placedModuleIDs.append(moduleID)
        }
    }
}

// MARK: - Tolerant decoding
// Fields with defaults are decoded with decodeIfPresent so files written before
// they existed still load.

extension ModuleGroup {
    enum CodingKeys: String, CodingKey {
        case id, name, notes, colorIndex, placedModuleIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        placedModuleIDs = try container.decodeIfPresent([UUID].self, forKey: .placedModuleIDs) ?? []
    }
}

extension ScreenImage {
    enum CodingKeys: String, CodingKey {
        case id, placedModuleID, controlID, imageFilenames, activeIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        placedModuleID = try container.decode(UUID.self, forKey: .placedModuleID)
        controlID = try container.decode(UUID.self, forKey: .controlID)
        imageFilenames = try container.decodeIfPresent([String].self, forKey: .imageFilenames) ?? []
        activeIndex = try container.decodeIfPresent(Int.self, forKey: .activeIndex) ?? 0
    }
}
