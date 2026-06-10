import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            slide(
                icon: "bolt.fill",
                title: "A listing in 30 seconds",
                text: "Snap a photo — get a ready-to-paste title, description, keywords and price estimate. No accounts, no integrations, no setup."
            )
            .tag(0)

            slide(
                icon: "tag.fill",
                title: "Shoot 1–3 angles",
                text: "Overall view, the brand/size tag, and any flaws. The tag photo dramatically improves brand, size and materials accuracy."
            )
            .tag(1)

            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Ready to scan")
                    .font(.title.bold())
                Text("Allow camera access to photograph your first item.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task {
                        _ = await AVCaptureDevice.requestAccess(for: .video)
                        onboardingDone = true
                    }
                } label: {
                    Text("Allow camera & start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
            .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private func slide(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title.bold())
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
