import Foundation

struct WordSearchPuzzle {
    let size: Int
    let grid: [[String]]
    let words: [String]
}

struct WordSearchGenerationResult {
    let puzzle: WordSearchPuzzle
    let unplacedWords: [String]
}

struct WordSearchGenerationOptions {
    let allowBackwards: Bool
    let allowOverlap: Bool

    static let `default` = WordSearchGenerationOptions(
        allowBackwards: true,
        allowOverlap: true
    )
}

enum WordSearchGenerator {
    private static let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private static let allDirections: [(row: Int, col: Int)] = [
        (1, 0),
        (0, 1),
        (1, 1),
        (-1, 0),
        (0, -1),
        (-1, -1),
        (1, -1),
        (-1, 1)
    ]

    static let allowedGridSizes = [12, 16, 20, 24]

    static func sanitizeWord(_ raw: String) -> String {
        let uppercased = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return String(uppercased.unicodeScalars.filter { scalar in
            scalar.value >= 65 && scalar.value <= 90
        }.map(Character.init))
    }

    static func parseWords(_ raw: String) -> [String] {
        raw
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map(sanitizeWord)
            .filter { !$0.isEmpty }
    }

    static func generate(words: [String], size: Int) -> WordSearchGenerationResult? {
        guard allowedGridSizes.contains(size) else { return nil }

        let sanitizedWords = words.map(sanitizeWord).filter { !$0.isEmpty }
        guard !sanitizedWords.isEmpty else { return nil }

        let uniqueWords = Array(Set(sanitizedWords))
        let sortedWords = uniqueWords.sorted { $0.count > $1.count }

        var bestCandidate: (grid: [[String]], unplaced: [String])?

        for _ in 0..<120 {
            let candidate = tryPlaceWords(
                words: sortedWords,
                size: size,
                options: .default
            )

            if bestCandidate == nil || candidate.unplaced.count < bestCandidate!.unplaced.count {
                bestCandidate = candidate
            }

            if candidate.unplaced.isEmpty {
                let filledGrid = fillRemainingCells(candidate.grid)
                return WordSearchGenerationResult(
                    puzzle: WordSearchPuzzle(size: size, grid: filledGrid, words: sortedWords),
                    unplacedWords: []
                )
            }
        }

        guard let bestCandidate else { return nil }

        let filledGrid = fillRemainingCells(bestCandidate.grid)
        return WordSearchGenerationResult(
            puzzle: WordSearchPuzzle(size: size, grid: filledGrid, words: sortedWords),
            unplacedWords: bestCandidate.unplaced
        )
    }

    static func generate(
        words: [String],
        size: Int,
        options: WordSearchGenerationOptions
    ) -> WordSearchGenerationResult? {
        guard allowedGridSizes.contains(size) else { return nil }

        let sanitizedWords = words.map(sanitizeWord).filter { !$0.isEmpty }
        guard !sanitizedWords.isEmpty else { return nil }

        let uniqueWords = Array(Set(sanitizedWords))
        let sortedWords = uniqueWords.sorted { $0.count > $1.count }

        var bestCandidate: (grid: [[String]], unplaced: [String])?

        for _ in 0..<120 {
            let candidate = tryPlaceWords(
                words: sortedWords,
                size: size,
                options: options
            )

            if bestCandidate == nil || candidate.unplaced.count < bestCandidate!.unplaced.count {
                bestCandidate = candidate
            }

            if candidate.unplaced.isEmpty {
                let filledGrid = fillRemainingCells(candidate.grid)
                return WordSearchGenerationResult(
                    puzzle: WordSearchPuzzle(size: size, grid: filledGrid, words: sortedWords),
                    unplacedWords: []
                )
            }
        }

        guard let bestCandidate else { return nil }

        let filledGrid = fillRemainingCells(bestCandidate.grid)
        return WordSearchGenerationResult(
            puzzle: WordSearchPuzzle(size: size, grid: filledGrid, words: sortedWords),
            unplacedWords: bestCandidate.unplaced
        )
    }

    private static func createEmptyGrid(size: Int) -> [[String]] {
        Array(repeating: Array(repeating: "", count: size), count: size)
    }

    private static func tryPlaceWords(
        words: [String],
        size: Int,
        options: WordSearchGenerationOptions
    ) -> (grid: [[String]], unplaced: [String]) {
        var grid = createEmptyGrid(size: size)
        var unplaced: [String] = []
        let directions = allowedDirections(for: options)

        for word in words {
            var didPlace = false

            for _ in 0..<400 {
                guard let direction = directions.randomElement() else { continue }

                let row = Int.random(in: 0..<size)
                let col = Int.random(in: 0..<size)

                if !fitsWord(
                    grid: grid,
                    word: word,
                    row: row,
                    col: col,
                    rowDelta: direction.row,
                    colDelta: direction.col,
                    allowOverlap: options.allowOverlap
                ) {
                    continue
                }

                writeWord(&grid, word: word, row: row, col: col, rowDelta: direction.row, colDelta: direction.col)
                didPlace = true
                break
            }

            if !didPlace {
                unplaced.append(word)
            }
        }

        return (grid, unplaced)
    }

    private static func fitsWord(
        grid: [[String]],
        word: String,
        row: Int,
        col: Int,
        rowDelta: Int,
        colDelta: Int,
        allowOverlap: Bool
    ) -> Bool {
        let size = grid.count
        let letters = Array(word)

        for index in 0..<letters.count {
            let currentRow = row + rowDelta * index
            let currentCol = col + colDelta * index

            if currentRow < 0 || currentCol < 0 || currentRow >= size || currentCol >= size {
                return false
            }

            let currentValue = grid[currentRow][currentCol]
            if currentValue.isEmpty {
                continue
            }

            if !allowOverlap {
                return false
            }

            if currentValue != String(letters[index]) {
                return false
            }
        }

        return true
    }

    private static func writeWord(_ grid: inout [[String]], word: String, row: Int, col: Int, rowDelta: Int, colDelta: Int) {
        let letters = Array(word)
        for index in 0..<letters.count {
            let currentRow = row + rowDelta * index
            let currentCol = col + colDelta * index
            grid[currentRow][currentCol] = String(letters[index])
        }
    }

    private static func fillRemainingCells(_ grid: [[String]]) -> [[String]] {
        var output = grid

        for row in 0..<output.count {
            for col in 0..<output[row].count {
                if output[row][col].isEmpty {
                    output[row][col] = String(letters.randomElement() ?? "A")
                }
            }
        }

        return output
    }

    private static func allowedDirections(for options: WordSearchGenerationOptions) -> [(row: Int, col: Int)] {
        if options.allowBackwards {
            return allDirections
        }

        // "Forward" directions only for easier puzzles.
        return [
            (0, 1),
            (1, 0),
            (1, 1),
            (1, -1)
        ]
    }
}
