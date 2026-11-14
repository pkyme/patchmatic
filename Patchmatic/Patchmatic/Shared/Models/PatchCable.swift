import Foundation
import SwiftUI

struct CablePin: Codable, Identifiable, Hashable {
    var id = UUID()
    var x: CGFloat
    var y: CGFloat
    /// If set, x/y are offsets from case origin; pin moves with the case
    var caseID: UUID?
    /// Order along the cable (0 = first pin after start)
    var sortIndex: Int

    var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set { x = newValue.x; y = newValue.y }
    }
}

struct PatchCable: Codable, Identifiable, Hashable {
    var id = UUID()
    var fromModuleID: UUID
    var fromControlID: UUID
    var toModuleID: UUID
    var toControlID: UUID
    /// Index into the cable color palette, assigned automatically on creation
    var colorIndex: Int = 0
    /// Optional custom color override (RGBA components)
    var customColor: CableColor?
    /// Intermediate fixed points that divide the cable into segments
    var pins: [CablePin] = []

    var orderedPins: [CablePin] {
        pins.sorted { $0.sortIndex < $1.sortIndex }
    }

    var segmentCount: Int { pins.count + 1 }

    /// Deterministic rope ID for a segment. Returns cable ID when no pins for backward compat.
    func segmentRopeID(_ segmentIndex: Int) -> UUID {
        if pins.isEmpty { return id }
        var bytes = id.uuid
        // Flip bit 7 of byte 12 to mark this as a segment rope (ensures segmentRopeID(0) ≠ cable.id),
        // then encode the segment index across bytes 13 and 15 for collision resistance.
        bytes.12 ^= 0x80
        bytes.13 ^= UInt8((segmentIndex >> 8) & 0xFF)
        bytes.15 ^= UInt8(segmentIndex & 0xFF)
        return UUID(uuid: bytes)
    }

    enum CodingKeys: String, CodingKey {
        case id, fromModuleID, fromControlID, toModuleID, toControlID, colorIndex, customColor, pins
    }

    init(id: UUID = UUID(), fromModuleID: UUID, fromControlID: UUID, toModuleID: UUID, toControlID: UUID, colorIndex: Int = 0, customColor: CableColor? = nil, pins: [CablePin] = []) {
        self.id = id
        self.fromModuleID = fromModuleID
        self.fromControlID = fromControlID
        self.toModuleID = toModuleID
        self.toControlID = toControlID
        self.colorIndex = colorIndex
        self.customColor = customColor
        self.pins = pins
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fromModuleID = try container.decode(UUID.self, forKey: .fromModuleID)
        fromControlID = try container.decode(UUID.self, forKey: .fromControlID)
        toModuleID = try container.decode(UUID.self, forKey: .toModuleID)
        toControlID = try container.decode(UUID.self, forKey: .toControlID)
        colorIndex = try container.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        customColor = try container.decodeIfPresent(CableColor.self, forKey: .customColor)
        pins = try container.decodeIfPresent([CablePin].self, forKey: .pins) ?? []
    }
}

struct CableColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1.0

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

}

// MARK: - Tolerant decoding

extension CablePin {
    enum CodingKeys: String, CodingKey {
        case id, x, y, caseID, sortIndex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        x = try container.decode(CGFloat.self, forKey: .x)
        y = try container.decode(CGFloat.self, forKey: .y)
        caseID = try container.decodeIfPresent(UUID.self, forKey: .caseID)
        sortIndex = try container.decodeIfPresent(Int.self, forKey: .sortIndex) ?? 0
    }
}

extension CableColor {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
    }
}
