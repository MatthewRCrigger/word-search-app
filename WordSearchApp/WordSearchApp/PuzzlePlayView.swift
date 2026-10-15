import SwiftUI

struct PuzzlePlayView: View {
    let puzzle: WordSearchPuzzle
    let title: String
    @Binding var foundWords: Set<String>
    let onPlayAgain: () -> WordSearchPuzzle?
    let onPrintPuzzle: (WordSearchPuzzle) -> Void
    let onClose: () -> Void

    @State private var isShowingCompletion = false
    @State private var displayedPuzzle: WordSearchPuzzle
    @State private var revealedMissedWords: Set<String> = []
    @State private var hintCoordinate: GridCoordinate?
    @State private var hintClearTask: Task<Void, Never>?
    @State private var hintRequestID = UUID()

    private var displayWords: [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        for word in displayedPuzzle.words.map({ $0.uppercased() }) {
            if seen.insert(word).inserted {
                ordered.append(word)
            }
        }

        return ordered
    }

    init(
        puzzle: WordSearchPuzzle,
        title: String,
        foundWords: Binding<Set<String>>,
        onPlayAgain: @escaping () -> WordSearchPuzzle?,
        onPrintPuzzle: @escaping (WordSearchPuzzle) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.puzzle = puzzle
        self.title = title
        self._foundWords = foundWords
        self.onPlayAgain = onPlayAgain
        self.onPrintPuzzle = onPrintPuzzle
        self.onClose = onClose
        self._displayedPuzzle = State(initialValue: puzzle)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            GeometryReader { proxy in
                let useSideBySide = proxy.size.width > 760 && proxy.size.width > proxy.size.height * 1.05

                Group {
                    if useSideBySide {
                        HStack(alignment: .top, spacing: 28) {
                            boardCard
                            sidePanel(compact: false)
                                .frame(width: min(360, proxy.size.width * 0.32))
                        }
                    } else {
                        VStack(spacing: 16) {
                            boardCard
                            sidePanel(compact: true)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.ground.ignoresSafeArea())
        .overlay {
            if isShowingCompletion {
                completionOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isShowingCompletion)
        .onChange(of: foundWords) { _, newValue in
            guard displayWords.count > 0 else { return }
            if newValue.count == displayWords.count {
                isShowingCompletion = true
            }
        }
        .onDisappear {
            hintClearTask?.cancel()
        }
    }

    // MARK: Layout pieces

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Label("Done", systemImage: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Capsule().fill(Theme.surface))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(title)
                    .font(Theme.display(24))
                    .lineLimit(1)
                Text("\(displayedPuzzle.size) × \(displayedPuzzle.size) · \(displayWords.count) words")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSecondary)
            }

            Spacer()

            Color.clear.frame(width: 96, height: 48)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private var boardCard: some View {
        InteractivePuzzleView(
            puzzle: displayedPuzzle,
            foundWords: $foundWords,
            revealedWords: revealedMissedWords,
            hintCoordinate: hintCoordinate
        )
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card(cornerRadius: 28)
    }

    private func sidePanel(compact: Bool) -> some View {
        VStack(spacing: 16) {
            progressCard

            if compact {
                wordsCard
                    .frame(height: 150)
            } else {
                wordsCard
            }

            actionRow
        }
    }

    private var progressCard: some View {
        let total = max(displayWords.count, 1)
        let found = foundWords.count

        return VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(found)")
                    .font(Theme.display(40, weight: .heavy))
                + Text(" / \(displayWords.count)")
                    .font(Theme.display(22))
                    .foregroundColor(Theme.inkTertiary)
                Spacer()
                Text("words found")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: 0xE4EAF3))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: proxy.size.width * CGFloat(found) / CGFloat(total))
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .card(cornerRadius: 24)
        .animation(.snappy, value: found)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(found) of \(displayWords.count) words found")
    }

    private var wordsCard: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(displayWords.enumerated()), id: \.element) { index, word in
                    wordRow(word, index: index)
                }
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card(cornerRadius: 24)
    }

    private func wordRow(_ word: String, index: Int) -> some View {
        let isFound = foundWords.contains(word)
        let isMissed = revealedMissedWords.contains(word)

        return HStack(spacing: 12) {
            Circle()
                .fill(isFound ? Theme.wordColor(at: index) : (isMissed ? Color(hex: 0xFFC9D6) : .clear))
                .overlay(
                    Circle().strokeBorder(
                        isFound ? Theme.ink.opacity(0.18) : (isMissed ? Theme.danger.opacity(0.4) : Color(hex: 0xCBD5E4)),
                        lineWidth: 2
                    )
                )
                .frame(width: 14, height: 14)

            Text(word)
                .font(.system(size: 17, weight: isFound ? .semibold : .bold))
                .tracking(0.7)
                .strikethrough(isFound, color: Theme.inkTertiary)
                .foregroundStyle(isFound ? Theme.inkTertiary : (isMissed ? Theme.danger : Theme.ink))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isFound ? "\(word), found" : (isMissed ? "\(word), missed" : word))
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if revealedMissedWords.isEmpty {
                Button(action: showHint) {
                    Label("Hint", systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.accentText, filled: true))
                .disabled(!canHint)

                Button(action: giveUp) {
                    Label("Give up", systemImage: "flag")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(tint: Theme.danger, filled: true))
                .disabled(foundWords.count == displayWords.count)
            } else {
                Button(action: startNextPuzzle) {
                    Label("Play again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var completionOverlay: some View {
        ZStack {
            Color(hex: 0x0F1B2D).opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(hex: 0xF2B705))
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(Color(hex: 0xFFF0A8)))
                    .padding(.bottom, 8)

                Text("You did it!")
                    .font(Theme.display(36, weight: .heavy))

                Text("You found all \(displayWords.count) words in \(title).")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 20)

                Button("Play again") {
                    startNextPuzzle()
                    isShowingCompletion = false
                }
                .buttonStyle(PrimaryButtonStyle())

                HStack(spacing: 10) {
                    Button("Print puzzle") {
                        onPrintPuzzle(displayedPuzzle)
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Return home") {
                        isShowingCompletion = false
                        onClose()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 36)
            .padding(.top, 40)
            .padding(.bottom, 32)
            .frame(maxWidth: 480)
            .card(cornerRadius: 32)
            .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
            .padding(24)
            .accessibilityAddTraits(.isModal)
        }
    }

    // MARK: Game logic

    private var unresolvedWords: [String] {
        displayWords.filter { !foundWords.contains($0) }
    }

    private var canHint: Bool {
        guard revealedMissedWords.isEmpty else { return false }
        guard !unresolvedWords.isEmpty else { return false }

        let engine = PuzzleSelectionEngine(puzzle: displayedPuzzle)
        return unresolvedWords.contains { word in
            guard let start = engine.coordinates(for: word)?.first else { return false }
            return !adjacentCoordinates(to: start).isEmpty
        }
    }

    private func giveUp() {
        revealedMissedWords = Set(unresolvedWords)
        hintCoordinate = nil
        hintClearTask?.cancel()
    }

    private func showHint() {
        guard canHint else { return }

        let engine = PuzzleSelectionEngine(puzzle: displayedPuzzle)
        for word in unresolvedWords.shuffled() {
            guard let start = engine.coordinates(for: word)?.first else { continue }
            let options = adjacentCoordinates(to: start)
            guard let chosen = options.randomElement() else { continue }
            revealHint(at: chosen)
            return
        }
    }

    private func revealHint(at coordinate: GridCoordinate) {
        hintCoordinate = coordinate
        hintClearTask?.cancel()
        let requestID = UUID()
        hintRequestID = requestID

        hintClearTask = Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard hintRequestID == requestID else { return }
                hintCoordinate = nil
            }
        }
    }

    private func startNextPuzzle() {
        if let nextPuzzle = onPlayAgain() {
            displayedPuzzle = nextPuzzle
            foundWords = []
            revealedMissedWords = []
            hintCoordinate = nil
            hintClearTask?.cancel()
            hintRequestID = UUID()
            isShowingCompletion = false
        }
    }

    private func adjacentCoordinates(to start: GridCoordinate) -> [GridCoordinate] {
        var output: [GridCoordinate] = []

        for rowOffset in -1...1 {
            for columnOffset in -1...1 {
                if rowOffset == 0, columnOffset == 0 { continue }

                let row = start.row + rowOffset
                let column = start.column + columnOffset

                guard row >= 0, row < displayedPuzzle.grid.count else { continue }
                guard column >= 0, column < displayedPuzzle.grid[row].count else { continue }

                output.append(GridCoordinate(row: row, column: column))
            }
        }

        return output
    }
}
