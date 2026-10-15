import SwiftUI

/// In-app splash that continues the system launch screen: same mark, same position, then the
/// wordmark fades in and the whole thing dissolves into the app.
struct SplashView: View {
    let onFinish: () -> Void

    @State private var phase = 0

    private let markSize: CGFloat = 200

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()

            Image("LaunchMark")
                .resizable()
                .scaledToFit()
                .frame(width: markSize, height: markSize)
                .offset(y: phase >= 1 ? -22 : 0)
                .accessibilityHidden(true)

            Text("Word Search")
                .font(Theme.display(34, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .offset(y: markSize / 2 + 28)
                .opacity(phase >= 1 ? 1 : 0)
                .offset(y: phase >= 1 ? 0 : 10)
        }
        .opacity(phase >= 2 ? 0 : 1)
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.smooth(duration: 0.55)) { phase = 1 }
            try? await Task.sleep(for: .milliseconds(850))
            withAnimation(.easeIn(duration: 0.3)) { phase = 2 }
            try? await Task.sleep(for: .milliseconds(300))
            onFinish()
        }
    }
}
