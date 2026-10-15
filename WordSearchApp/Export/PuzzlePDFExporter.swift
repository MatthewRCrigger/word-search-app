import Foundation

#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
private typealias PlatformColor = NSColor
#endif

enum PuzzlePDFExporter {
    struct Layout: Equatable {
        let pageRect: CGRect
        let contentRect: CGRect
        let titleFrame: CGRect
        let gridFrame: CGRect
        let wordListFrame: CGRect
        let gridCellSize: CGFloat
        let wordColumns: Int
    }

    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let contentInset: CGFloat = 36
    private static let titleFont = PlatformFont.systemFont(ofSize: 28, weight: .bold)
    private static let titleColor = PlatformColor.black
    private static let gridLineColor = PlatformColor.black
    private static let gridLineWidth: CGFloat = 1
    private static let wordFont = PlatformFont.systemFont(ofSize: 11, weight: .semibold)
    private static let wordLineHeight: CGFloat = 16
    private static let wordColumnSpacing: CGFloat = 10
    private static let sectionSpacing: CGFloat = 18
    private static let documentCreator = "WordSearchApp"
    private static let documentSubject = "Word Search Puzzle"
    private static let defaultPDFExtension = "pdf"

    static func pdfData(for puzzle: WordSearchPuzzle, title: String) -> Data {
        let documentInfo: [String: Any] = [
            kCGPDFContextTitle as String: normalizedTitle(title),
            kCGPDFContextAuthor as String: documentCreator,
            kCGPDFContextCreator as String: documentCreator,
            kCGPDFContextSubject as String: documentSubject,
        ]
        let layout = layout(for: puzzle, title: title)

        #if canImport(UIKit)
        let rendererFormat = UIGraphicsPDFRendererFormat()
        rendererFormat.documentInfo = documentInfo

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: rendererFormat)
        return renderer.pdfData { context in
            context.beginPage()
            drawPage(for: puzzle, title: title, layout: layout)
        }
        #else
        let data = NSMutableData()
        var mediaBox = pageRect
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, documentInfo as CFDictionary) else {
            return Data()
        }

        context.beginPDFPage(nil)
        // Flip to a top-left origin so the shared layout math matches UIKit's.
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)

        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        drawPage(for: puzzle, title: title, layout: layout)
        NSGraphicsContext.current = previousContext

        context.endPDFPage()
        context.closePDF()
        return data as Data
        #endif
    }

    static func shareableFileURL(
        for puzzle: WordSearchPuzzle,
        title: String,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let fileURL = directory.appendingPathComponent(fileName(for: title))
        let data = pdfData(for: puzzle, title: title)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    #if canImport(UIKit)
    @MainActor
    @discardableResult
    static func presentPrintInteractionController(
        for puzzle: WordSearchPuzzle,
        title: String,
        from sourceView: UIView,
        completion: UIPrintInteractionController.CompletionHandler? = nil
    ) -> Bool {
        do {
            let fileURL = try shareableFileURL(for: puzzle, title: title)

            guard UIPrintInteractionController.canPrint(fileURL) else {
                return false
            }

            let printController = UIPrintInteractionController.shared
            let printInfo = UIPrintInfo.printInfo()
            printInfo.jobName = normalizedTitle(title)
            printInfo.outputType = .general
            printController.printInfo = printInfo
            printController.printingItem = fileURL

            return printController.present(
                from: sourceView.bounds,
                in: sourceView,
                animated: true,
                completionHandler: completion
            )
        } catch {
            return false
        }
    }
    #endif

    static func layout(for puzzle: WordSearchPuzzle, title: String, pageRect: CGRect = pageRect) -> Layout {
        let contentRect = pageRect.insetBy(dx: contentInset, dy: contentInset)
        let titleHeight = max(lineHeight(of: titleFont) + 8, 34)
        let titleFrame = CGRect(
            x: contentRect.minX,
            y: contentRect.minY,
            width: contentRect.width,
            height: titleHeight
        )

        let bodyTop = titleFrame.maxY + sectionSpacing
        let bodyHeight = max(0, contentRect.maxY - bodyTop)

        let maxWordWidth = puzzle.words.map { word in
            (word as NSString).size(withAttributes: [.font: wordFont]).width
        }.max() ?? 0

        let estimatedColumns = puzzle.words.count >= 18 ? 3 : puzzle.words.count >= 9 ? 2 : 1
        let minWordListWidth = max(140, min(210, maxWordWidth + 24))
        let gridMaxWidth = max(0, contentRect.width - sectionSpacing - minWordListWidth)
        let cellSize = max(1, floor(min(gridMaxWidth / CGFloat(puzzle.size), bodyHeight / CGFloat(puzzle.size))))
        let gridSide = cellSize * CGFloat(puzzle.size)

        let gridFrame = CGRect(
            x: contentRect.minX,
            y: bodyTop + max(0, (bodyHeight - gridSide) / 2),
            width: gridSide,
            height: gridSide
        )

        let wordListFrame = CGRect(
            x: gridFrame.maxX + sectionSpacing,
            y: bodyTop,
            width: max(0, contentRect.maxX - (gridFrame.maxX + sectionSpacing)),
            height: bodyHeight
        )

        let fittingColumns = max(
            1,
            Int(floor((wordListFrame.width + wordColumnSpacing) / max(1, maxWordWidth + wordColumnSpacing)))
        )
        let wordColumns = max(1, min(3, min(estimatedColumns, fittingColumns)))

        return Layout(
            pageRect: pageRect,
            contentRect: contentRect,
            titleFrame: titleFrame,
            gridFrame: gridFrame,
            wordListFrame: wordListFrame,
            gridCellSize: cellSize,
            wordColumns: wordColumns
        )
    }

    static func fileName(for title: String) -> String {
        let cleanedComponents = normalizedTitle(title)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        let baseName = cleanedComponents.isEmpty ? "Word-Search-Puzzle" : cleanedComponents.joined(separator: "-")
        return "\(baseName).\(defaultPDFExtension)"
    }

    private static func drawPage(for puzzle: WordSearchPuzzle, title: String, layout: Layout) {
        #if canImport(UIKit)
        let currentContext = UIGraphicsGetCurrentContext()
        #else
        let currentContext = NSGraphicsContext.current?.cgContext
        #endif
        guard let context = currentContext else { return }

        drawTitle(title, in: layout.titleFrame)
        drawGrid(puzzle, in: layout.gridFrame, cellSize: layout.gridCellSize, context: context)
        drawWordList(puzzle.words, in: layout.wordListFrame, columns: layout.wordColumns)
    }

    private static func drawTitle(_ title: String, in frame: CGRect) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: titleColor,
            .paragraphStyle: paragraphStyle
        ]

        (normalizedTitle(title) as NSString).draw(in: frame, withAttributes: attributes)
    }

    private static func drawGrid(_ puzzle: WordSearchPuzzle, in frame: CGRect, cellSize: CGFloat, context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        context.setStrokeColor(gridLineColor.cgColor)
        context.setLineWidth(gridLineWidth)

        let linePath = CGMutablePath()
        linePath.addRect(frame)
        for row in 0...puzzle.size {
            let y = frame.minY + CGFloat(row) * cellSize
            linePath.move(to: CGPoint(x: frame.minX, y: y))
            linePath.addLine(to: CGPoint(x: frame.maxX, y: y))
        }

        for column in 0...puzzle.size {
            let x = frame.minX + CGFloat(column) * cellSize
            linePath.move(to: CGPoint(x: x, y: frame.minY))
            linePath.addLine(to: CGPoint(x: x, y: frame.maxY))
        }

        context.addPath(linePath)
        context.strokePath()

        let letterFont = PlatformFont.systemFont(ofSize: max(8, min(18, cellSize * 0.56)), weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping

        let letterAttributes: [NSAttributedString.Key: Any] = [
            .font: letterFont,
            .foregroundColor: PlatformColor.black,
            .paragraphStyle: paragraphStyle
        ]

        for (rowIndex, row) in puzzle.grid.enumerated() {
            for (columnIndex, letter) in row.enumerated() {
                let cellRect = CGRect(
                    x: frame.minX + CGFloat(columnIndex) * cellSize,
                    y: frame.minY + CGFloat(rowIndex) * cellSize,
                    width: cellSize,
                    height: cellSize
                )

                (letter as NSString).draw(in: cellRect.insetBy(dx: 1, dy: 1), withAttributes: letterAttributes)
            }
        }
    }

    private static func drawWordList(_ words: [String], in frame: CGRect, columns: Int) {
        guard !words.isEmpty, columns > 0 else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: wordFont,
            .foregroundColor: PlatformColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let columnWidth = (frame.width - wordColumnSpacing * CGFloat(columns - 1)) / CGFloat(columns)
        let rows = Int(ceil(Double(words.count) / Double(columns)))
        let maxRows = max(1, rows)

        for (index, word) in words.enumerated() {
            let column = index / maxRows
            let row = index % maxRows

            guard column < columns else { continue }

            let x = frame.minX + CGFloat(column) * (columnWidth + wordColumnSpacing)
            let y = frame.minY + CGFloat(row) * wordLineHeight
            let wordFrame = CGRect(x: x, y: y, width: columnWidth, height: wordLineHeight)
            (word as NSString).draw(in: wordFrame, withAttributes: attributes)
        }
    }

    private static func lineHeight(of font: PlatformFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }

    private static func normalizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Word Search Puzzle" : trimmed
    }
}
