import Foundation
import PDFKit
import Testing
@testable import WordSearchApp

struct PuzzlePDFExporterTests {
    @Test func fileNameIsSanitizedAndStable() {
        #expect(PuzzlePDFExporter.fileName(for: "  Cabin Trip: 2026 / Puzzle  ") == "Cabin-Trip-2026-Puzzle.pdf")
        #expect(PuzzlePDFExporter.fileName(for: "!!!") == "Word-Search-Puzzle.pdf")
    }

    @Test func layoutIsDeterministicForTheSamePuzzle() {
        let puzzle = samplePuzzle()

        let layoutA = PuzzlePDFExporter.layout(for: puzzle, title: "Cabin Trip")
        let layoutB = PuzzlePDFExporter.layout(for: puzzle, title: "Cabin Trip")

        #expect(layoutA == layoutB)
        #expect(layoutA.gridFrame.width == layoutA.gridFrame.height)
        #expect(layoutA.gridCellSize > 0)
        #expect(layoutA.wordColumns >= 1)
    }

    @Test func pdfMetadataUsesTheProvidedTitleAndAppIdentity() {
        let puzzle = samplePuzzle()
        let data = PuzzlePDFExporter.pdfData(for: puzzle, title: "Cabin Trip")
        let document = PDFDocument(data: data)

        #expect(document != nil)

        guard let document else {
            Issue.record("Expected a PDFDocument")
            return
        }

        #expect(document.pageCount == 1)

        let attributes = document.documentAttributes ?? [:]
        #expect(attributes[PDFDocumentAttribute.titleAttribute] as? String == "Cabin Trip")
        #expect(attributes[PDFDocumentAttribute.authorAttribute] as? String == "WordSearchApp")
        #expect(attributes[PDFDocumentAttribute.creatorAttribute] as? String == "WordSearchApp")
        #expect(attributes[PDFDocumentAttribute.subjectAttribute] as? String == "Word Search Puzzle")
    }

    @Test func shareableFileURLWritesAPDFToTemporaryStorage() throws {
        let puzzle = samplePuzzle()
        let url = try PuzzlePDFExporter.shareableFileURL(for: puzzle, title: "Cabin Trip")

        defer {
            try? FileManager.default.removeItem(at: url)
        }

        #expect(url.lastPathComponent == "Cabin-Trip.pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))

        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty)
        #expect(PDFDocument(data: data)?.pageCount == 1)
    }

    private func samplePuzzle() -> WordSearchPuzzle {
        let alphabet = Array("ABCDEFGHIJKLMNOP")

        let grid: [[String]] = (0..<12).map { row in
            (0..<12).map { column in
                String(alphabet[(row + column) % alphabet.count])
            }
        }

        return WordSearchPuzzle(
            size: 12,
            grid: grid,
            words: ["CAT", "DOG", "BIRD", "FISH", "OWL", "MOOSE"]
        )
    }
}
