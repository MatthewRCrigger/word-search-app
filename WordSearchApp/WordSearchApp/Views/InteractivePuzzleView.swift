import SwiftUI

struct InteractivePuzzleView: View {
    let puzzle: WordSearchPuzzle
    private let selectionEngine: PuzzleSelectionEngine
    @Binding var foundWords: Set<String>
    let revealedWords: Set<String>
    let hintCoordinate: GridCoordinate?
    var onWordFound: ((PuzzleSelectionMatch) -> Void)?

    @State private var dragOrigin: GridCoordinate?
    @State private var currentDragPath: [GridCoordinate] = []

    init(
        puzzle: WordSearchPuzzle,
        foundWords: Binding<Set<String>>,
        revealedWords: Set<String> = [],
        hintCoordinate: GridCoordinate? = nil,
        onWordFound: ((PuzzleSelectionMatch) -> Void)? = nil
    ) {
        self.puzzle = puzzle
        self.selectionEngine = PuzzleSelectionEngine(puzzle: puzzle)
        self._foundWords = foundWords
        self.revealedWords = revealedWords
        self.hintCoordinate = hintCoordinate
        self.onWordFound = onWordFound
    }

    var body: some View {
        GeometryReader { proxy in
            let boardSide = max(0, min(proxy.size.width, proxy.size.height) - 12)

            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    puzzleBoard(side: boardSide)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder
    private func puzzleBoard(side: CGFloat) -> some View {
        let gridSize = puzzle.grid.count
        let spacing = max(2, min(5, side / max(CGFloat(gridSize) * 9, 1)))
        let cellSize = gridSize > 0 ? max(0, (side - CGFloat(gridSize - 1) * spacing) / CGFloat(gridSize)) : 0
        let boardSize = CGFloat(gridSize) * cellSize + CGFloat(max(gridSize - 1, 0)) * spacing
        let foundCoordinates = selectionEngine.foundCoordinates(for: foundWords)
        let orderedWords = puzzle.words.map { $0.uppercased() }
        let foundPaths: [(path: [GridCoordinate], color: Color)] = foundWords
            .sorted()
            .compactMap { word in
                guard let path = selectionEngine.coordinates(for: word) else { return nil }
                let index = orderedWords.firstIndex(of: word) ?? 0
                return (path, Theme.wordColor(at: index))
            }
        let revealedPaths = revealedWords
            .sorted()
            .compactMap { selectionEngine.coordinates(for: $0) }
        let foundHighlightWidth = max(16, cellSize * 0.82)
        let dragHighlightWidth = max(14, cellSize * 0.78)
        let revealedCoordinates = selectionEngine.foundCoordinates(for: revealedWords)

        ZStack {
            Color.clear

            ForEach(Array(foundPaths.enumerated()), id: \.offset) { _, entry in
                highlightPath(
                    entry.path,
                    color: entry.color,
                    lineWidth: foundHighlightWidth,
                    spacing: spacing,
                    cellSize: cellSize
                )
            }

            ForEach(Array(revealedPaths.enumerated()), id: \.offset) { _, path in
                highlightPath(
                    path,
                    color: Color(hex: 0xFFC9D6),
                    lineWidth: foundHighlightWidth,
                    spacing: spacing,
                    cellSize: cellSize
                )
            }

            if !currentDragPath.isEmpty {
                highlightPath(
                    currentDragPath,
                    color: Theme.accent.opacity(0.35),
                    lineWidth: dragHighlightWidth,
                    spacing: spacing,
                    cellSize: cellSize
                )
            }

            if let hintCoordinate {
                highlightPath(
                    [hintCoordinate],
                    color: Theme.accent.opacity(0.4),
                    lineWidth: dragHighlightWidth,
                    spacing: spacing,
                    cellSize: cellSize
                )
            }

            ForEach(puzzle.grid.indices, id: \.self) { row in
                ForEach(puzzle.grid[row].indices, id: \.self) { column in
                    let coordinate = GridCoordinate(row: row, column: column)
                    let isFound = foundCoordinates.contains(coordinate)
                    let isDragging = currentDragPath.contains(coordinate)
                    let isRevealed = revealedCoordinates.contains(coordinate)
                    let isHinted = (hintCoordinate == coordinate)

                    cellView(
                        letter: puzzle.grid[row][column],
                        isFound: isFound,
                        isDragging: isDragging,
                        isRevealed: isRevealed,
                        isHinted: isHinted,
                        size: cellSize
                    )
                    .position(
                        x: CGFloat(column) * (cellSize + spacing) + (cellSize / 2),
                        y: CGFloat(row) * (cellSize + spacing) + (cellSize / 2)
                    )
                }
            }
        }
        .frame(width: boardSize, height: boardSize)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value.location, side: boardSize, spacing: spacing, cellSize: cellSize)
                }
                .onEnded { _ in
                    commitSelection()
                }
        )
    }

    @ViewBuilder
    private func cellView(
        letter: String,
        isFound: Bool,
        isDragging: Bool,
        isRevealed: Bool,
        isHinted: Bool,
        size: CGFloat
    ) -> some View {
        Text(letter)
            .font(.system(size: max(12, size * 0.5), weight: .bold, design: .rounded))
            .foregroundStyle(
                letterColor(
                    isFound: isFound,
                    isDragging: isDragging,
                    isRevealed: isRevealed,
                    isHinted: isHinted
                )
            )
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private func highlightPath(
        _ path: [GridCoordinate],
        color: Color,
        lineWidth: CGFloat,
        spacing: CGFloat,
        cellSize: CGFloat
    ) -> some View {
        if path.count == 1, let coordinate = path.first {
            Circle()
                .fill(color)
                .frame(width: lineWidth, height: lineWidth)
                .position(centerPoint(for: coordinate, spacing: spacing, cellSize: cellSize))
        } else {
            Path { pathShape in
                guard let first = path.first else { return }
                pathShape.move(to: centerPoint(for: first, spacing: spacing, cellSize: cellSize))

                for coordinate in path.dropFirst() {
                    pathShape.addLine(to: centerPoint(for: coordinate, spacing: spacing, cellSize: cellSize))
                }
            }
            .stroke(
                color,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func centerPoint(for coordinate: GridCoordinate, spacing: CGFloat, cellSize: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(coordinate.column) * (cellSize + spacing) + (cellSize / 2),
            y: CGFloat(coordinate.row) * (cellSize + spacing) + (cellSize / 2)
        )
    }

    private func letterColor(isFound: Bool, isDragging: Bool, isRevealed: Bool, isHinted: Bool) -> Color {
        if isFound {
            return Theme.ink
        }

        if isRevealed {
            return Theme.danger
        }

        if isHinted || isDragging {
            return Theme.accentText
        }

        return Color(hex: 0x33425B)
    }

    private func handleDragChanged(_ location: CGPoint, side: CGFloat, spacing: CGFloat, cellSize: CGFloat) {
        guard let coordinate = coordinate(at: location, side: side, spacing: spacing, cellSize: cellSize) else {
            return
        }

        if dragOrigin == nil {
            dragOrigin = coordinate
            currentDragPath = [coordinate]
            return
        }

        guard let origin = dragOrigin,
              let path = selectionEngine.path(from: origin, to: coordinate) else {
            return
        }

        currentDragPath = path
    }

    private func commitSelection() {
        guard let match = selectionEngine.match(for: currentDragPath) else {
            resetDragState()
            return
        }

        if !foundWords.contains(match.word) {
            var updatedFoundWords = foundWords
            updatedFoundWords.insert(match.word)
            foundWords = updatedFoundWords
            onWordFound?(match)
        }

        resetDragState()
    }

    private func resetDragState() {
        dragOrigin = nil
        currentDragPath = []
    }

    private func coordinate(at location: CGPoint, side: CGFloat, spacing: CGFloat, cellSize: CGFloat) -> GridCoordinate? {
        guard location.x >= 0, location.y >= 0, location.x <= side, location.y <= side else { return nil }
        let step = cellSize + spacing

        guard step > 0 else { return nil }

        let column = Int(location.x / step)
        let row = Int(location.y / step)

        guard row >= 0, row < puzzle.grid.count else { return nil }
        guard column >= 0, column < puzzle.grid[row].count else { return nil }

        return GridCoordinate(row: row, column: column)
    }
}
