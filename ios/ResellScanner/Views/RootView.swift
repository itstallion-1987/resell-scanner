import SwiftUI

struct RootView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !onboardingDone {
                OnboardingView()
            } else {
                TabView {
                    ScanView()
                        .tabItem { Label("Scan", systemImage: "camera.viewfinder") }
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
                .sheet(isPresented: $appState.showPaywall) {
                    PaywallView()
                }
            }
        }
        .tint(Brand.emerald)
        // Бренд построен на светлой «бумаге ценника»; фиксируем светлую схему,
        // чтобы интерфейс выглядел одинаково у всех (тёмная тема — бэклог)
        .preferredColorScheme(.light)
    }
}
