#if os(macOS)
import AppKit
import PDFKit
import UniformTypeIdentifiers

/// macOS has no share sheet for files: PDFs are saved through a save panel or sent to the print panel.
@MainActor
enum MacPDF {
    /// Asks where to save the puzzle PDF. Returns false only when writing failed; cancelling is not a failure.
    static func save(puzzle: WordSearchPuzzle, title: String) -> Bool {
        guard let temporaryURL = try? PuzzlePDFExporter.shareableFileURL(for: puzzle, title: title) else {
            return false
        }
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = temporaryURL.lastPathComponent
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destination = panel.url else { return true }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: temporaryURL, to: destination)
            return true
        } catch {
            return false
        }
    }

    /// Opens the system print panel for the puzzle. Returns false if the PDF could not be prepared.
    static func printPuzzle(_ puzzle: WordSearchPuzzle, title: String) -> Bool {
        let data = PuzzlePDFExporter.pdfData(for: puzzle, title: title)
        guard let document = PDFDocument(data: data),
              let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo,
              let operation = document.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true) else {
            return false
        }

        operation.jobTitle = title
        operation.run()
        return true
    }
}
#endif
