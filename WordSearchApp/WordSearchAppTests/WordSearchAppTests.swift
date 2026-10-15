import Testing
@testable import WordSearchApp

struct WordSearchAppTests {

    @Test func sanitizeWordRemovesNonLettersAndUppercases() {
        #expect(WordSearchGenerator.sanitizeWord(" Cat-42! ") == "CAT")
    }

    @Test func parseWordsSplitsOnCommaAndNewline() {
        let parsed = WordSearchGenerator.parseWords("cat, dog\nbird")
        #expect(parsed == ["CAT", "DOG", "BIRD"])
    }

    @Test func generateReturnsCompleteGridWithOnlyLetters() {
        let words = ["CAT", "DOG", "BIRD", "FISH", "TIGER"]
        let result = WordSearchGenerator.generate(words: words, size: 16)

        #expect(result != nil)

        guard let puzzle = result?.puzzle else {
            Issue.record("Expected a puzzle")
            return
        }

        #expect(puzzle.grid.count == 16)
        #expect(puzzle.grid.allSatisfy { $0.count == 16 })

        let allLetters = puzzle.grid.flatMap { $0 }
        #expect(allLetters.allSatisfy { $0.count == 1 && $0.first?.isLetter == true })
    }
}
