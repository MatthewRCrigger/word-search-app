import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\WordSubject.name)]) private var subjects: [WordSubject]

    @State private var selectedTab = 0
    @State private var selectedSubjectID: PersistentIdentifier?

    @State private var selectedGridSize = 16
    @State private var selectedWordCount = 8
    @State private var allowBackwards = true
    @State private var allowOverlap = true

    @State private var activePuzzleSession: PuzzleSession?
    @State private var foundWords: Set<String> = []
    @State private var setupErrorMessage = ""
    @State private var isShowingCreateWordBank = false
    @State private var exportedDocument: ExportedDocument?
    @State private var exportedDocumentCleanupURL: URL?
    private let minimumWordsPerPuzzle = PuzzleFactory.minimumWordsPerPuzzle

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    private var canPlay: Bool {
        selectedSubject != nil && eligibleWordsForSelectedSubject.count >= minimumWordsPerPuzzle
    }

    var body: some View {
        shell
            .tint(Theme.accent)
            .puzzleCover(item: $activePuzzleSession) { session in
                PuzzlePlayView(
                    puzzle: session.puzzle,
                    title: session.title,
                    foundWords: $foundWords,
                    onPlayAgain: { session.nextPuzzle() },
                    onPrintPuzzle: { exportPuzzleToPDF(puzzle: $0, title: session.title) },
                    onClose: { activePuzzleSession = nil }
                )
            }
            .onAppear(perform: ensureSelectedSubject)
            .onChange(of: subjects) { _, _ in
                ensureSelectedSubject()
            }
            .onChange(of: selectedGridSize) { _, _ in
                syncWordCountWithEligibility()
            }
            .onChange(of: selectedSubjectID) { _, _ in
                syncWordCountWithEligibility()
            }
            .sheet(isPresented: $isShowingCreateWordBank) {
                CreateWordBankView(existingNames: Set(subjects.map(\.name))) { name, words in
                    let subject = WordSubject(name: name)
                    modelContext.insert(subject)

                    for text in words {
                        let word = SubjectWord(text: text)
                        word.subject = subject
                        modelContext.insert(word)
                        subject.words.append(word)
                    }

                    selectedSubjectID = subject.persistentModelID
                }
            }
            #if os(iOS)
            .sheet(item: $exportedDocument, onDismiss: cleanupExportedDocument) { document in
                ShareSheet(items: [document.url])
            }
            #endif
            #if os(macOS)
            .focusedSceneValue(\.libraryActions, LibraryActions(
                canPlay: canPlay,
                newPuzzle: generatePuzzle,
                exportPDF: exportCurrentPuzzleToPDF,
                newWordBank: { isShowingCreateWordBank = true },
                showPlay: { selectedTab = 0 },
                showWordBanks: { selectedTab = 1 }
            ))
            #endif
    }

    @ViewBuilder
    private var shell: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: Binding<Int?>(get: { selectedTab }, set: { selectedTab = $0 ?? selectedTab })) {
                Section("Library") {
                    Label("Play", systemImage: "play.fill").tag(0)
                    Label("Word Banks", systemImage: "book.closed.fill").tag(1)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            Group {
                if selectedTab == 0 { playScreen } else { wordBanksScreen }
            }
            .navigationTitle(selectedTab == 0 ? "New Puzzle" : "Word Banks")
            .toolbar {
                if selectedTab == 0 {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Export PDF", systemImage: "square.and.arrow.up", action: exportCurrentPuzzleToPDF)
                            .help("Export this puzzle as a PDF")
                            .disabled(!canPlay)
                        Button("Play", systemImage: "play.fill", action: generatePuzzle)
                            .help("Start a new puzzle")
                            .buttonStyle(.borderedProminent)
                            .disabled(!canPlay)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Word Bank", systemImage: "plus") { isShowingCreateWordBank = true }
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        #else
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                AppSidebar(selectedTab: $selectedTab)
                Group {
                    if selectedTab == 0 { playScreen } else { wordBanksScreen }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Theme.ground.ignoresSafeArea())
        } else {
            TabView(selection: $selectedTab) {
                playScreen
                    .tabItem { Label("Play", systemImage: "play.fill") }
                    .tag(0)

                wordBanksScreen
                    .tabItem { Label("Word Banks", systemImage: "book.closed.fill") }
                    .tag(1)
            }
        }
        #endif
    }

    @ViewBuilder
    private var playScreen: some View {
        #if os(macOS)
        MacPlaySetupView(
            subjects: subjects,
            selectedSubjectID: $selectedSubjectID,
            selectedGridSize: $selectedGridSize,
            selectedWordCount: $selectedWordCount,
            allowBackwards: $allowBackwards,
            allowOverlap: $allowOverlap,
            selectedSubjectName: selectedSubject?.name,
            minimumWordCount: minimumWordsPerPuzzle,
            maximumWordCount: eligibleWordsForSelectedSubject.count,
            statusMessage: setupErrorMessage,
            onCreateWordBank: { isShowingCreateWordBank = true },
            onManageWordBanks: { selectedTab = 1 }
        )
        #else
        PlaySetupView(
            subjects: subjects,
            selectedSubjectID: $selectedSubjectID,
            selectedGridSize: $selectedGridSize,
            selectedWordCount: $selectedWordCount,
            allowBackwards: $allowBackwards,
            allowOverlap: $allowOverlap,
            selectedSubjectName: selectedSubject?.name,
            minimumWordCount: minimumWordsPerPuzzle,
            maximumWordCount: eligibleWordsForSelectedSubject.count,
            statusMessage: setupErrorMessage,
            onCreateWordBank: { isShowingCreateWordBank = true },
            onManageWordBanks: { selectedTab = 1 },
            onGeneratePDF: exportCurrentPuzzleToPDF,
            onPlay: generatePuzzle
        )
        #endif
    }

    private var wordBanksScreen: some View {
        WordBanksView(
            subjects: subjects,
            onCreateWordBank: { isShowingCreateWordBank = true },
            onPlayBank: { subject in
                selectedSubjectID = subject.persistentModelID
                selectedTab = 0
            }
        )
    }

    private var selectedSubject: WordSubject? {
        guard let selectedSubjectID else { return nil }
        return subjects.first(where: { $0.persistentModelID == selectedSubjectID })
    }

    private var eligibleWordsForSelectedSubject: [String] {
        guard let selectedSubject else { return [] }
        return eligibleWords(in: selectedSubject, for: selectedGridSize)
    }

    private func ensureSelectedSubject() {
        guard !subjects.isEmpty else {
            selectedSubjectID = nil
            return
        }

        guard let selectedSubjectID else {
            self.selectedSubjectID = subjects.first?.persistentModelID
            return
        }

        if !subjects.contains(where: { $0.persistentModelID == selectedSubjectID }) {
            self.selectedSubjectID = subjects.first?.persistentModelID
        }

        syncWordCountWithEligibility()
    }

    private func cycleSubject(by delta: Int) {
        guard !subjects.isEmpty else { return }

        guard let selectedSubjectID,
              let currentIndex = subjects.firstIndex(where: { $0.persistentModelID == selectedSubjectID }) else {
            self.selectedSubjectID = subjects.first?.persistentModelID
            return
        }

        let count = subjects.count
        let nextIndex = (currentIndex + delta + count) % count
        self.selectedSubjectID = subjects[nextIndex].persistentModelID
    }

    private func generatePuzzle() {
        guard let session = buildSessionFromCurrentSettings() else { return }
        #if os(macOS)
        openWindow(id: PuzzleWindow.id, value: session)
        #else
        foundWords = []
        activePuzzleSession = session
        #endif
    }

    private func exportCurrentPuzzleToPDF() {
        guard let session = buildSessionFromCurrentSettings() else { return }
        exportPuzzleToPDF(puzzle: session.puzzle, title: session.title)
    }

    private func buildSessionFromCurrentSettings() -> PuzzleSession? {
        guard let selectedSubject else {
            setupErrorMessage = "Create a word bank first."
            return nil
        }

        let eligibleWords = eligibleWords(in: selectedSubject, for: selectedGridSize)
        guard !eligibleWords.isEmpty else {
            setupErrorMessage = "Add words to \(selectedSubject.name) before playing."
            return nil
        }

        guard eligibleWords.count >= minimumWordsPerPuzzle else {
            setupErrorMessage = "At least \(minimumWordsPerPuzzle) words must fit in the selected grid size."
            return nil
        }

        let requestedWordCount = max(minimumWordsPerPuzzle, min(selectedWordCount, eligibleWords.count))

        let options = WordSearchGenerationOptions(
            allowBackwards: allowBackwards,
            allowOverlap: allowOverlap
        )

        guard let puzzle = PuzzleFactory.generate(
            from: eligibleWords,
            wordCount: requestedWordCount,
            size: selectedGridSize,
            options: options
        ) else {
            setupErrorMessage = "Could not place \(requestedWordCount) words. Try enabling overlap, reducing words, or increasing grid size."
            return nil
        }

        setupErrorMessage = ""
        return PuzzleSession(
            puzzle: puzzle,
            wordPool: eligibleWords,
            wordCount: requestedWordCount,
            gridSize: selectedGridSize,
            options: options,
            title: selectedSubject.name
        )
    }

    private func exportPuzzleToPDF(puzzle: WordSearchPuzzle, title: String) {
        #if os(macOS)
        if !MacPDF.save(puzzle: puzzle, title: title) {
            setupErrorMessage = "Couldn't save the PDF. Please try again."
        }
        #else
        do {
            let fileURL = try PuzzlePDFExporter.shareableFileURL(for: puzzle, title: title)
            exportedDocumentCleanupURL = fileURL
            exportedDocument = ExportedDocument(url: fileURL)
        } catch {
            setupErrorMessage = "Couldn't generate PDF right now. Please try again."
        }
        #endif
    }

    private func cleanupExportedDocument() {
        if let url = exportedDocumentCleanupURL {
            try? FileManager.default.removeItem(at: url)
            exportedDocumentCleanupURL = nil
        }
    }

    private func eligibleWords(in subject: WordSubject, for size: Int) -> [String] {
        var seen = Set<String>()
        var words: [String] = []

        for word in subject.words {
            let cleaned = WordSearchGenerator.sanitizeWord(word.text)
            guard !cleaned.isEmpty, cleaned.count <= size else { continue }
            if seen.insert(cleaned).inserted {
                words.append(cleaned)
            }
        }

        return words
    }

    private func syncWordCountWithEligibility() {
        guard let selectedSubject else { return }
        let eligibleCount = eligibleWords(in: selectedSubject, for: selectedGridSize).count

        if eligibleCount < minimumWordsPerPuzzle {
            selectedWordCount = minimumWordsPerPuzzle
            return
        }

        if selectedWordCount < minimumWordsPerPuzzle {
            selectedWordCount = minimumWordsPerPuzzle
        } else if selectedWordCount > eligibleCount {
            selectedWordCount = eligibleCount
        }
    }
}

private extension View {
    /// Full-screen on iOS. On macOS puzzles open in their own window instead.
    @ViewBuilder
    func puzzleCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(item: item, content: content)
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct AppSidebar: View {
    @Binding var selectedTab: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack(spacing: 10) {
                Image(systemName: "character.textbox")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ground)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.ink))
                Text("Word Search")
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 4) {
                item("Play", systemImage: "play.fill", tag: 0)
                item("Word Banks", systemImage: "book.closed.fill", tag: 1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
        .frame(width: 220)
        .frame(maxHeight: .infinity)
        .background(Theme.surface.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.line).frame(width: 1).ignoresSafeArea()
        }
    }

    private func item(_ title: String, systemImage: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag

        return Button {
            selectedTab = tag
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .bold : .semibold))
                Spacer()
            }
            .foregroundStyle(isSelected ? Theme.accentText : Theme.inkSecondary)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isSelected ? Theme.accentTint : .clear))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#endif

private struct ExportedDocument: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    ContentView()
        .modelContainer(for: [WordSubject.self, SubjectWord.self], inMemory: true)
}
