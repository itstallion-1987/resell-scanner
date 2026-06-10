import SwiftUI

/// Этапный оверлей вместо «зависшего» спиннера — создаёт ощущение работы
/// и удерживает от свайпа из приложения в момент генерации (3–8 с).
struct GenerationProgressView: View {
    @State private var step = 0
    private let steps = ["Uploading photos…", "Recognizing the item…", "Writing your listing…"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 24) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(steps.indices, id: \.self) { i in
                        HStack(spacing: 10) {
                            Image(systemName: icon(for: i))
                                .foregroundStyle(i <= step ? Color.white : Color.white.opacity(0.4))
                            Text(steps[i])
                                .font(.callout.weight(i == step ? .semibold : .regular))
                                .foregroundStyle(i <= step ? Color.white : Color.white.opacity(0.5))
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .task {
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
