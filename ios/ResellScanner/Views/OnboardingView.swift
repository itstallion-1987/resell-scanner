import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var page = 0

    var body: some View {
        ZStack {
            Brand.forestGradient.ignoresSafeArea()
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

                VStack(spacing: 22) {
                    Spacer()
                    ZStack {
                        ViewfinderBrackets()
                            .stroke(Brand.mint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 110, height: 110)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Brand.mint)
                    }
                    Text("Ready to scan")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("Allow camera access to photograph your first item.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                    Spacer()
                    Button {
                        Task {
                            _ = await AVCaptureDevice.requestAccess(for: .video)
                            onboardingDone = true
                        }
                    } label: {
                        Text("Allow camera & start")
                    }
                    .buttonStyle(BrandPrimaryButtonStyle())
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 30)
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .never))
        }
    }

    private func slide(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                ViewfinderBrackets()
                    .stroke(Brand.mint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 110, height: 110)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(Brand.mint)
            }
            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Text("Swipe")
                Image(systemName: "chevron.right")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.35))
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 30)
    }
}
