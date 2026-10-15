import SwiftUI
import SwiftData

@main
struct WordSearchAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WordSubject.self,
            SubjectWord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        libraryWindow

        #if os(macOS)
        puzzleWindow
        #endif
    }

    private var libraryWindow: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1120, height: 760)
        .commands { AppCommands() }
        #endif
    }

    #if os(macOS)
    private var puzzleWindow: some Scene {
        WindowGroup("Puzzle", id: PuzzleWindow.id, for: PuzzleSession.self) { $session in
            if let session {
                PuzzleWindowView(session: session)
            }
        }
        .defaultSize(width: 1040, height: 760)
        .modelContainer(sharedModelContainer)
    }
    #endif
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS) && DEBUG
    @Environment(\.openWindow) private var openWindow
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            ContentView()
                #if DEBUG
                .task { seedDemoDataIfRequested() }
                #endif

            #if os(iOS)
            if isShowingSplash && !reduceMotion {
                SplashView { isShowingSplash = false }
                    .transition(.identity)
                    .zIndex(1)
            }
            #endif
        }
    }

    #if DEBUG
    /// Launch with `-SeedDemoData` to fill an empty store with sample word banks (for screenshots and previews).
    private func seedDemoDataIfRequested() {
        defer { openDemoPuzzleIfRequested() }

        guard CommandLine.arguments.contains("-SeedDemoData"),
              ((try? modelContext.fetchCount(FetchDescriptor<WordSubject>())) ?? 0) == 0 else { return }

        let banks: [(String, [String])] = [
            ("Ocean Life", ["WHALE", "CORAL", "REEF", "SHARK", "TIDE", "KELP", "SQUID", "PEARL", "CRAB", "EEL", "OCTOPUS", "DOLPHIN", "TURTLE", "LOBSTER"]),
            ("Space & Planets", ["MARS", "VENUS", "SATURN", "COMET", "ORBIT", "GALAXY", "METEOR", "NEBULA", "ROCKET", "LUNAR"]),
            ("Farm Animals", ["COW", "PIG", "SHEEP", "GOAT", "HORSE", "CHICKEN", "DUCK", "TURKEY", "DONKEY", "ROOSTER"])
        ]

        for (name, words) in banks {
            let subject = WordSubject(name: name)
            modelContext.insert(subject)
            for text in words {
                let word = SubjectWord(text: text)
                word.subject = subject
                modelContext.insert(word)
                subject.words.append(word)
            }
        }
    }

    /// Launch with `-OpenDemoPuzzle` to open a puzzle window straight away (macOS, for screenshots).
    private func openDemoPuzzleIfRequested() {
        #if os(macOS)
        guard CommandLine.arguments.contains("-OpenDemoPuzzle"),
              let subject = try? modelContext.fetch(FetchDescriptor<WordSubject>(sortBy: [SortDescriptor(\.name)])).first else { return }

        let pool = Array(Set(subject.words.map { WordSearchGenerator.sanitizeWord($0.text) }.filter { !$0.isEmpty && $0.count <= 12 }))
        guard pool.count >= PuzzleFactory.minimumWordsPerPuzzle,
              let puzzle = PuzzleFactory.generate(from: pool, wordCount: 8, size: 12, options: .default) else { return }

        openWindow(id: PuzzleWindow.id, value: PuzzleSession(
            puzzle: puzzle, wordPool: pool, wordCount: 8, gridSize: 12, options: .default, title: subject.name
        ))
        #endif
    }
    #endif
}
