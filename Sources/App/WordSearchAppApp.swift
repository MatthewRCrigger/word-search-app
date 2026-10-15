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
        WindowGroup {
            RootView()
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            ContentView()

            #if os(iOS)
            if isShowingSplash && !reduceMotion {
                SplashView { isShowingSplash = false }
                    .transition(.identity)
                    .zIndex(1)
            }
            #endif
        }
    }
}
