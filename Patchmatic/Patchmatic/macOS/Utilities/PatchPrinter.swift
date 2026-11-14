import SwiftUI
import AppKit

@MainActor
enum PatchPrinter {
    static func print(rack: Rack, patch: Patch, rackVM: RackViewModel,
                      patchVM: PatchViewModel, isDarkMode: Bool,
                      showPatchNumbers: Bool) {
        let printView = PatchPrintView(
            rack: rack,
            patch: patch,
            rackVM: rackVM,
            patchVM: patchVM,
            isDarkMode: isDarkMode,
            showPatchNumbers: showPatchNumbers
        )
        .environment(\.drawsShadows, false)

        let renderer = ImageRenderer(content: printView)
        renderer.scale = 1.0

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PatchPrint-\(UUID().uuidString).pdf")

        var pdfSize = CGSize.zero
        renderer.render { size, renderFunc in
            pdfSize = size
            var box = CGRect(origin: .zero, size: size)
            guard let ctx = CGContext(tempURL as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            renderFunc(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
        }

        guard let pdfDoc = CGPDFDocument(tempURL as CFURL),
              pdfDoc.numberOfPages > 0
        else {
            try? FileManager.default.removeItem(at: tempURL)
            return
        }

        let printableView = PDFPagePrintView(pdfDocument: pdfDoc, size: pdfSize)

        guard let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo else { return }
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.orientation = pdfSize.width > pdfSize.height ? .landscape : .portrait
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true
        printInfo.topMargin = 18
        printInfo.bottomMargin = 18
        printInfo.leftMargin = 18
        printInfo.rightMargin = 18

        let printOp = NSPrintOperation(view: printableView, printInfo: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            printOp.run()
        }

        try? FileManager.default.removeItem(at: tempURL)
    }
}

/// Draws a PDF page directly via Core Graphics for accurate print output
private class PDFPagePrintView: NSView {
    let pdfDocument: CGPDFDocument

    init(pdfDocument: CGPDFDocument, size: CGSize) {
        self.pdfDocument = pdfDocument
        super.init(frame: CGRect(origin: .zero, size: size))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let page = pdfDocument.page(at: 1) else { return }
        let mediaBox = page.getBoxRect(.mediaBox)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: bounds.width / mediaBox.width,
                    y: -bounds.height / mediaBox.height)
        ctx.drawPDFPage(page)
        ctx.restoreGState()
    }
}
