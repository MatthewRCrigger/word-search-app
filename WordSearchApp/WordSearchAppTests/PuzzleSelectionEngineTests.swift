import Testing
@testable import WordSearchApp

struct PuzzleSelectionEngineTests {
    private func makePuzzle() -> WordSearchPuzzle {
        WordSearchPuzzle(
            size: 4,
            grid: [
                ["C", "A", "T", "X"],
                ["X", "X", "X", "X"],
                ["X", "X", "X", "X"],
                ["X", "D", "O", "G"]
            ],
            words: ["CAT", "DOG"]
        )
    }

    @Test func pathSupportsStraightLinesInEightDirections() {
        let engine = PuzzleSelectionEngine(puzzle: makePuzzle())

        #expect(engine.path(from: .init(row: 0, column: 0), to: .init(row: 0, column: 2)) == [
            .init(row: 0, column: 0),
            .init(row: 0, column: 1),
            .init(row: 0, column: 2)
        ])

        #expect(engine.path(from: .init(row: 0, column: 1), to: .init(row: 3, column: 1)) == [
            .init(row: 0, column: 1),
            .init(row: 1, column: 1),
            .init(row: 2, column: 1),
            .init(row: 3, column: 1)
        ])

        #expect(engine.path(from: .init(row: 0, column: 2), to: .init(row: 2, column: 0)) == [
            .init(row: 0, column: 2),
            .init(row: 1, column: 1),
            .init(row: 2, column: 0)
        ])
    }

    @Test func pathRejectsNonStraightSelections() {
        let engine = PuzzleSelectionEngine(puzzle: makePuzzle())

        #expect(engine.path(from: .init(row: 0, column: 0), to: .init(row: 1, column: 2)) == nil)
    }

    @Test func reverseSelectionMatchesHiddenWord() {
        let engine = PuzzleSelectionEngine(puzzle: makePuzzle())
        let path = engine.path(from: .init(row: 0, column: 2), to: .init(row: 0, column: 0))

        #expect(path != nil)

        guard let path else {
            Issue.record("Expected a path")
            return
        }

        let match = engine.match(for: path)

        #expect(match?.word == "CAT")
        #expect(match?.isReversed == true)
        #expect(match?.coordinates == path)
    }

    @Test func foundCoordinatesUnionTracksPlacedWordCells() {
        let engine = PuzzleSelectionEngine(puzzle: makePuzzle())
        let foundCoordinates = engine.foundCoordinates(for: ["CAT"])

        #expect(foundCoordinates == [
            .init(row: 0, column: 0),
            .init(row: 0, column: 1),
            .init(row: 0, column: 2)
        ])
    }
}
