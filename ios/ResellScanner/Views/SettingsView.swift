import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var appState: AppState

    @AppStorage("defaultPlatform") private var defaultPlatformRaw = Platform.ebay.rawValue
    @AppStorage("currency") private var currency = "USD"

    private static let currencies = ["USD", "EUR", "GBP", "CAD", "AUD", "PLN"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Listings") {
                    Picker("Default platform", selection: $defaultPlatformRaw) {
                        ForEach(Platform.allCases) { platform in
                            Text(platform.displayName).tag(platform.rawValue)
                        }
                    }
                    Picker("Currency", selection: $currency) {
                        ForEach(Self.currencies, id: \.self) { Text($0) }
                    }
                }

                Section("Subscription") {
                    HStack {
                        Text("Plan")
                        Spacer()
                        Text(purchases.isPro ? "Pro" : "Free")
                            .foregroundStyle(purchases.isPro ? .green : .secondary)
                    }
                    if !purchases.isPro {
                        if let remaining = appState.remainingFree, remaining >= 0 {
                            HStack {
                                Text("Free listings left")
                                Spacer()
                                Text("\(remaining)").foregroundStyle(.secondary)
                            }
                        }
                        Button("Upgrade to Pro") {
                            appState.showPaywall = true
                        }
                    }
                    Button("Restore purchases") {
                        Task { await purchases.restore() }
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    // TODO: заменить ссылки перед сабмитом
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
