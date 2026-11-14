import SwiftUI
#if canImport(AppKit)

struct CableColorGrid: View {
    let palette: [Color]
    let onSelect: (Int) -> Void

    private let colorColumns = Array(repeating: GridItem(.fixed(28), spacing: 6), count: 5)
    private let grayColumn = [GridItem(.fixed(28))]

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            LazyVGrid(columns: colorColumns, spacing: 6) {
                ForEach(0..<20, id: \.self) { index in
                    ColorSwatch(color: palette[index]) { onSelect(index) }
                }
            }
            LazyVGrid(columns: grayColumn, spacing: 6) {
                ForEach(0..<4, id: \.self) { offset in
                    ColorSwatch(color: palette[20 + offset]) { onSelect(20 + offset) }
                }
            }
        }
        .padding(8)
    }
}

private struct ColorSwatch: View {
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 24, height: 24)
            .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
            .scaleEffect(isHovered ? 1.25 : 1.0)
            .shadow(color: isHovered ? color.opacity(0.5) : .clear, radius: 4)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
            .onTapGesture(perform: action)
    }
}
#endif
