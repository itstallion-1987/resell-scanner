import SwiftUI

/// Этапный оверлей вместо «зависшего» спиннера — создаёт ощущение работы
/// и удерживает от свайпа из приложения в момент генерации.
struct GenerationProgressView: View {
    @State private var step = 0
    @State private var pulse = false
    private let steps = ["Uploading photos…", "Recognizing the item…", "Writing your listing…"]

    var body: some View {
        ZStack {
            Brand.forestDeep.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    ViewfinderBrackets()
                        .stroke(Brand.mint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 86, height: 86)
                        .scaleEffect(pulse ? 1.06 : 0.96)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "tag.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Brand.mint)
                        .rotationEffect(.degrees(-15))
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(steps.indices, id: \.self) { i in
                        HStack(spacing: 10) {
                            Image(systemName: icon(for: i))
                                .foregroundStyle(i <= step ? Brand.mint : .white.opacity(0.3))
                            Text(steps[i])
                                .font(.callout.weight(i == step ? .semibold : .regular))
                                .fontDesign(.rounded)
                                .foregroundStyle(i <= step ? .white : .white.opacity(0.4))
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 52)
            }
        }
        .task {
            pulse = true
            for i in 1..<steps.count {
                try? await Task.sleep(for: .seconds(i == 1 ? 1.2 : 2.0))
                if Task.isCancelled { return }
                step = i
            }
        }
    }

    private func icon(for index: Int) -> String {
        if index < step { return "checkmark.circle.fill" }
        if index == step { return "circle.dotted" }
        return "circle"
    }
}
