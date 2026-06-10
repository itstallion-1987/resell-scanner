import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @EnvironmentObject private var appState: AppState

    @AppStorage("defaultPlatform") private var defaultPlatformRaw = Platform.ebay.rawValue
    @AppStorage("currency") private var currency = "USD"
    @State private var copiedDeviceID = false

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
                    Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                    Link("Terms of Use", destination: AppConfig.termsOfUseURL)
                }

                Section {
                    // Идентификатор устройства — для запроса на удаление данных (обещано в Privacy Policy)
                    Button {
                        UIPasteboard.general.string = DeviceID.current
                        copiedDeviceID = true
                    } label: {
                        HStack {
                            Text("Device ID")
                            Spacer()
                            Text(copiedDeviceID ? "Copied!" : String(DeviceID.current.prefix(8)) + "…")
                                .foregroundStyle(.secondary)
                                .font(.callout.monospaced())
                        }
                    }
                } footer: {
                    Text("Anonymous ID used only to enforce free-tier limits. Tap to copy if you request data deletion.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
