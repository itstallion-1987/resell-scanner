import SwiftUI

// Фирменный язык «Бирка»: объявление как физический ценник.
// Крафт-бумага, чернильные рамки, перфорация, красный штамп, штрих-код,
// моноширинные цены. Печатная эстетика: плоско, контрастно, без теней.

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
    static let paper = Color(hex: 0xF3EEE3)      // крафт-фон
    static let ticket = Color(hex: 0xFFFDF7)     // бумага бирки
    static let ink = Color(hex: 0x1A1A16)        // чернила
    static let inkSoft = Color(hex: 0x5C574B)    // вторичный текст
    static let inkFaint = Color(hex: 0x8B8472)   // подписи-лейблы
    static let line = Color(hex: 0xD9D2C2)       // тонкие линейки на крафте
    static let stamp = Color(hex: 0xC73E2E)      // красный штамп
    static let stampInk = Color(hex: 0x7E2218)   // тёмный красный (текст на штампе)
    static let cameraDark = Color(hex: 0x161410) // фон камеры
}

// MARK: - Типографика печати

extension Text {
    /// Маленький лейбл «как на чеке»: капс + разрядка
    func printLabel(_ color: Color = Brand.inkFaint) -> Text {
        self.font(.caption2.weight(.semibold)).kerning(1.4).foregroundColor(color)
    }

    /// Моноширинные цифры (цены, коды)
    func mono(_ size: CGFloat = 17, weight: Font.Weight = .semibold) -> Text {
        self.font(.system(size: size, weight: weight, design: .monospaced)).foregroundColor(Brand.ink)
    }
}

// MARK: - Бирка (карточка с чернильной рамкой и дыроколом)

struct TicketCard: ViewModifier {
    var holePunch: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(Brand.ticket)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Brand.ink, lineWidth: 1.3)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(alignment: .topLeading) {
                if holePunch {
                    Circle()
                        .fill(Brand.paper)
                        .overlay(Circle().strokeBorder(Brand.ink, lineWidth: 1.3))
                        .frame(width: 12, height: 12)
                        .offset(x: 16, y: -6)
                }
            }
    }
}

extension View {
    func ticketCard(holePunch: Bool = false) -> some View {
        modifier(TicketCard(holePunch: holePunch))
    }
}

/// Перфорация — пунктирная линия отрыва
struct Perforation: View {
    var color: Color = Brand.ink

    var body: some View {
        Rectangle()
            .frame(height: 1.2)
            .foregroundStyle(.clear)
            .overlay(
                GeometryReader { geo in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0.6))
                        p.addLine(to: CGPoint(x: geo.size.width, y: 0.6))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                }
            )
            .frame(height: 2)
    }
}

/// Декоративный штрих-код: детерминированные полосы из строки-сида
struct BarcodeView: View {
    let seed: String
    var height: CGFloat = 22
    var color: Color = Brand.ink

    var body: some View {
        Canvas { context, size in
            var hash = UInt64(5381)
            for byte in seed.utf8 {
                hash = hash &* 33 &+ UInt64(byte)
            }
            var x: CGFloat = 0
            var state = hash
            while x < size.width {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let w = CGFloat((state >> 33) % 3) + 1
                let gap = CGFloat((state >> 41) % 3) + 1.5
                context.fill(
                    Path(CGRect(x: x, y: 0, width: w, height: size.height)),
                    with: .color(color)
                )
                x += w + gap
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Красный штамп: повёрнутая рамка с капсом
struct StampLabel: View {
    let text: String
    var color: Color = Brand.stamp
    var angle: Double = -4

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .kerning(1.6)
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(color, lineWidth: 1.7)
            )
            .rotationEffect(.degrees(angle))
            .opacity(0.92)
    }
}

/// Маленькая марка бренда: бирка с верёвочным отверстием
struct TagMark: View {
    var size: CGFloat = 26
    var color: Color = Brand.ink

    var body: some View {
        ZStack {
            Image(systemName: "tag.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
                .rotationEffect(.degrees(-15))
            Circle()
                .fill(Brand.paper)
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(x: -size * 0.28, y: -size * 0.1)
        }
        .frame(width: size * 1.2, height: size * 1.2)
    }
}

// MARK: - Кнопки печатного пресса

struct InkButtonStyle: ButtonStyle {
    var fill: Color = Brand.ink
    var textColor: Color = Brand.ticket

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .kerning(1.8)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(fill, in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(textColor)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GhostInkButtonStyle: ButtonStyle {
    var tint: Color = Brand.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .kerning(1.2)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(tint, lineWidth: 1.4)
            )
            .foregroundStyle(tint)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// Мотив видоискателя — остаётся только на экране камеры
struct ViewfinderBrackets: Shape {
    var cornerLength: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = min(rect.width, rect.height) * cornerLength
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}
