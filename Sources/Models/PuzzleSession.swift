import Foundation

/// Everything needed to show a puzzle and generate the next one from the same settings.
/// Codable so a Mac puzzle window can be opened by value.
struct PuzzleSession: Codable, Hashable, Identifiable {
    var id = UUID()
    let puzzle: WordSearchPuzzle
    let wordPool: [String]
    let wordCount: Int
    let gridSize: Int
    let options: WordSearchGenerationOptions
    let title: String

    /// A fresh puzzle drawn from the same word pool and options.
    func nextPuzzle() -> WordSearchPuzzle? {
        PuzzleFactory.generate(from: wordPool, wordCount: wordCount, size: gridSize, options: options)
    }
}

enum PuzzleFactory {
    static let minimumWordsPerPuzzle = 5

    static func generate(
        from wordPool: [String],
        wordCount: Int,
        size: Int,
        options: WordSearchGenerationOptions
    ) -> WordSearchPuzzle? {
        guard wordPool.count >= wordCount else { return nil }

        for _ in 0..<80 {
            let selectedWords = Array(wordPool.shuffled().prefix(wordCount))

            guard let result = WordSearchGenerator.generate(
                words: selectedWords,
                size: size,
                options: options
            ) else {
                continue
            }

            if result.unplacedWords.isEmpty {
                return result.puzzle
            }
        }

        return nil
    }
}
