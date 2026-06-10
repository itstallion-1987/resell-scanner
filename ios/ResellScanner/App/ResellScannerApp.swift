import SwiftUI
import SwiftData

@main
struct ResellScannerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var purchases = PurchaseManager.shared

    init() {
        PurchaseManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(purchases)
        }
        .modelContainer(for: Listing.self)
    }
}
