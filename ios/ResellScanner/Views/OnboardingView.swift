import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var page = 0

    var body: some View {
        ZStack {
            Brand.paper.ignoresSafeArea()
            TabView(selection: $page) {
                slide(
                    stamp: "30 seconds",
                    title: "Photo →\nlisting.",
                    text: "Snap a photo — get a ready-to-paste title, description, keywords and price estimate. No accounts. No integrations. No setup."
                )
                .tag(0)

                slide(
                    stamp: "Pro tip",
                    title: "Shoot the\ntag too.",
                    text: "Overall view, the brand/size tag, and any flaws. The tag photo dramatically improves brand, size and materials accuracy."
                )
                .tag(1)

                VStack(alignment: .leading, spacing: 18) {
                    Spacer()
                    StampLabel(text: "Final step", angle: -3)
                    Text("Ready\nto scan.")
                        .font(.system(size: 46, weight: .heavy))
                        .foregroundStyle(Brand.ink)
                        .lineSpacing(-2)
                    Text("Allow camera access to photograph your first item.")
                        .font(.body)
                        .foregroundStyle(Brand.inkSoft)
                    Spacer()
                    BarcodeView(seed: "onboarding-final", height: 24)
                    Button {
                        Task {
                            _ = await AVCaptureDevice.requestAccess(for: .video)
                            onboardingDone = true
                        }
                    } label: {
                        Text("Allow camera & start")
                    }
                    .buttonStyle(InkButtonStyle())
                    .padding(.bottom, 44)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .never))

            VStack {
                HStack(spacing: 8) {
                    TagMark(size: 16)
                    Text("RESELL SCANNER").printLabel(Brand.ink)
                    Spacer()
                    Text("№ 00\(page + 1)").mono(13)
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
                Spacer()
            }
        }
    }

    private func slide(stamp: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            StampLabel(text: stamp, angle: -3)
            Text(title)
                .font(.system(size: 46, weight: .heavy))
                .foregroundStyle(Brand.ink)
                .lineSpacing(-2)
            Text(text)
                .font(.body)
                .foregroundStyle(Brand.inkSoft)
            Spacer()
            HStack(spacing: 6) {
                Text("Swipe").printLabel()
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Brand.inkFaint)
            }
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
