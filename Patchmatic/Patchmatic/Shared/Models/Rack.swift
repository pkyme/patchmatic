import Foundation

enum RowSize: String, Codable, CaseIterable {
    case threeU = "3U"
    case oneU = "1U"

    var height: CGFloat {
        switch self {
        case .threeU: return EurorackConstants.panelHeight
        case .oneU: return EurorackConstants.panelHeight1U
        }
    }

    /// Physical panel height in millimetres
    var heightMM: Double {
        switch self {
        case .threeU: return 128.5
        case .oneU: return 39.65
        }
    }
}

struct RackRow: Codable, Identifiable, Hashable {
    var id = UUID()
    var size: RowSize

    init(id: UUID = UUID(), size: RowSize = .threeU) {
        self.id = id
        self.size = size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        size = try container.decodeIfPresent(RowSize.self, forKey: .size) ?? .threeU
    }

    enum CodingKeys: String, CodingKey {
        case id, size
    }
}

// MARK: - Case

@Observable
final class Case: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var rows: [RackRow]
    var rowWidthHP: Int
    var placedModules: [PlacedModule]
    /// Position on the free-form canvas (top-left of case content area)
    var positionX: CGFloat
    var positionY: CGFloat

    init(id: UUID = UUID(), name: String = "Case", rows: [RackRow] = [RackRow(), RackRow()], rowWidthHP: Int = 104, placedModules: [PlacedModule] = [], positionX: CGFloat = 0, positionY: CGFloat = 0) {
        self.id = id
        self.name = name
        self.rows = rows
        self.rowWidthHP = rowWidthHP
        self.placedModules = placedModules
        self.positionX = positionX
        self.positionY = positionY
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, rows, rowWidthHP, placedModules, positionX, positionY
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rows = try container.decode([RackRow].self, forKey: .rows)
        rowWidthHP = try container.decode(Int.self, forKey: .rowWidthHP)
        placedModules = try container.decode([PlacedModule].self, forKey: .placedModules)
        positionX = try container.decodeIfPresent(CGFloat.self, forKey: .positionX) ?? 0
        positionY = try container.decodeIfPresent(CGFloat.self, forKey: .positionY) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rows, forKey: .rows)
        try container.encode(rowWidthHP, forKey: .rowWidthHP)
        try container.encode(placedModules, forKey: .placedModules)
        try container.encode(positionX, forKey: .positionX)
        try container.encode(positionY, forKey: .positionY)
    }

    // MARK: - Hashable

    static func == (lhs: Case, rhs: Case) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Helpers

    func modules(inRow row: Int) -> [PlacedModule] {
        placedModules
            .filter { $0.rowIndex == row }
            .sorted { $0.positionInRow < $1.positionInRow }
    }

    /// First position in `row` with a gap of at least `moduleWidth` HP.
    /// `widthOf` returns the width in HP of a module already in the row.
    func nextAvailablePosition(inRow row: Int, moduleWidth: Int, widthOf: (PlacedModule) -> Int) -> Int? {
        let rowModules = modules(inRow: row)
        var cursor = 0
        for module in rowModules {
            if module.positionInRow >= cursor + moduleWidth {
                return cursor
            }
            cursor = max(cursor, module.positionInRow + widthOf(module))
        }
        if cursor + moduleWidth <= rowWidthHP {
            return cursor
        }
        return nil
    }

    func rowAt(y: CGFloat) -> Int? {
        var offset: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let bottom = offset + row.size.height
            if y >= offset && y < bottom {
                return i
            }
            offset = bottom + EurorackConstants.rowSpacing
        }
        return nil
    }

    func rowYOffset(_ rowIndex: Int) -> CGFloat {
        var y: CGFloat = 0
        for i in 0..<min(rowIndex, rows.count) {
            y += rows[i].size.height + EurorackConstants.rowSpacing
        }
        return y
    }

    func totalHeight() -> CGFloat {
        guard !rows.isEmpty else { return 0 }
        let heights = rows.map { $0.size.height }
        return heights.reduce(0, +) + CGFloat(rows.count - 1) * EurorackConstants.rowSpacing
    }
}

// MARK: - Rack

@Observable
final class Rack: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var cases: [Case]

    init(id: UUID = UUID(), name: String = "Rack", cases: [Case] = [Case()]) {
        self.id = id
        self.name = name
        self.cases = cases
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, cases
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cases = try container.decode([Case].self, forKey: .cases)
        migrateToFreePositioning(caseHeaderHeight: Self.legacyCaseHeaderHeight)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(cases, forKey: .cases)
    }

    // MARK: - Hashable

    static func == (lhs: Rack, rhs: Rack) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Helpers

    /// Default spacing used when laying out cases vertically for migration
    static let caseSpacing: CGFloat = 24.0

    /// Find which case a placed module belongs to
    func caseForModule(_ moduleID: UUID) -> Case? {
        cases.first { c in c.placedModules.contains { $0.id == moduleID } }
    }

    /// Find a placed module by ID across all cases
    func placedModule(_ moduleID: UUID) -> PlacedModule? {
        for c in cases {
            if let placed = c.placedModules.first(where: { $0.id == moduleID }) {
                return placed
            }
        }
        return nil
    }

    /// Bounding box of all cases on the canvas
    func boundingBox() -> CGRect {
        guard !cases.isEmpty else { return .zero }
        var minX: CGFloat = .greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        for c in cases {
            let w = EurorackConstants.width(forHP: c.rowWidthHP)
            minX = min(minX, c.positionX)
            minY = min(minY, c.positionY)
            maxX = max(maxX, c.positionX + w)
            maxY = max(maxY, c.positionY + c.totalHeight())
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Approximate case header height used to space cases when migrating legacy layouts
    static let legacyCaseHeaderHeight: CGFloat = 28

    /// Migrate legacy documents where all cases are at (0,0) to a vertical stack layout
    func migrateToFreePositioning(caseHeaderHeight: CGFloat) {
        let allDefault = cases.allSatisfy { $0.positionX == 0 && $0.positionY == 0 }
        guard allDefault, cases.count > 1 else { return }
        var y: CGFloat = 0
        for rackCase in cases {
            rackCase.positionX = 0
            rackCase.positionY = y
            y += caseHeaderHeight + rackCase.totalHeight() + Self.caseSpacing
        }
    }
}
