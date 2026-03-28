import SwiftUI

struct ContentView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    private var preferredColorScheme: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        Group {
            if accountManager.activeAccount != nil {
                MainTabView()
                    .supportReminder()
            } else {
                LoginView()
            }
        }
        .animation(.smooth, value: accountManager.activeAccount != nil)
        .preferredColorScheme(preferredColorScheme)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            if !hasSeenOnboarding {
                showOnboarding = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationManager())
}
