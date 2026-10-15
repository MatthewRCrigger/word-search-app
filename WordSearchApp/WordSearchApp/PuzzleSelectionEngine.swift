import Foundation

struct GridCoordinate: Hashable {
    let row: Int
    let column: Int
}

struct PuzzleSelectionMatch: Equatable {
    let word: String
    let coordinates: [GridCoordinate]
    let isReversed: Bool
}

struct PuzzleSelectionEngine {
    private static let directions: [GridCoordinate] = [
        .init(row: -1, column: -1),
        .init(row: -1, column: 0),
        .init(row: -1, column: 1),
        .init(row: 0, column: -1),
        .init(row: 0, column: 1),
        .init(row: 1, column: -1),
        .init(row: 1, column: 0),
        .init(row: 1, column: 1)
    ]

    let puzzle: WordSearchPuzzle
    private let placements: [String: [GridCoordinate]]

    init(puzzle: WordSearchPuzzle) {
        self.puzzle = puzzle
        self.placements = Self.buildPlacements(for: puzzle)
    }

    func path(from start: GridCoordinate, to end: GridCoordinate) -> [GridCoordinate]? {
        guard isValid(start), isValid(end) else { return nil }

        if start == end {
            return [start]
        }

        let rowDelta = end.row - start.row
        let columnDelta = end.column - start.column

        let stepRow: Int
        let stepColumn: Int

        if rowDelta == 0 {
            stepRow = 0
            stepColumn = columnDelta.signum()
        } else if columnDelta == 0 {
            stepRow = rowDelta.signum()
            stepColumn = 0
        } else if abs(rowDelta) == abs(columnDelta) {
            stepRow = rowDelta.signum()
            stepColumn = columnDelta.signum()
        } else {
            return nil
        }

        var coordinates: [GridCoordinate] = []
        var current = start

        while true {
            coordinates.append(current)
            if current == end { break }
            current = GridCoordinate(row: current.row + stepRow, column: current.column + stepColumn)
        }

        return coordinates
    }

    func selectionString(for path: [GridCoordinate]) -> String? {
        guard !path.isEmpty else { return nil }

        var letters = String()
        letters.reserveCapacity(path.count)

        for coordinate in path {
            guard let letter = letter(at: coordinate) else { return nil }
            letters.append(contentsOf: letter.uppercased())
        }

        return letters
    }

    func match(for path: [GridCoordinate]) -> PuzzleSelectionMatch? {
        guard let selection = selectionString(for: path) else { return nil }

        for word in puzzle.words {
            let normalizedWord = word.uppercased()

            if selection == normalizedWord {
                return PuzzleSelectionMatch(word: normalizedWord, coordinates: path, isReversed: false)
            }

            if selection == String(normalizedWord.reversed()) {
                return PuzzleSelectionMatch(word: normalizedWord, coordinates: path, isReversed: true)
            }
        }

        return nil
    }

    func coordinates(for word: String) -> [GridCoordinate]? {
        placements[word.uppercased()]
    }

    func foundCoordinates(for foundWords: Set<String>) -> Set<GridCoordinate> {
        foundWords.reduce(into: Set<GridCoordinate>()) { result, word in
            guard let coordinates = coordinates(for: word) else { return }
            result.formUnion(coordinates)
        }
    }

    private func isValid(_ coordinate: GridCoordinate) -> Bool {
        guard coordinate.row >= 0, coordinate.row < puzzle.grid.count else { return false }
        guard coordinate.column >= 0, coordinate.column < puzzle.grid[coordinate.row].count else { return false }
        return true
    }

    private func letter(at coordinate: GridCoordinate) -> String? {
        guard isValid(coordinate) else { return nil }
        return puzzle.grid[coordinate.row][coordinate.column].uppercased()
    }

    private static func buildPlacements(for puzzle: WordSearchPuzzle) -> [String: [GridCoordinate]] {
        var placements: [String: [GridCoordinate]] = [:]

        for word in puzzle.words {
            placements[word.uppercased()] = locate(word: word.uppercased(), in: puzzle.grid)
        }

        return placements
    }

    private static func locate(word: String, in grid: [[String]]) -> [GridCoordinate]? {
        guard !grid.isEmpty else { return nil }
        let rowCount = grid.count
        let columnCount = grid[0].count
        let letters = Array(word)

        for row in 0..<rowCount {
            for column in 0..<columnCount {
                let start = GridCoordinate(row: row, column: column)

                for direction in directions {
                    let end = GridCoordinate(
                        row: row + direction.row * (letters.count - 1),
                        column: column + direction.column * (letters.count - 1)
                    )

                    guard let path = path(from: start, to: end, rowCount: rowCount, columnCount: columnCount) else {
                        continue
                    }

                    if selectionString(for: path, in: grid) == word {
                        return path
                    }
                }
            }
        }

        return nil
    }

    private static func path(
        from start: GridCoordinate,
        to end: GridCoordinate,
        rowCount: Int,
        columnCount: Int
    ) -> [GridCoordinate]? {
        guard start.row >= 0, start.row < rowCount, start.column >= 0, start.column < columnCount else { return nil }
        guard end.row >= 0, end.row < rowCount, end.column >= 0, end.column < columnCount else { return nil }

        if start == end {
            return [start]
        }

        let rowDelta = end.row - start.row
        let columnDelta = end.column - start.column

        let stepRow: Int
        let stepColumn: Int

        if rowDelta == 0 {
            stepRow = 0
            stepColumn = columnDelta.signum()
        } else if columnDelta == 0 {
            stepRow = rowDelta.signum()
            stepColumn = 0
        } else if abs(rowDelta) == abs(columnDelta) {
            stepRow = rowDelta.signum()
            stepColumn = columnDelta.signum()
        } else {
            return nil
        }

        var coordinates: [GridCoordinate] = []
        var current = start

        while true {
            coordinates.append(current)
            if current == end { break }
            current = GridCoordinate(row: current.row + stepRow, column: current.column + stepColumn)
        }

        return coordinates
    }

    private static func selectionString(for path: [GridCoordinate], in grid: [[String]]) -> String? {
        guard !path.isEmpty else { return nil }

        var letters = String()
        letters.reserveCapacity(path.count)

        for coordinate in path {
            guard coordinate.row >= 0, coordinate.row < grid.count else { return nil }
            guard coordinate.column >= 0, coordinate.column < grid[coordinate.row].count else { return nil }
            letters.append(contentsOf: grid[coordinate.row][coordinate.column].uppercased())
        }

        return letters
    }
}
