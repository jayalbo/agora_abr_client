// Ensure your target's Info has UILaunchStoryboardName set to "LaunchScreen" to use the launch screen storyboard.
import SwiftUI

@main
struct AgoraABRAudienceApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

fileprivate struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                ContentView()
            }
        }
        .onAppear {
            // Keep splash visible briefly so users don't see a black screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSplash = false
                }
            }
        }
    }
}

