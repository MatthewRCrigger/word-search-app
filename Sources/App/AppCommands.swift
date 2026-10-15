#if os(macOS)
import SwiftUI

// MARK: - Focused actions

/// What the library window can do, published so menu commands can reach it.
struct LibraryActions {
    let canPlay: Bool
    let newPuzzle: () -> Void
    let exportPDF: () -> Void
    let newWordBank: () -> Void
    let showPlay: () -> Void
    let showWordBanks: () -> Void
}

/// What a puzzle window can do, published so menu commands can reach it.
struct PuzzleActions {
    let canHint: Bool
    let canGiveUp: Bool
    let hint: () -> Void
    let giveUp: () -> Void
    let playAgain: () -> Void
    let exportPDF: () -> Void
    let printPuzzle: () -> Void
}

private struct LibraryActionsKey: FocusedValueKey { typealias Value = LibraryActions }
private struct PuzzleActionsKey: FocusedValueKey { typealias Value = PuzzleActions }

extension FocusedValues {
    var libraryActions: LibraryActions? {
        get { self[LibraryActionsKey.self] }
        set { self[LibraryActionsKey.self] = newValue }
    }

    var puzzleActions: PuzzleActions? {
        get { self[PuzzleActionsKey.self] }
        set { self[PuzzleActionsKey.self] = newValue }
    }
}

// MARK: - Puzzle window

enum PuzzleWindow {
    static let id = "puzzle"
}

struct PuzzleWindowView: View {
    let session: PuzzleSession

    @Environment(\.dismiss) private var dismiss
    @State private var foundWords: Set<String> = []

    var body: some View {
        PuzzlePlayView(
            puzzle: session.puzzle,
            title: session.title,
            foundWords: $foundWords,
            onPlayAgain: { session.nextPuzzle() },
            onPrintPuzzle: { _ = MacPDF.printPuzzle($0, title: session.title) },
            onClose: { dismiss() }
        )
        .frame(minWidth: 860, minHeight: 640)
        .tint(Theme.accent)
    }
}

// MARK: - Menu commands

struct AppCommands: Commands {
    @FocusedValue(\.libraryActions) private var library
    @FocusedValue(\.puzzleActions) private var puzzle

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Word Bank") { library?.newWordBank() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(library == nil)
        }

        CommandGroup(replacing: .printItem) {
            Button("Export PDF…") { exportPDF() }
                .keyboardShortcut("e")
                .disabled(library?.canPlay != true && puzzle == nil)

            Button("Print…") { puzzle?.printPuzzle() }
                .keyboardShortcut("p")
                .disabled(puzzle == nil)
        }

        CommandGroup(after: .sidebar) {
            Button("Show Play") { library?.showPlay() }
                .keyboardShortcut("1")
                .disabled(library == nil)
            Button("Show Word Banks") { library?.showWordBanks() }
                .keyboardShortcut("2")
                .disabled(library == nil)
        }

        CommandMenu("Game") {
            Button("New Puzzle") {
                if let library { library.newPuzzle() } else { puzzle?.playAgain() }
            }
            .keyboardShortcut("n")
            .disabled(library?.canPlay != true && puzzle == nil)

            Button("Play Again") { puzzle?.playAgain() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(puzzle == nil)

            Divider()

            Button("Hint") { puzzle?.hint() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(puzzle?.canHint != true)

            Button("Give Up") { puzzle?.giveUp() }
                .keyboardShortcut("g", modifiers: [.command, .option])
                .disabled(puzzle?.canGiveUp != true)
        }
    }

    private func exportPDF() {
        if let puzzle { puzzle.exportPDF() } else { library?.exportPDF() }
    }
}
#endif
