import SwiftUI

struct CaseView: View {
    var rackCase: Case
    var rackVM: RackViewModel
    var patchVM: PatchViewModel
    var showKnobValues: Bool
    var labelsIgnoreActivation: Bool = false
    var isDarkMode: Bool = false
    var zoom: CGFloat = 1.0
    var actions = RackRowActions()
    var pressedControlID: UUID? = nil
    /// Hovered control highlight; nil where controls don't highlight on hover
    var hoverAnimator: HoverAnimator? = nil
    var readOnly: Bool = false

    @State private var showingHPPopover = false
    @State private var hpInput: String = ""
    @State private var hpHovered = false
    @State private var showingNamePopover = false
    @State private var nameInput: String = ""
    @State private var nameHovered = false

    var body: some View {
        let caseWidth = EurorackConstants.width(forHP: rackCase.rowWidthHP) * zoom

        VStack(spacing: 0) {
            if !showKnobValues {
                HStack {
                    Button {
                        nameInput = rackCase.name
                        showingNamePopover = true
                    } label: {
                        Text(rackCase.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(nameHovered ? Color.primary.opacity(0.08) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .onHover { nameHovered = $0 }
                    .popover(isPresented: $showingNamePopover) {
                        TextField("Name", text: $nameInput)
                            .frame(width: 160)
                            .onSubmit {
                                let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty {
                                    rackVM.renameCase(rackCase, to: trimmed)
                                }
                                showingNamePopover = false
                            }
                            .padding(10)
                    }
                    Spacer()
                    Button {
                        hpInput = "\(rackCase.rowWidthHP)"
                        showingHPPopover = true
                    } label: {
                        Text("\(rackCase.rowWidthHP) HP")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(hpHovered ? Color.primary.opacity(0.08) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .onHover { hpHovered = $0 }
                    .popover(isPresented: $showingHPPopover) {
                        HStack {
                            TextField("HP", text: $hpInput)
                                .frame(width: 60)
                                .multilineTextAlignment(.center)
                                .onSubmit {
                                    if let value = Int(hpInput),
                                       value >= EurorackConstants.minModuleHP,
                                       value <= EurorackConstants.maxModuleHP {
                                        rackVM.setCaseWidthHP(rackCase, to: value)
                                    }
                                    showingHPPopover = false
                                }
                            Text("HP")
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                    }

                    Menu {
                        Button("Add 3U Row") {
                            rackVM.addRow(to: rackCase, size: .threeU)
                        }
                        Button("Add 1U Row") {
                            rackVM.addRow(to: rackCase, size: .oneU)
                        }
                        if !rackCase.rows.isEmpty {
                            Divider()
                            Menu("Remove Row") {
                                ForEach(Array(rackCase.rows.enumerated()), id: \.element.id) { index, row in
                                    Button("Row \(index + 1) (\(row.size.rawValue))", role: .destructive) {
                                        rackVM.removeRow(from: rackCase, at: index)
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Add 3U Row") {
                        rackVM.addRow(to: rackCase, size: .threeU)
                    }
                    Button("Add 1U Row") {
                        rackVM.addRow(to: rackCase, size: .oneU)
                    }
                    if !rackCase.rows.isEmpty {
                        Divider()
                        Menu("Remove Row") {
                            ForEach(Array(rackCase.rows.enumerated()), id: \.element.id) { index, row in
                                Button("Row \(index + 1) (\(row.size.rawValue))", role: .destructive) {
                                    rackVM.removeRow(from: rackCase, at: index)
                                }
                            }
                        }
                    }
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.onAppear { rackVM.caseHeaderHeight = proxy.size.height }
                    }
                }
                .overlay {
                    GeometryReader { geo in
                        let r: CGFloat = 4
                        let w = geo.size.width
                        let h = geo.size.height
                        Path { p in
                            // Left side up, top with rounded corners, right side down — no bottom edge
                            p.move(to: CGPoint(x: 0, y: h))
                            p.addLine(to: CGPoint(x: 0, y: r))
                            p.addArc(center: CGPoint(x: r, y: r), radius: r,
                                     startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
                            p.addLine(to: CGPoint(x: w - r, y: 0))
                            p.addArc(center: CGPoint(x: w - r, y: r), radius: r,
                                     startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
                            p.addLine(to: CGPoint(x: w, y: h))
                        }
                        .stroke(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    }
                }
            }

            VStack(spacing: EurorackConstants.rowSpacing * zoom) {
                ForEach(Array(rackCase.rows.enumerated()), id: \.element.id) { rowIndex, row in
                    RackRowView(
                        rackCase: rackCase,
                        rowIndex: rowIndex,
                        rowHeight: row.size.height * zoom,
                        rackVM: rackVM,
                        patchVM: patchVM,
                        showKnobValues: showKnobValues,
                        labelsIgnoreActivation: labelsIgnoreActivation,
                        isDarkMode: isDarkMode,
                        zoom: zoom,
                        actions: actions,
                        pressedControlID: pressedControlID,
                        hoverAnimator: hoverAnimator,
                        readOnly: readOnly
                    )
                }
            }
        }
        .frame(width: caseWidth)
        .overlay {
            if !showKnobValues, rackVM.selectedCaseIDs.contains(rackCase.id) {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2 * zoom)
                    .allowsHitTesting(false)
            }
        }
    }
}
