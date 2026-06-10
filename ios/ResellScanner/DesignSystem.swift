import SwiftUI

// Фирменный язык: глубокий изумруд + тёплая «бумага ценника» + янтарь для денег.
// Мотив бренда — уголки видоискателя (из иконки приложения).

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Brand {
    static let forest = Color(hex: 0x0E3B33)      // глубокий изумруд — фирменные поверхности
    static let forestDeep = Color(hex: 0x0A2B25)  // низ градиентов
    static let emerald = Color(hex: 0x0FA383)     // акцент действий
    static let mint = Color(hex: 0x2BC79F)        // яркий акцент на тёмном
    static let paper = Color(hex: 0xF7F4ED)       // фон «бумага ценника»
    static let card = Color.white
    static let amber = Color(hex: 0xD99A2B)       // деньги/цена
    static let amberInk = Color(hex: 0x412402)    // текст на янтаре
    static let ink = Color(hex: 0x14211E)
    static let inkMuted = Color(hex: 0x5C6B66)
    static let lineOnPaper = Color(hex: 0xE4DFD2)

    static var forestGradient: LinearGradient {
        LinearGradient(colors: [forest, forestDeep], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Мотив: уголки видоискателя

struct ViewfinderBrackets: Shape {
    var cornerLength: CGFloat = 0.28 // доля стороны

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = min(rect.width, rect.height) * cornerLength
        // верх-лево
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // верх-право
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // низ-право
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // низ-лево
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

struct BrandMark: View {
    var size: CGFloat = 28
    var color: Color = Brand.mint

    var body: some View {
        ZStack {
            ViewfinderBrackets()
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.11, lineCap: .round))
            Image(systemName: "tag.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-15))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Кнопки

struct BrandPrimaryButtonStyle: ButtonStyle {
    var fill: Color = Brand.emerald
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(fill, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .foregroundStyle(textColor)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct BrandGhostButtonStyle: ButtonStyle {
    var tint: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1.2)
            )
            .foregroundStyle(tint)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Карточки и подписи

struct PaperCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Brand.ink.opacity(0.05), radius: 10, y: 3)
    }
}

extension View {
    func paperCard() -> some View { modifier(PaperCard()) }
}

struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(Brand.inkMuted)
    }
}

struct BrandChipLabel: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            FieldLabel(text: title)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(Brand.ink)
        }
    }
}
