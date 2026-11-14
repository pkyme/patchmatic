import Foundation

@Observable
final class ModuleDefinition: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var format: RowSize
    var widthHP: Int
    var controls: [Control]
    var imageFileName: String?

    init(id: UUID = UUID(), name: String = "New Module", format: RowSize = .threeU, widthHP: Int = 8, controls: [Control] = [], imageFileName: String? = nil) {
        self.id = id
        self.name = name
        self.format = format
        self.widthHP = widthHP
        self.controls = controls
        self.imageFileName = imageFileName
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, format, widthHP, controls, imageFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        format = try container.decodeIfPresent(RowSize.self, forKey: .format) ?? .threeU
        widthHP = try container.decode(Int.self, forKey: .widthHP)
        controls = try container.decode([Control].self, forKey: .controls)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(format, forKey: .format)
        try container.encode(widthHP, forKey: .widthHP)
        try container.encode(controls, forKey: .controls)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
    }

    /// Panel height in points based on format
    var panelHeight: CGFloat {
        format.height
    }

    // MARK: - Hashable

    static func == (lhs: ModuleDefinition, rhs: ModuleDefinition) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
