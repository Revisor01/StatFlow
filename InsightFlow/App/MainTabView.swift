import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("tab.dashboard", systemImage: "chart.bar.fill", value: 0) {
                DashboardView()
            }

            Tab("tab.admin", systemImage: "slider.horizontal.3", value: 1) {
                AdminView()
            }

            Tab("tab.settings", systemImage: "gearshape.fill", value: 2) {
                SettingsView()
            }
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(NotificationManager())
}
