import SwiftUI

/// Этапный оверлей «печать чека»: бирка с построчно печатающимися шагами —
/// ощущение работы вместо зависшего спиннера.
struct GenerationProgressView: View {
    @State private var step = 0
    @State private var cursorOn = true
    private let steps = ["Uploading photos", "Recognizing the item", "Writing your listing"]

    var body: some View {
        ZStack {
            Brand.ink.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Printing your listing").printLabel(Brand.inkSoft)
                    Spacer()
                    TagMark(size: 16)
                }
                Perforation()
                ForEach(steps.indices, id: \.self) { i in
                    HStack(spacing: 8) {
                        Text(i < step ? "[ok]" : (i == step ? "[..]" : "[  ]"))
                            .font(.system(.footnote, design: .monospaced).weight(.bold))
                            .foregroundStyle(i < step ? Brand.ink : (i == step ? Brand.stamp : Brand.inkFaint))
                            .opacity(i == step ? (cursorOn ? 1 : 0.25) : 1)
                            .animation(
                                i == step ? .easeInOut(duration: 0.45).repeatForever(autoreverses: true) : nil,
                                value: cursorOn
                            )
                        Text(steps[i])
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(i <= step ? Brand.ink : Brand.inkFaint)
                        Spacer()
                    }
                }
                Perforation()
                BarcodeView(seed: "printing", height: 16)
            }
            .padding(16)
            .frame(maxWidth: 290)
            .background(Brand.ticket)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Brand.ink, lineWidth: 1.4))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .task {
            cursorOn = false // запускает repeatForever-анимацию курсора
            for i in 1..<steps.count {
                try? await Task.sleep(for: .seconds(i == 1 ? 1.2 : 2.0))
                if Task.isCancelled { return }
                step = i
            }
        }
    }
}
