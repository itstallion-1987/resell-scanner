import SwiftUI

struct RootView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @EnvironmentObject private var appState: AppState

    var body: some View {
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
}
