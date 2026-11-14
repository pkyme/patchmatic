import SwiftUI

/// A patch's position and name in a set's patch list, followed by an optional accessory.
struct SetPatchRow<Accessory: View>: View {
    /// One-based position in the set
    let position: Int
    let name: String
    var numberWidth: CGFloat = 24
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack {
            Text("\(position).")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: numberWidth, alignment: .trailing)
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
    }
}
