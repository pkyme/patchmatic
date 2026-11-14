import SwiftUI

// MARK: - Floating group list

struct MaxTitleWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct FloatingGroupList: View {
    let groups: [ModuleGroup]
    let patchVM: PatchViewModel
    var readOnly: Bool = false
    let onEditNotes: (ModuleGroup) -> Void
    let onRenameGroup: (ModuleGroup) -> Void
    let onDeleteGroup: (UUID) -> Void
    let onFocusGroup: (ModuleGroup) -> Void

    @State private var titleWidth: CGFloat = 200

    private func cardContent(for group: ModuleGroup, expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if !group.notes.isEmpty {
                Text(group.notes)
                    .font(.system(size: 10))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxHeight: expanded ? nil : 0, alignment: .top)
                    .clipped()
            }
        }
        .frame(width: expanded ? 200 : titleWidth, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .geometryGroup()
    }

    @ViewBuilder
    private func groupCard(for group: ModuleGroup, activeIDs: Set<UUID>, anyHovered: Bool) -> some View {
        let isHovered = activeIDs.contains(group.id)
        let fillColor: Color = anyHovered && !isHovered
            ? .gray
            : GroupPalette.color(forIndex: group.colorIndex)
        let listHovered = !patchVM.hoveredGroupIDs.isEmpty
        let idle = !listHovered
        let fillOpacity: Double = isHovered ? 0.6 : (anyHovered ? 0.15 : (listHovered ? 0.35 : 0.15))
        let textOpacity: Double = anyHovered && !isHovered ? 0.5 : (listHovered || isHovered ? 1.0 : 0.45)

        cardContent(for: group, expanded: listHovered)
        .foregroundStyle(.white.opacity(textOpacity))
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 6)
                    .fill(.regularMaterial)
                    .opacity(listHovered ? 1 : 0)
                RoundedRectangle(cornerRadius: 6)
                    .fill(fillColor.opacity(fillOpacity))
                RoundedRectangle(cornerRadius: 6)
                    .stroke(fillColor.opacity(fillOpacity + 0.2), lineWidth: 1)
            }
        )
        .opacity(idle ? 0.75 : 1.0)
        .shadow(color: .black.opacity(listHovered ? 0.35 : 0.15), radius: listHovered ? 6 : 3, x: 0, y: listHovered ? 3 : 1)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                patchVM.hoveredGroupIDs = [group.id]
            } else {
                patchVM.hoveredGroupIDs = []
            }
        }
        .onTapGesture {
            onFocusGroup(group)
        }
        .contextMenu {
            if !readOnly {
                Button("Rename...") {
                    onRenameGroup(group)
                }
                Button("Edit Notes...") {
                    onEditNotes(group)
                }
                Divider()
                Button("Delete Group", role: .destructive) {
                    onDeleteGroup(group.id)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: [isHovered, anyHovered, listHovered])
    }

    var body: some View {
        let activeIDs = patchVM.hoveredGroupIDs.isEmpty ? patchVM.moduleHoverGroupIDs : patchVM.hoveredGroupIDs
        let anyHovered = !activeIDs.isEmpty
        VStack(spacing: 0) {
            ForEach(groups) { group in
                groupCard(for: group, activeIDs: activeIDs, anyHovered: anyHovered)
            }
        }
        .padding(8)
        .background {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(groups) { group in
                    Text(group.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .hidden()
            .background(GeometryReader { geo in
                Color.clear.preference(key: MaxTitleWidthKey.self, value: geo.size.width)
            })
        }
        .onPreferenceChange(MaxTitleWidthKey.self) { width in
            if width > 0 { titleWidth = width }
        }
        .animation(.easeInOut(duration: 0.2), value: groups.map(\.id))
    }
}
